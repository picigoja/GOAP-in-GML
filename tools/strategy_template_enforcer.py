#!/usr/bin/env python3
# Animus Strategy Template Enforcer v2 — detects inline strategy structs (no build_strategy) and can scaffold above them.
import re, sys, pathlib, yaml, argparse

ROOT = pathlib.Path(".")
CFG = yaml.safe_load((ROOT / "tools" / "animus_strategy_rules.yaml").read_text())

def rx(p, flags=0): return re.compile(p, flags)

GLOBS = CFG["strategy_file_globs"]
NS_RE = rx(CFG["template_namespace_regex"])
#!/usr/bin/env python3
# Animus Strategy Template Enforcer v2.1 — emits machine-readable suggestions (JSON)
import re, sys, pathlib, yaml, argparse, json, time

ROOT = pathlib.Path('.')
CFG = yaml.safe_load((ROOT / 'tools' / 'animus_strategy_rules.yaml').read_text())

def rx(p, flags=0): return re.compile(p, flags)

GLOBS = CFG['strategy_file_globs']
NS_RE = rx(CFG['template_namespace_regex']) if CFG.get('template_namespace_regex') else None
ALLOW_INLINE = CFG.get('allow_inline_return_scaffold', True)

BSTART = CFG.get('patch_banner_start', '/* ===== ANIMUS TEMPLATE SUGGESTION (auto-inserted) =====')
BEND   = CFG.get('patch_banner_end',   '===== END ANIMUS TEMPLATE SUGGESTION ===== */')

INSTANT_RX = [rx(p, re.S) for p in CFG.get('instant_heuristics', [])]
TIMED_RX   = [rx(p, re.S) for p in CFG.get('timed_heuristics', [])]
MOVE_RX    = [rx(p, re.S) for p in CFG.get('move_heuristics', [])]

SCAFFOLDS = CFG.get('template_scaffolds', {})
REQ_METHODS = ['start','update','stop','invariant_check']

SUG_ENABLE = CFG.get('enable_suggestions', False)
SUG_PATH = CFG.get('suggestion_report_path', 'tools/.strategy_suggestions.json')

def gather_files():
    out = []
    for g in GLOBS:
        out.extend([p for p in ROOT.glob(g) if p.is_file() and p.suffix.lower()=='.gml'])
    return sorted(set(out))

def classify_legacy(text):
    scores = {'instant':0, 'timed':0, 'move':0}
    for r in INSTANT_RX:
        try:
            if r.search(text): scores['instant'] += 1
        except re.error:
            pass
    for r in TIMED_RX:
        try:
            if r.search(text): scores['timed'] += 1
        except re.error:
            pass
    for r in MOVE_RX:
        try:
            if r.search(text): scores['move'] += 1
        except re.error:
            pass
    order = ['timed','move','instant']
    best = max(order, key=lambda k: (scores[k], 2 if k=='timed' else (1 if k=='move' else 0)))
    return best, scores

def find_build_strategy_brace(text):
    m = re.search(r'\bbuild_strategy\s*=\s*function\s*\(', text)
    if not m: return None
    i = text.find('{', m.end())
    if i == -1: return None
    return i

def method_presence(block):
    missing = []
    for name in REQ_METHODS:
        if re.search(rf'\b{name}\s*=\s*function\s*\(', block) is None:
            missing.append(name)
    return missing

def find_inline_strategy_return_spans(text):
    out = []
    for m in re.finditer(r'\breturn\s*\{', text):
        i = m.end()-1
        depth = 1
        while i < len(text) and depth > 0:
            if text[i] == '{': depth += 1
            elif text[i] == '}': depth -= 1
            i += 1
        block = text[m.end():i-1]
        miss = method_presence(block)
        if len(miss) < 4:
            out.append((m.start(), i))
    return out

