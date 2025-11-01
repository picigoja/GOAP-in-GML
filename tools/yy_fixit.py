#!/usr/bin/env python3
"""
yy_fixit.py — GameMaker script rename/repair assistant for Animus

Usage:
  # Rename a script (Folder/OldName.{gml,yy}) to (Folder/NewName.{gml,yy})
  python tools/yy_fixit.py rename --script "GOAP/scripts/Animus_Planner/Animus_Planner.gml" --new-name "Animus_PlannerV2"

  # Move + rename (change folder and stem)
  python tools/yy_fixit.py rename --script "GOAP/scripts/Animus_Planner/Animus_Planner.gml" \
       --new-folder "GOAP/scripts/Animus_PlannerV2" --new-name "Animus_PlannerV2"

  # Repair a mismatch (name/path drift); picks a source of truth (default: filesystem)
  python tools/yy_fixit.py repair --script "GOAP/scripts/Animus_Planner/Animus_Planner.gml"

Flags:
  --apply   actually perform changes (default is dry-run)
  --force   allow overwriting existing files (use carefully)
  --truth=[fs|yy|yyp]  choose source of truth when repairing (default fs)

Exits non-zero on errors to play nice with CI.
"""
import argparse, json, pathlib, shutil, sys, time

ROOT = pathlib.Path(".")
YYP_PATH = ROOT / "GOAP" / "GOAP.yyp"
ORDER_PATH = ROOT / "GOAP" / "GOAP.resource_order"

def die(msg): print(f"[FAIL] {msg}"); sys.exit(1)
def info(msg): print(f"[INFO] {msg}")
def warn(msg): print(f"[WARN] {msg}")

def load_json(p: pathlib.Path):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        die(f"Failed to read/parse JSON {p}: {e}")

def dump_json(p: pathlib.Path, data, apply_changes: bool):
    stamp = time.strftime("%Y%m%d-%H%M%S")
    backup = p.with_suffix(p.suffix + f".bak.{stamp}")
    if apply_changes:
        shutil.copy2(p, backup)
        p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        info(f"Updated {p} (backup: {backup})")
    else:
        info(f"(dry-run) Would update {p} (backup would be {backup})")

def rel_to_project(p: pathlib.Path) -> str:
    return p.relative_to(YYP_PATH.parent).as_posix()

def find_script_pair(script_gml: pathlib.Path):
    if not script_gml.exists():
        die(f"Script .gml not found: {script_gml}")
    yy = script_gml.with_suffix(".yy")
    if not yy.exists():
        warn(f"Script .yy is missing beside {script_gml}")
    return yy

def yyp_find_resource(yyp, script_yy_rel: str):
    for res in yyp.get("resources", []):
        rid = res.get("id", {})
        if rid.get("path") == script_yy_rel:
            return res
    return None

def ensure_resource_order_has(path_rel: str, apply_changes: bool):
    if not ORDER_PATH.exists():
        warn(f"{ORDER_PATH} not found; skipping order update.")
        return
    lines = [ln.strip() for ln in ORDER_PATH.read_text(encoding="utf-8").splitlines()]
    if path_rel in lines:
        return
    lines.append(path_rel)
    if apply_changes:
        ORDER_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
        info(f"Added to resource_order: {path_rel}")
    else:
        info(f"(dry-run) Would add to resource_order: {path_rel}")

def cmd_git_mv(src: pathlib.Path, dst: pathlib.Path, apply_changes: bool, force: bool):
    if dst.exists() and not force:
        die(f"Destination exists: {dst} (use --force to overwrite)")
    dst.parent.mkdir(parents=True, exist_ok=True)
    if apply_changes:
        try:
            import subprocess
            subprocess.run(["git", "mv", str(src), str(dst)], check=True)
            info(f"git mv {src} -> {dst}")
        except Exception:
            shutil.move(str(src), str(dst))
            info(f"mv {src} -> {dst}")
    else:
        info(f"(dry-run) Would move {src} -> {dst}")

