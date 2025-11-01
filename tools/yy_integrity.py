#!/usr/bin/env python3
"""
Animus GameMaker integrity checker:
- Validates .yyp resources vs disk
- Validates each Script .yy vs its .gml filename & path
- Catches orphan .gml (no .yy), orphan .yy (no .gml), and yyp references to missing files
- Warns if resource_order is out of sync (optional)
Exit code 1 on any violation.
"""
import sys, json, yaml, pathlib

ROOT = pathlib.Path(".")
CFG = yaml.safe_load((ROOT / "tools" / "yy_rules.yaml").read_text())

def load_json(p):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        die(f"Cannot parse JSON: {p} ({e})")

def die(msg):
    print(f"[FATAL] {msg}")
    sys.exit(1)

def warn(msg):
    print(f"[WARN] {msg}")

def info(msg):
    print(f"[INFO] {msg}")

yyp_path = ROOT / CFG["yyp_path"]
if not yyp_path.exists():
    die(f".yyp not found at {yyp_path}")

yyp = load_json(yyp_path)

# Collect resources declared in .yyp
declared = {}
for res in yyp.get("resources", []):
    rid = res.get("id", {})
    name = rid.get("name")
    path = rid.get("path")
    if not name or not path:
        warn(f"Malformed yyp resource: {res}")
        continue
    declared[path] = name

# Scan disk for .gml files
gml_files = set()
for pat in CFG["script_globs"]:
    for p in ROOT.glob(pat):
        if p.is_file() and p.suffix.lower() == ".gml":
            gml_files.add(p)

issues = 0

def issue(msg):
    global issues
    issues += 1
    print(f"[ISSUE] {msg}")

# 1) For each .gml, check .yy sibling and consistency
for gml in sorted(gml_files):
    folder = gml.parent
    expected_name = gml.stem
    yy = folder / f"{expected_name}.yy"
    if CFG.get("require_script_yy", True):
        if not yy.exists():
            issue(f"Missing .yy for script: {gml}")
            continue
        j = load_json(yy)
        model_name = j.get("name") or j.get("Name")
        if CFG.get("enforce_filename_matches_name", True):
            if model_name and model_name != expected_name:
                issue(f"Name mismatch: {yy} has name '{model_name}' but file is '{expected_name}.gml'")
        proj_rel = yy.relative_to(yyp_path.parent).as_posix()
        if CFG.get("enforce_path_sync", True):
            if proj_rel not in declared:
                issue(f".yyp does not declare script resource for: {proj_rel}")
            else:
                dec_name = declared[proj_rel]
                if model_name and dec_name != model_name:
                    issue(f".yyp declares name '{dec_name}' but {proj_rel} has '{model_name}'")

# 2) Check for orphan .yy without .gml and missing files on disk
for res_path in declared.keys():
    disk_path = (yyp_path.parent / res_path)
    if not disk_path.exists():
        if CFG.get("fail_on_missing_resource", True):
            issue(f".yyp references missing file on disk: {res_path}")
        else:
            warn(f".yyp references missing file on disk: {res_path}")
    else:
        if disk_path.suffix.lower() == ".yy" and "/scripts/" in res_path:
            stem = disk_path.stem
            gml = disk_path.parent / f"{stem}.gml"
            if not gml.exists():
                issue(f"Script resource missing .gml sibling: {disk_path} expects {gml.name}")

# 3) Optional: resource_order sanity
order_path = ROOT / CFG.get("resource_order_file", "")
if order_path and order_path.exists():
    try:
        order_lines = [ln.strip() for ln in order_path.read_text(encoding="utf-8").splitlines() if ln.strip()]
        needed = []
        for gml in sorted(gml_files):
            yy = gml.with_suffix(".yy")
            if yy.exists():
                proj_rel = yy.relative_to(yyp_path.parent).as_posix()
                needed.append(proj_rel)
        missing = [p for p in needed if p not in order_lines]
        for p in missing:
            warn(f"resource_order missing entry for: {p}")
    except Exception as e:
        warn(f"Could not parse resource_order: {e}")

if issues:
    sys.exit(1)
info("YY/YYP integrity OK.")
