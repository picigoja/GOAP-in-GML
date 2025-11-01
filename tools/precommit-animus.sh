#!/usr/bin/env bash
set -euo pipefail
echo "[precommit] Animus sanity & integrity"
python tools/gml_linter.py
python tools/yy_integrity.py
