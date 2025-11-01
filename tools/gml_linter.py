#!/usr/bin/env python3
"""Animus / GML linter: repo-aware, deterministic-safety, planner-contract, legacy ban"""
import re
import sys
import pathlib
import yaml
import argparse

ROOT = pathlib.Path(__file__).resolve().parents[1]
cfg_path = ROOT / "tools" / "animus_rules.yaml"
if not cfg_path.exists():
    print("Missing tools/animus_rules.yaml", file=sys.stderr)
    sys.exit(2)

CFG = yaml.safe_load(cfg_path.read_text())

REGEX_ERRORS = []

def compile_regex_or_report(key, pattern, flags=0):
    """Safely compile a regex pattern from config.
    On error, report to stderr and return None (caller must handle skipping).
    """
    if not pattern:
        return None
    try:
        return re.compile(pattern, flags)
    except re.error as e:
        REGEX_ERRORS.append((key, pattern, str(e)))
        sys.stderr.write(f"[gml_linter] Invalid regex in config key '{key}': {e}\n")
        sys.stderr.write(f"[gml_linter] Pattern: {pattern!r}\n")
        return None

def validate_regex_keys(cfg: dict):
    """Validate common regex keys in the config and return list of error messages."""
    errors = []
    # keys we expect to be regex-like
    candidate_keys = [
        'ban_tabs', 'ban_trailing_ws', 'ban_silent_return', 'ban_globals',
        'planner_call_regex', 'planner_old_sig_regex'
    ]
    for k in candidate_keys:
        # nested preference pattern
        if k == 'prefer_snapshot_pattern':
            v = cfg.get('prefer_snapshot_false', {}).get('pattern')
        else:
            v = cfg.get(k)
        if isinstance(v, str) and v.strip():
            try:
                re.compile(v, re.MULTILINE)
            except re.error as e:
                errors.append(f"{k}: {e}  (pattern={v!r})")
    return errors

REGEX_VALIDATION_ERRORS = validate_regex_keys(CFG)
if REGEX_VALIDATION_ERRORS:
    for line in REGEX_VALIDATION_ERRORS:
        sys.stderr.write(f"[gml_linter] {line}\n")

# CLI
ap = argparse.ArgumentParser()
ap.add_argument('--validate-only', action='store_true', dest='validate_only', help='Validate regex config and exit.')
args = ap.parse_args()

# If requested, validate regex config and exit early (do not run scans)
if args.validate_only:
    if REGEX_VALIDATION_ERRORS or REGEX_ERRORS:
        sys.stderr.write('[gml_linter] Configuration regex issues detected.\n')
        for k, pat, err in REGEX_ERRORS:
            sys.stderr.write(f"[gml_linter] key={k} pattern={pat!r} error={err}\n")
        for line in REGEX_VALIDATION_ERRORS:
            sys.stderr.write(f"[gml_linter] {line}\n")
        sys.exit(2)
    print('[gml_linter] regex config OK')
    sys.exit(0)

GML_FILES = [p for p in ROOT.rglob("**/*.gml") if ".git" not in str(p)]
ISSUES = 0

def emit(path, line_no, kind, msg, hint=None):
    global ISSUES
    ISSUES += 1
    print(f"{path}:{line_no}: [{kind}] {msg}")
    if hint:
        # Use ASCII arrow to avoid console encoding issues on some terminals
        print(f"  -> {hint}")

def iter_lines(path):
    text = path.read_text(encoding="utf-8", errors="ignore")
    return text, text.splitlines()

def rx(pattern, flags=0):
    try:
        return re.compile(pattern, flags)
    except re.error:
        return None

# ---------- Generic scans ----------
RX_TAB     = compile_regex_or_report('ban_tabs', CFG.get('ban_tabs'))
RX_TWS     = compile_regex_or_report('ban_trailing_ws', CFG.get('ban_trailing_ws'))
RX_SILENT  = compile_regex_or_report('ban_silent_return', CFG.get('ban_silent_return'), re.M)
RX_GLOBAL  = compile_regex_or_report('ban_globals', CFG.get('ban_globals'))
RX_PLANNER = compile_regex_or_report('planner_call_regex', CFG.get('planner_call_regex'), re.S)

