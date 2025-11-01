#!/usr/bin/env python3
# Animus Strategy Template Enforcer v2 — detects inline strategy structs (no build_strategy) and can scaffold above them.
import re, sys, pathlib, yaml, argparse

ROOT = pathlib.Path(".")
CFG = yaml.safe_load((ROOT / "tools" / "animus_strategy_rules.yaml").read_text())

def rx(p, flags=0): return re.compile(p, flags)

GLOBS = CFG["strategy_file_globs"]
NS_RE = rx(CFG["template_namespace_regex"])
ALLOW_INLINE = CFG.get("allow_inline_return_scaffold", True)

BSTART = CFG.get("patch_banner_start", "/* ===== ANIMUS TEMPLATE SUGGESTION (auto-inserted) =====")
BEND   = CFG.get("patch_banner_end",   "===== END ANIMUS TEMPLATE SUGGESTION ===== */")

INSTANT_RX = [rx(p, re.S) for p in CFG["instant_heuristics"]]
TIMED_RX   = [rx(p, re.S) for p in CFG["timed_heuristics"]]
MOVE_RX    = [rx(p, re.S) for p in CFG["move_heuristics"]]

SCAFFOLDS = CFG["template_scaffolds"]

REQ_METHODS = ["start","update","stop","invariant_check"]

def gather_files():
    out = []
    for g in GLOBS:
        out.extend([p for p in ROOT.glob(g) if p.is_file() and p.suffix.lower()==".gml"])
    return sorted(set(out))

def classify_legacy(text):
    scores = {"instant":0, "timed":0, "move":0}
    for r in INSTANT_RX:
        try:
            if r.search(text): scores["instant"]+=1
        except re.error:
            pass
    for r in TIMED_RX:
        try:
            if r.search(text): scores["timed"]+=1
        except re.error:
            pass
    for r in MOVE_RX:
        try:
            if r.search(text): scores["move"]+=1
        except re.error:
            pass
    # strict priority on ties: timed > move > instant (conservative)
    order = ["timed","move","instant"]
    best = max(order, key=lambda k: (scores[k], 2 if k=="timed" else (1 if k=="move" else 0)))
    return best, scores

def has_banner(text):
    return (BSTART in text) and (BEND in text)

def find_build_strategy_brace(text):
    m = re.search(r'\bbuild_strategy\s*=\s*function\s*\(', text)
    if not m: return None
    # find first { after signature
    i = text.find("{", m.end())
    if i == -1: return None
    return i

def method_presence(block):
    missing = []
    for name in REQ_METHODS:
        if re.search(rf'\b{name}\s*=\s*function\s*\(', block) is None:
            missing.append(name)
    return missing

def find_inline_strategy_return_spans(text):
    """
    Look for: return { ... start=function ... update=function ... stop=function ... } ;
    Returns index of 'return' token for injection.
    """
    out = []
    for m in re.finditer(r'\breturn\s*\{', text):
        # capture struct literal until matching }
        i = m.end()-1
        depth = 1
        while i < len(text) and depth > 0:
            if text[i] == "{": depth += 1
            elif text[i] == "}": depth -= 1
            i += 1
        block = text[m.end():i-1]
        miss = method_presence(block)
        if len(miss) < 4:  # we found at least one required method; good signal it’s a strategy
            out.append((m.start(), i))
    return out

def inject_scaffold_at(text, idx, kind):
    if has_banner(text):
        return text, False
    scaffold = f"{BSTART}\n{SCAFFOLDS[kind].rstrip()}\n{BEND}\n"
    patched = text[:idx] + scaffold + text[idx:]
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

        # Skip if already using templates
        if NS_RE.search(text):
            if args.verbose: print(f"[ok] {f} uses Animus_StrategyTemplates")
            continue

        kind, scores = classify_legacy(text)
        if args.verbose:
            # Use ASCII arrow to avoid console encoding issues on Windows
            print(f"{f}: non-templated strategy detected -> suggest `{kind}` template (scores={scores})")

        inserted = False
        # Primary: build_strategy body
        brace = find_build_strategy_brace(text)
        if brace is not None:
            if args.patch:
                new_text, changed = inject_scaffold_at(text, brace, kind)
                if changed:
                    f.write_text(new_text, encoding="utf-8")
                    touched += 1
                    inserted = True
                    if args.verbose: print(f"[write] injected scaffold (build_strategy) in {f}")

        # Fallback: inline return of a strategy struct
        if not inserted and ALLOW_INLINE:
            spans = find_inline_strategy_return_spans(text)
            if spans:
                # inject at the first return of a likely strategy struct
                if args.patch:
                    idx = spans[0][0]
                    new_text, changed = inject_scaffold_at(text, idx, kind)
                    if changed:
                        f.write_text(new_text, encoding="utf-8")
                        touched += 1
                        inserted = True
                        if args.verbose: print(f"[write] injected scaffold (inline return) in {f}")

        if args.strict or not args.patch:
            # Count as an issue unless we successfully inserted a scaffold
            if not inserted:
                issues += 1

    if args.patch and args.verbose:
        print(f"[result] Scaffolds inserted in {touched} file(s)")

    if issues:
        sys.exit(1)
    print("[result] All strategies templated (or scaffolds present).")

if __name__ == "__main__":
    main()
