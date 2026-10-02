#!/usr/bin/env python3
"""Merge a stock system_ext SELinux policy into the GSI's own system_ext policy (stdlib only).

Usage: merge_system_ext_sepolicy.py GSI_DIR STOCK_DIR OUT_DIR --ver 202504 [--stock-name NAME]

GSI_DIR / STOCK_DIR are copies of a system_ext etc/selinux dir. Writes the merged files that differ
from GSI_DIR into OUT_DIR (same relative paths), plus a regenerated
system_ext_sepolicy_and_mapping.sha256, and prints what it did.

The GSI mounts no system_ext partition (/system_ext is /system/system_ext), so the stock system_ext
policy (vendor HAL service labels and rules) is otherwise never loaded.

Why the stock cil is rewritten, not just appended:
  init runs secilc with -m (multiple declarations allowed), so a name declared in two files is
  merged, not rejected. system_ext cil numbers its generated attributes (base_typeattr_N) after the
  plat policy it was built against. The stock system_ext was built against a different plat policy,
  so its numbers collide with the GSI's plat and system_ext ones and would silently be unioned into
  unrelated attribute sets. The stock ones are renamed to base_typeattr_N<suffix>.
"""
import argparse
import hashlib
import os
import re
import sys
import xml.etree.ElementTree as ET