# compile joined ban lists into a single alternation for scanning
RX_BANS = []
if CFG.get('ban_legacy'):
    RX_BANS.append(('legacy', compile_regex_or_report('ban_legacy', '|'.join(CFG.get('ban_legacy', [])))))
RX_RANDOM = []
if CFG.get('ban_random'):
    RX_RANDOM.append(('nondeterminism.random', compile_regex_or_report('ban_random', '|'.join(CFG.get('ban_random', [])))))
RX_WALL = []
if CFG.get('ban_wallclock'):
    RX_WALL.append(('nondeterminism.wallclock', compile_regex_or_report('ban_wallclock', '|'.join(CFG.get('ban_wallclock', [])))))

# optional old-signature detector
RX_PLANNER_OLD = compile_regex_or_report('planner_old_sig_regex', CFG.get('planner_old_sig_regex'), re.S)

STRAT_METHODS = CFG.get("strategy_required_methods", [])

def count_args(arg_str):
    # count top-level commas not inside () [] {}
    depth = 0
    cnt = 1 if arg_str.strip() else 0
    for ch in arg_str:
        if ch in "([{": depth += 1
        elif ch in ")]}": depth -= 1
        elif ch == "," and depth == 0: cnt += 1
    return cnt

def scan_generic(path):
    text, lines = iter_lines(path)
    # tabs & trailing whitespace
    for i, ln in enumerate(lines, 1):
        if RX_TAB and RX_TAB.search(ln): emit(path, i, "style.tabs", "Tab character")
        if RX_TWS and RX_TWS.search(ln): emit(path, i, "style.trailing_ws", "Trailing whitespace")
    # silent returns
    if RX_SILENT:
        for m in RX_SILENT.finditer(text):
            line_no = text.count('\n', 0, m.start()) + 1
            emit(path, line_no, "logic.silent_return", "Use explicit outcome instead of bare `return;`")
    # globals
    if RX_GLOBAL:
        for m in RX_GLOBAL.finditer(text):
            token = m.group(0)
            if token not in CFG.get("allowed_globals", []):
                line_no = text.count('\n', 0, m.start()) + 1
                emit(path, line_no, "arch.global_state", f"Global usage `{token}` not allowed", "Refactor to pass state/context")
    # legacy bans and nondeterminism / wallclock
    for kind, rxp in RX_BANS + RX_RANDOM + RX_WALL:
        if rxp is None: continue
        for m in rxp.finditer(text):
            line_no = text.count('\n', 0, m.start()) + 1
            emit(path, line_no, kind, f"Forbidden pattern: `{m.group(0)}`")

def scan_planner_calls(path):
    if not RX_PLANNER:
        return
    text, _ = iter_lines(path)
    for m in RX_PLANNER.finditer(text):
        # prefer explicit (?P<args>) capture if provided in regex
        args = None
        try:
            if 'args' in m.re.groupindex:
                args = m.group('args')
        except Exception:
            args = None

        if args is None:
            # fallback: naive capture of (...) region following the match
            start = m.end()
            depth = 1
            i = start
            while i < len(text) and depth > 0:
                if text[i] == "(":
                    depth += 1
                elif text[i] == ")":
                    depth -= 1
                i += 1
            args = text[start:i-1]
            tail = text[i:i+200]
        else:
            # compute tail for plan_shape assertion from end of match
            tail = text[m.end():m.end()+200]

        argc = count_args(args)
        req = CFG.get('required_arg_count', 0)
        if req and argc != req:
            line_no = text.count('\n', 0, m.start()) + 1
            emit(path, line_no, 'contract.planner_args',
                 f"`planner.plan(...)` expects {req} args, found {argc}",
                 'Use: plan(agent, goals_to_check, last_goal, memory)')

        # additionally detect known old 3-arg signature if configured
        if RX_PLANNER_OLD:
            try:
                # check old signature in the matched span
                span = m.group(0)
                if RX_PLANNER_OLD.search(span):
                    line_no = text.count('\n', 0, m.start()) + 1
                    emit(path, line_no, 'contract.planner_old_sig',
                         'Found legacy planner.plan(...) signature with 3 args; consider adding memory argument',
                         'Upgrade to planner.plan(agent, goals, last_goal, memory)')
            except Exception:
                pass

        # encourage plan shape assertion nearby
        if 'assert_plan_shape' not in tail:
            line_no = text.count('\n', 0, m.start()) + 1
            emit(path, line_no, 'contract.plan_shape.assertion',
                 'Missing `Animus_Core.assert_plan_shape(plan)` after planner call')