def rename_script(script_gml: pathlib.Path, new_folder: pathlib.Path, new_name: str, apply_changes: bool, force: bool):
    old_gml = script_gml
    old_yy = find_script_pair(old_gml)
    if old_yy is None or not old_yy.exists():
        die("Cannot proceed without Script.yy")

    new_dir = new_folder if new_folder else old_gml.parent
    new_gml = new_dir / f"{new_name}.gml"
    new_yy  = new_dir / f"{new_name}.yy"

    print("=== PLAN ===")
    print(f"Move {old_gml} -> {new_gml}")
    print(f"Move {old_yy} -> {new_yy}")
    print("Update Script.yy: field `name`")
    print("Update GOAP.yyp:   id.path & id.name")
    if ORDER_PATH.exists(): print("Ensure GOAP.resource_order contains new path")

    cmd_git_mv(old_gml, new_gml, apply_changes, force)
    cmd_git_mv(old_yy, new_yy, apply_changes, force)

    yy_json = load_json(new_yy)
    yy_json["name"] = new_name
    dump_json(new_yy, yy_json, apply_changes)

    yyp = load_json(YYP_PATH)
    old_rel = rel_to_project(old_yy)
    new_rel = rel_to_project(new_yy)

    res = yyp_find_resource(yyp, old_rel) or yyp_find_resource(yyp, new_rel)
    if not res:
        warn(f"Resource for {old_rel} not found in .yyp; creating new entry")
        yyp.setdefault("resources", []).append({"id": {"name": new_name, "path": new_rel}})
    else:
        rid = res["id"]
        rid["name"] = new_name
        rid["path"] = new_rel
    dump_json(YYP_PATH, yyp, apply_changes)

    ensure_resource_order_has(new_rel, apply_changes)

def repair(script_gml: pathlib.Path, truth: str, apply_changes: bool, force: bool):
    yy = find_script_pair(script_gml)
    if not yy or not yy.exists():
        die("Repair requires a Script.yy next to the .gml")

    yyp = load_json(YYP_PATH)
    yy_json = load_json(yy)
    fs_name = script_gml.stem
    yy_name = yy_json.get("name", "")
    rel = rel_to_project(yy)
    res = yyp_find_resource(yyp, rel)

    if truth == "fs":
        desired_name = fs_name
    elif truth == "yy":
        desired_name = yy_name or fs_name
    else:
        desired_name = (res["id"]["name"] if res and res.get("id") and res["id"].get("name") else fs_name)

    ok = True
    if yy_name != desired_name: ok = False
    if res and res["id"].get("name") != desired_name: ok = False

    if ok:
        info("Nothing to repair; names and paths are aligned.")
        return

    print("=== PLAN (repair) ===")
    if fs_name != desired_name:
        print(f"Rename file stems to '{desired_name}'")
    print("Update Script.yy `name` and YYP `id.name`")

    if fs_name != desired_name:
        new_gml = script_gml.with_name(desired_name + ".gml")
        new_yy  = yy.with_name(desired_name + ".yy")
        cmd_git_mv(script_gml, new_gml, apply_changes, force)
        cmd_git_mv(yy, new_yy, apply_changes, force)
        script_gml, yy = new_gml, new_yy
        rel = rel_to_project(yy)

    yy_json["name"] = desired_name
    dump_json(yy, yy_json, apply_changes)

    if not res:
        warn(f".yyp missing resource for {rel}; creating")
        yyp.setdefault("resources", []).append({"id": {"name": desired_name, "path": rel}})
    else:
        res["id"]["name"] = desired_name
        res["id"]["path"] = rel
    dump_json(YYP_PATH, yyp, apply_changes)

    ensure_resource_order_has(rel, apply_changes)

def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("rename", help="move/rename a script")
    a.add_argument("--script", required=True, help="Path to .gml")
    a.add_argument("--new-name", required=True, help="New stem (without extension)")
    a.add_argument("--new-folder", default=None, help="Optional new folder for the script")
    a.add_argument("--apply", action="store_true")
    a.add_argument("--force", action="store_true")

    r = sub.add_parser("repair", help="repair mismatched names/paths")
    r.add_argument("--script", required=True, help="Path to .gml")
    r.add_argument("--truth", choices=["fs", "yy", "yyp"], default="fs")
    r.add_argument("--apply", action="store_true")
    r.add_argument("--force", action="store_true")

    args = ap.parse_args()
    script = pathlib.Path(args.script)

    if args.cmd == "rename":
        new_folder = pathlib.Path(args.new_folder) if args.new_folder else None
        rename_script(script, new_folder, args.new_name, args.apply, args.force)
    else:
        repair(script, args.truth, args.apply, args.force)

if __name__ == "__main__":
    main()
