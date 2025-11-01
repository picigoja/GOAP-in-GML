#!/usr/bin/env python3
"""Animus / GML linter: repo-aware, deterministic-safety, planner-contract, legacy ban"""
import re
import sys
import pathlib
import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
cfg_path = ROOT / "tools" / "animus_rules.yaml"
if not cfg_path.exists():
    print("Missing tools/animus_rules.yaml", file=sys.stderr)
    sys.exit(2)

CFG = yaml.safe_load(cfg_path.read_text())

GML_FILES = [p for p in ROOT.rglob("**/*.gml") if ".git" not in str(p)]
ISSUES = 0

def emit(path, line_no, kind, msg, hint=None):
    global ISSUES
    ISSUES += 1
    print(f"{path}:{line_no}: [{kind}] {msg}")
    if hint:
        print(f"  ↳ {hint}")

def iter_lines(path):
    text = path.read_text(encoding="utf-8", errors="ignore")
    return text, text.splitlines()

def rx(pattern, flags=0):
    return re.compile(pattern, flags)

# ---------- Generic scans ----------
RX_TAB     = rx(CFG["ban_tabs"]) if CFG.get("ban_tabs") else None
RX_TWS     = rx(CFG["ban_trailing_ws"]) if CFG.get("ban_trailing_ws") else None
RX_SILENT  = rx(CFG["ban_silent_return"], re.M) if CFG.get("ban_silent_return") else None
RX_GLOBAL  = rx(CFG["ban_globals"]) if CFG.get("ban_globals") else None
RX_PLANNER = rx(CFG["planner_call_regex"]) if CFG.get("planner_call_regex") else None

RX_BANS = [("legacy", rx("|".join(CFG.get("ban_legacy", []))))] if CFG.get("ban_legacy") else []
RX_RANDOM = [("nondeterminism.random", rx("|".join(CFG.get("ban_random", []))))] if CFG.get("ban_random") else []
RX_WALL   = [("nondeterminism.wallclock", rx("|".join(CFG.get("ban_wallclock", []))))] if CFG.get("ban_wallclock") else []

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
        # naive capture of (...) region
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
        argc = count_args(args)
        if argc != CFG.get("required_arg_count", 0):
            line_no = text.count('\n', 0, m.start()) + 1
            emit(path, line_no, "contract.planner_args",
                 f"`planner.plan(...)` expects {CFG['required_arg_count']} args, found {argc}",
                 "Use: plan(agent, goals_to_check, last_goal, memory)")
        # encourage plan shape assertion nearby
        tail = text[i:i+200]
        if "assert_plan_shape" not in tail:
            line_no = text.count('\n', 0, m.start()) + 1
            emit(path, line_no, "contract.plan_shape.assertion",
                 "Missing `Animus_Core.assert_plan_shape(plan)` after planner call")

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

    if ISSUES:
        sys.exit(1)

if __name__ == "__main__":
    main()