def make_template_code(kind):
    # Return ready-to-paste GML template call for each kind
    if kind == 'timed':
        return (
            'return Animus_StrategyTemplates.timed({\n'
            "    expected_duration: (Animus_Core.is_callable(self.get_expected_duration) ? self.get_expected_duration() : 0.6),\n"
            "    timeout: undefined,\n"
            "    on_start: function(ctx) { if (Animus_Core.is_callable(self.start)) self.start(ctx); },\n"
            "    on_stop:  function(ctx, reason) { if (Animus_Core.is_callable(self.stop)) self.stop(ctx, reason); }\n"
            '});'
        )
    if kind == 'move':
        return (
            'return Animus_StrategyTemplates.move({\n'
            "    invariant_check: (Animus_Core.is_callable(self.invariant_check) ? self.invariant_check : function(_ctx){ return true; }),\n"
            "    reservation_keys: (Animus_Core.is_callable(self.get_reservation_keys) ? self.get_reservation_keys() : []),\n"
            "    last_invariant_key: (Animus_Core.is_callable(self.get_last_invariant_key) ? self.get_last_invariant_key() : undefined),\n"
            "    on_start: function(ctx) { if (Animus_Core.is_callable(self.start)) self.start(ctx); },\n"
            "    on_stop:  function(ctx, reason) { if (Animus_Core.is_callable(self.stop)) self.stop(ctx, reason); }\n"
            '});'
        )
    # instant
    return (
        'return Animus_StrategyTemplates.instant({\n'
        "    on_start: function(ctx) { if (Animus_Core.is_callable(self.start)) self.start(ctx); },\n"
        "    on_stop: function(ctx, reason) { if (Animus_Core.is_callable(self.stop)) self.stop(ctx, reason); }\n"
        '});'
    )

def emit_suggestions(suggestions):
    try:
        p = ROOT / SUG_PATH
        payload = {
            'generated_at': time.strftime('%Y-%m-%d %H:%M:%S'),
            'non_templated': suggestions
        }
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(payload, indent=2), encoding='utf-8')
        print(f"[emit] suggestions -> {p}")
    except Exception as e:
        print(f"[warn] failed to write suggestions: {e}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--patch', action='store_true')
    ap.add_argument('--strict', action='store_true')
    ap.add_argument('--verbose', action='store_true')
    args = ap.parse_args()

    files = gather_files()
    if args.verbose: print(f"[scan] {len(files)} candidate files")

    suggestions = []
    issues = 0
    touched = 0

    for f in files:
        text = f.read_text(encoding='utf-8', errors='ignore')

        if NS_RE and NS_RE.search(text):
            if args.verbose: print(f"[ok] {f} uses Animus_StrategyTemplates")
            continue

        kind, scores = classify_legacy(text)
        if args.verbose:
            print(f"{f}: non-templated strategy detected -> suggest `{kind}` template (scores={scores})")

        # find anchors
        anchor_idx = None
        anchor_type = None
        brace = find_build_strategy_brace(text)
        if brace is not None:
            anchor_idx = brace
            anchor_type = 'build_strategy'
        else:
            spans = find_inline_strategy_return_spans(text)
            if spans:
                anchor_idx = spans[0][0]
                anchor_type = 'inline_return'

        suggested_code = make_template_code(kind)

        suggestions.append({
            'file': str(f).replace('\\','/'),
            'suggested_kind': kind,
            'scores': scores,
            'anchor_type': anchor_type,
            'anchor_index': anchor_idx,
            'suggested_template_code': suggested_code
        })

        # patch behavior remains: insert comment scaffolds if requested
        inserted = False
        if args.patch and anchor_idx is not None:
            if args.patch:
                # Insert the commented scaffold (non-destructive)
                banner = BSTART + '\n' + SCAFFOLDS.get(kind, '').rstrip() + '\n' + BEND + '\n'
                new_text = text[:anchor_idx] + banner + text[anchor_idx:]
                f.write_text(new_text, encoding='utf-8')
                touched += 1
                inserted = True
                if args.verbose: print(f"[write] injected scaffold in {f}")

        if args.strict or not args.patch:
            if not inserted:
                issues += 1

    # emit JSON suggestions if enabled
    if SUG_ENABLE:
        emit_suggestions(suggestions)

    if args.patch and args.verbose:
        print(f"[result] Scaffolds inserted in {touched} file(s)")

    if issues:
        sys.exit(1)
    print('[result] All strategies templated (or scaffolds present).')

if __name__ == '__main__':
    main()