def read_lines(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().splitlines()
    except FileNotFoundError:
        return []


def entries(lines):
    """Non-comment, non-blank lines."""
    return [l for l in lines if l.strip() and not l.lstrip().startswith("#")]


# Key functions: what the runtime treats as "the same entry".

def key_first_token(line):  # service/hwservice/keystore2/tee contexts
    return line.split()[0]


def key_property(line):
    # "name context [exact|prefix] [type...]". init rejects a duplicate (name, match kind).
    t = line.split()
    return (t[0], "exact" if len(t) > 2 and t[2] == "exact" else "prefix")


def key_file(line):
    # "regex [-type] context"
    t = line.split()
    return (t[0], t[1] if len(t) == 3 else "")


SEAPP_OUTPUTS = {"domain", "type", "levelFrom", "level"}


def key_seapp(line):
    # libselinux rejects seapp entries whose input selectors are all equal.
    kv = dict(p.split("=", 1) for p in line.split())
    return frozenset((k, v) for k, v in kv.items() if k not in SEAPP_OUTPUTS)


def value_of(line, key_fn):
    if key_fn is key_seapp:
        kv = dict(p.split("=", 1) for p in line.split())
        return tuple(sorted((k, v) for k, v in kv.items() if k in SEAPP_OUTPUTS))
    t = line.split()
    if key_fn is key_file:
        return t[-1]
    return tuple(t[1:])


CONTEXT_FILES = {
    "system_ext_service_contexts": key_first_token,
    "system_ext_hwservice_contexts": key_first_token,
    "system_ext_property_contexts": key_property,
    "system_ext_file_contexts": key_file,
    "system_ext_seapp_contexts": key_seapp,
    "system_ext_keystore2_key_contexts": key_first_token,
    "system_ext_tee_service_contexts": key_first_token,
}


def merge_context(gsi_lines, stock_lines, key_fn, name, stock_name):
    """GSI file unchanged, then stock entries whose key the GSI file doesn't already have."""
    have = {}
    for l in entries(gsi_lines):
        have[key_fn(l)] = l
    added, same, conflicts = [], 0, []
    for l in entries(stock_lines):
        k = key_fn(l)
        if k in have:
            if value_of(have[k], key_fn) == value_of(l, key_fn):
                same += 1
            else:
                conflicts.append((have[k], l))
            continue
        have[k] = l
        added.append(l)
    if conflicts:
        for g, s in conflicts:
            print(f"CONFLICT in {name}:\n  gsi:   {g}\n  stock: {s}", file=sys.stderr)
        sys.exit(f"{name}: {len(conflicts)} conflicting entries, refusing to guess")
    out = list(gsi_lines)
    if added:
        out += ["", f"# ---- merged from {stock_name} ----"] + added
    return out, len(added), same


def check_one_statement_per_line(lines, path):
    for i, l in enumerate(lines, 1):
        s = l.strip()
        if not s or s.startswith(";"):
            continue
        if not s.startswith("(") or s.count("(") != s.count(")"):
            sys.exit(f"{path}:{i}: not one balanced CIL statement per line; line-level merge unsafe")


BASE_ATTR = re.compile(r"\bbase_typeattr_(\d+)\b")


def rename_stock_base_typeattrs(stock_lines, path, suffix):
    """Rename base_typeattr_N declared in the stock file to base_typeattr_N<suffix>.

    The stock file also references a few base_typeattr_N it does not declare: those come from the
    plat policy it was built against and mean something else in the GSI's plat. Statements using
    them can't be translated. They are all neverallows (compile-time assertions that init skips
    with -N and that never reach the kernel policy), so they are dropped. Anything else referencing
    them is an error.
    """
    declared = set(re.findall(r"^\(typeattribute (base_typeattr_\d+)\)", "\n".join(stock_lines), re.M))
    out, dropped = [], 0
    for l in stock_lines:
        foreign = {m.group(0) for m in BASE_ATTR.finditer(l)} - declared
        if foreign:
            if l.startswith(("(neverallow ", "(neverallowx ")):
                dropped += 1
                continue
            sys.exit(f"{path}: non-neverallow statement uses plat attribute {foreign}: {l[:200]}")
        out.append(BASE_ATTR.sub(lambda m: f"{m.group(0)}{suffix}", l))
    return out, dropped


def merge_cil(gsi_lines, stock_lines, path, stock_name, suffix, rename):
    """GSI statements unchanged, then stock statements not already present verbatim.

    Returns (lines, added, identical_skipped, neverallows_dropped)."""
    check_one_statement_per_line(gsi_lines, path + " (gsi)")
    check_one_statement_per_line(stock_lines, path + " (stock)")
    dropped = 0
    if rename:
        stock_lines, dropped = rename_stock_base_typeattrs(stock_lines, path, suffix)
    have = set(l.strip() for l in gsi_lines)
    added = [l for l in stock_lines if l.strip() and not l.lstrip().startswith(";")
             and l.strip() not in have]
    dup = sum(1 for l in stock_lines if l.strip() and l.strip() in have)
    out = list(gsi_lines)
    if added:
        out += [f";;; ---- merged from {stock_name}; "
                f"base_typeattr_N renamed to base_typeattr_N{suffix} ----"] + added
    return out, len(added), dup, dropped


def merge_mac_permissions(gsi_text, stock_text):
    """Append stock <signer> elements whose signature the GSI file doesn't have."""
    g = ET.fromstring(gsi_text)
    s = ET.fromstring(stock_text)
    have = {e.get("signature") for e in g.findall("signer")}
    added = [e for e in s.findall("signer") if e.get("signature") not in have]
    if not added:
        return None, 0
    for e in added:
        g.append(e)
    return '<?xml version="1.0" encoding="iso-8859-1"?>' + ET.tostring(g, encoding="unicode"), len(added)


def write(out_dir, rel, lines_or_text):
    p = os.path.join(out_dir, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    text = lines_or_text if isinstance(lines_or_text, str) else "\n".join(lines_or_text) + "\n"
    with open(p, "w", encoding="utf-8") as f:
        f.write(text)


def merge(a):
    ver = a.ver
    report = []
    # 1. policy + mapping (+ compat if the stock one has content)
    cil = "system_ext_sepolicy.cil"
    if not os.path.exists(os.path.join(a.gsi, cil)):
        sys.exit(f"{a.gsi}: no {cil}")
    merged_cil, n, d, x = merge_cil(read_lines(os.path.join(a.gsi, cil)),
                                    read_lines(os.path.join(a.stock, cil)), cil, a.stock_name,
                                    a.suffix, rename=True)
    write(a.out, cil, merged_cil)
    report.append(f"{cil}: +{n} stock statements ({d} already identical in GSI; "
                  f"{x} neverallows on foreign base_typeattrs dropped)")
    for rel in (f"mapping/{ver}.cil", f"mapping/{ver}.compat.cil"):
        stock = read_lines(os.path.join(a.stock, rel))
        if not entries([l for l in stock if not l.startswith(";")]):
            report.append(f"{rel}: stock has none, GSI copy kept")
            continue
        if rel.endswith(".compat.cil") and not os.path.exists(os.path.join(a.gsi, rel)):
            sys.exit(f"{rel}: stock has statements but the GSI installs no such file")
        merged, n, d, _ = merge_cil(read_lines(os.path.join(a.gsi, rel)), stock, rel, a.stock_name,
                                  a.suffix, rename=False)
        write(a.out, rel, merged)
        report.append(f"{rel}: +{n} stock statements ({d} already identical in GSI)")
    # 2. context files (only those the GSI has; the others would not be installed)
    for name, key_fn in CONTEXT_FILES.items():
        gp = os.path.join(a.gsi, name)
        s = read_lines(os.path.join(a.stock, name))
        if not os.path.exists(gp):
            if entries(s):
                report.append(f"{name}: not in GSI, {len(entries(s))} stock entries skipped")
            continue
        merged, n, same = merge_context(read_lines(gp), s, key_fn, name, a.stock_name)
        if n:
            write(a.out, name, merged)
        report.append(f"{name}: +{n} stock entries ({same} already in GSI with same context)")
    # 3. mac_permissions
    name = "system_ext_mac_permissions.xml"
    gp, sp = os.path.join(a.gsi, name), os.path.join(a.stock, name)
    if os.path.exists(gp) and os.path.exists(sp):
        with open(gp) as f:
            gt = f.read()
        with open(sp) as f:
            st = f.read()
        text, n = merge_mac_permissions(gt, st)
        if text:
            write(a.out, name, text)
        report.append(f"{name}: +{n} stock signers")
    # 4. hash file: init compares it with the precompiled policy's copy on odm to decide whether to
    #    compile on device. It is sha256(system_ext_sepolicy.cil + mapping/<ver>.cil); regenerate it
    #    for the merged files (it then never matches the stock precompiled policy).
    h = hashlib.sha256()
    for rel in (cil, f"mapping/{ver}.cil"):
        p = os.path.join(a.out, rel)
        if not os.path.exists(p):
            p = os.path.join(a.gsi, rel)
        with open(p, "rb") as f:
            h.update(f.read())
    write(a.out, "system_ext_sepolicy_and_mapping.sha256", h.hexdigest() + "\n")
    report.append(f"system_ext_sepolicy_and_mapping.sha256: regenerated = {h.hexdigest()}")
    print("\n".join(report))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("gsi")
    ap.add_argument("stock")
    ap.add_argument("out")
    ap.add_argument("--ver", required=True, help="vendor plat_sepolicy_vers.txt")
    ap.add_argument("--stock-name", default="stock system_ext",
                    help="names the merged-in part in the comment headers")
    ap.add_argument("--suffix", default="_aurora", help="appended to renamed stock base_typeattr_N")
    a = ap.parse_args()
    if not re.fullmatch(r"[0-9.]+", a.ver):
        sys.exit(f"bad --ver {a.ver!r}")
    merge(a)


if __name__ == "__main__":
    main()