def scan_strategy_structs(path):
    text, _ = iter_lines(path)
    # Look for build_strategy returning a struct literal `{ ... }`
    for m in re.finditer(r'\bbuild_strategy\b.*?{', text, re.S):
        struct_start = m.end()-1
        depth = 1
        i = struct_start
        while i < len(text) and depth > 0:
            if text[i] == "{": depth += 1
            elif text[i] == "}": depth -= 1
            i += 1
        block = text[struct_start:i]
        missing = []
        for name in STRAT_METHODS:
            if re.search(rf'\b{name}\s*=\s*function\s*\(', block) is None:
                missing.append(name)
        if missing:
            line_no = text.count('\n', 0, m.start()) + 1
            emit(path, line_no, "contract.strategy_iface",
                 f"Strategy missing methods: {', '.join(missing)}",
                 "Use templates in Animus_StrategyTemplates.gml or implement required methods.")

def scan_snapshot_usage(path):
    pref = CFG.get("prefer_snapshot_false", {})
    if not pref.get("enabled", False):
        return
    text, _ = iter_lines(path)
    for m in re.finditer(pref.get("pattern", ""), text):
        arg = m.group(1).strip()
        line_no = text.count('\n', 0, m.start()) + 1
        if arg == "" or arg.lower() == "true":
            emit(path, line_no, "perf.snapshot",
                 "Prefer `memory.snapshot(false)` before planning",
                 "Pass false to avoid deep clone when stable input suffices")

def file_matches(path, globs):
    return any(path.match(glob) for glob in globs)

def main():
    for f in GML_FILES:
        scan_generic(f)
        scan_planner_calls(f)
        scan_strategy_structs(f)
        scan_snapshot_usage(f)

    # Enforce planner/agent/executor contracts more strictly in core files
    for f in GML_FILES:
        # Planner must not reference legacy nodes
        if any(f.match(glob) for glob in CFG.get("core_files", {}).get("planner", [])):
            text, _ = iter_lines(f)
            if re.search("|".join(CFG.get("ban_legacy", [])), text):
                emit(f, 1, "arch.legacy_in_planner", "Planner references legacy plan containers")

        # Agent should orchestrate only: flag long function bodies in tick
        if any(f.match(glob) for glob in CFG.get("core_files", {}).get("agent", [])):
            text, _ = iter_lines(f)
            for m in re.finditer(r'\bagent(?:\.|)?tick\s*\([^)]*\)\s*{', text):
                start = m.end()
                depth = 1; i = start
                while i < len(text) and depth > 0:
                    if text[i] == "{": depth += 1
                    elif text[i] == "}": depth -= 1
                    i += 1
                body = text[start:i-1]
                # heuristic: too many assignments/branches inside tick
                if len(re.findall(r'=', body)) > 40 or len(re.findall(r'\bif\b|\bswitch\b', body)) > 12:
                    line_no = text.count('\n', 0, m.start()) + 1
                    emit(f, line_no, "arch.agent_too_heavy",
                         "Agent.tick seems to contain heavy logic (heuristic)",
                         "Delegate logic to planner/executor; keep tick orchestration-only.")

    # If there were regex validation errors, print a concise summary and fail
    if REGEX_ERRORS or REGEX_VALIDATION_ERRORS:
        sys.stderr.write("[gml_linter] Configuration regex issues detected.\n")
        for k, pat, err in REGEX_ERRORS:
            sys.stderr.write(f"[gml_linter] key={k} pattern={pat!r} error={err}\n")
        for line in REGEX_VALIDATION_ERRORS:
            sys.stderr.write(f"[gml_linter] {line}\n")
        # Exit with distinct code so CI can detect config problems
        sys.exit(2)

    if ISSUES:
        sys.exit(1)

if __name__ == "__main__":
    main()
