#!/usr/bin/env python3
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
GML = list(ROOT.rglob("**/*.gml"))
bad = 0

rules = [
  ("Silent return (no value)", re.compile(r'^\s*return\s*;\s*$', re.M)),
  ("Tab characters", re.compile(r'\t')),
  ("Trailing whitespace", re.compile(r'[ \t]+$', re.M)),
  ("Global usage", re.compile(r'\bglobal\.\w+')),
  ("Legacy GOAP_Node/Plan creation", re.compile(r'\bGOAP_Node\b|\bGOAP_ActionPlan\b')),
]

for f in GML:
    try:
        text = f.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        continue
    for name, rx in rules:
        if rx:
            for m in rx.finditer(text):
                lineno = text.count('\n', 0, m.start()) + 1
                print(f"{f}:{lineno}: {name}")
                bad += 1
    # crude strategy interface check
    if "build_strategy" in text and "function" in text:
        need = ["start", "update", "stop", "invariant_check"]
        missing = [n for n in need if re.search(rf'\b{n}\s*=\s*function', text) is None]
        if missing:
            print(f"{f}:1: Strategy missing methods: {', '.join(missing)}")
            bad += 1

sys.exit(1 if bad else 0)
