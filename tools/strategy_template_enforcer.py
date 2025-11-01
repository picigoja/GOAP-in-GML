#!/usr/bin/env python3
"""
Animus Strategy Template Enforcer

- Scans strategy/action files for hand-rolled strategies.
- If a file doesn't reference Animus_StrategyTemplates.*, it is "non-templated".
- Heuristically classifies the legacy style: instant / timed / move.
- Reports issues (exit 1) or, with --patch, injects a commented scaffold
  right above the first 'build_strategy' definition. No behavior change.

Usage:
  python tools/strategy_template_enforcer.py           # report-only, CI-friendly
  python tools/strategy_template_enforcer.py --patch   # inject commented scaffolds
  python tools/strategy_template_enforcer.py --strict  # fail on non-templated, even if scaffold already present

Options:
  --patch      Insert commented template scaffold blocks (idempotent).
  --strict     Treat any non-templated file as an error (default true in CI).
  --verbose    Print classification details.
"""
import re, sys, pathlib, yaml, argparse

ROOT = pathlib.Path(".")
CFG = yaml.safe_load((ROOT / "tools" / "animus_strategy_rules.yaml").read_text())

def rx(p, flags=0): return re.compile(p, flags)

GLOBS = CFG["strategy_file_globs"]
NS_RE = rx(CFG["template_namespace_regex"]) if CFG.get("template_namespace_regex") else None
BSTART = CFG.get("patch_banner_start", "/* ANIMUS SUGGESTION */")
BEND   = CFG.get("patch_banner_end", "/* END */")

def compile_list(arr):
    out = []
    for p in arr:
        try:
            out.append(rx(p, re.S))
        except re.error as e:
            # Skip invalid/fragile heuristics but warn; keeps enforcer robust
            print(f"[warn] invalid heuristic regex skipped: {p} ({e})")
    return out

INSTANT_RX = compile_list(CFG.get("instant_heuristics", []))
TIMED_RX   = compile_list(CFG.get("timed_heuristics", []))
MOVE_RX    = compile_list(CFG.get("move_heuristics", []))

SCAFFOLDS = CFG.get("template_scaffolds", {})

def gather_files():
    out = []
    for g in GLOBS:
        out.extend([p for p in ROOT.glob(g) if p.is_file() and p.suffix.lower()==".gml"])
    return sorted(set(out))

def classify_legacy(text):
    scores = {"instant":0, "timed":0, "move":0}
    for r in INSTANT_RX:
        if r.search(text): scores["instant"]+=1
    for r in TIMED_RX:
        if r.search(text): scores["timed"]+=1
    for r in MOVE_RX:
        if r.search(text): scores["move"]+=1
    order = ["timed", "move", "instant"]
    best = max(order, key=lambda k: (scores[k], -order.index(k)))
    return best, scores

def has_banner(text):
    return (BSTART in text) and (BEND in text)

def find_build_strategy_span(text):
    m = re.search(r'\bbuild_strategy\s*=\s*function\s*\(', text)
    if not m: return None
    i = text.find("{", m.end())
    if i == -1: return None
    return i

def inject_scaffold(text, kind, verbose=False):
    if has_banner(text):
        return text, False
    anchor = find_build_strategy_span(text)
    if anchor is None:
        return text, False
    scaffold = f"{BSTART}\n{SCAFFOLDS.get(kind, '').rstrip()}\n{BEND}\n"
    patched = text[:anchor] + scaffold + text[anchor:]
    if verbose:
        print(f"[patch] Inserted {kind} scaffold")
    return patched, True

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--patch", action="store_true")
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    files = gather_files()
    if args.verbose: print(f"[scan] {len(files)} candidate files")

    issues = 0
    touched = 0
    for f in files:
        text = f.read_text(encoding="utf-8", errors="ignore")
        if NS_RE and NS_RE.search(text):
            if args.verbose: print(f"[ok] {f} uses Animus_StrategyTemplates")
            continue

        kind, scores = classify_legacy(text)
        msg = f"{f}: non-templated strategy detected -> suggest `{kind}` template (scores={scores})"
        print(msg)
        if args.patch:
            patched, changed = inject_scaffold(text, kind, args.verbose)
            if changed:
                f.write_text(patched, encoding="utf-8")
                touched += 1
                print(f"[write] injected scaffold in {f}")
        if args.strict or not args.patch:
            issues += 1

    if args.patch and touched:
        print(f"[result] Scaffolds injected in {touched} file(s)")

    if issues:
        sys.exit(1)
    print("[result] All strategies templated (or scaffolds present).")

if __name__ == "__main__":
    main()
