#!/usr/bin/env python3
import json, pathlib, time
ROOT = pathlib.Path('.')
SUGG = ROOT / 'tools/.strategy_suggestions.json'

def main():
    data = json.loads(SUGG.read_text(encoding='utf-8'))
    for item in data.get('non_templated', []):
        f = pathlib.Path(item['file'])
        idx = item.get('anchor_index')
        if not f.exists() or idx is None:
            continue
        text = f.read_text(encoding='utf-8')
        stamp = time.strftime('%Y-%m-%d %H:%M:%S')
        banner = f"/* ===== ANIMUS TEMPLATE (from suggestions {stamp}) =====\n"
        code = item['suggested_template_code'].replace('\n', '\n// ')
        tail = "\n===== END ANIMUS TEMPLATE ===== */\n"
        patched = text[:idx] + banner + "// " + code + tail + text[idx:]
        f.write_text(patched, encoding='utf-8')
        print(f"[write] inserted suggestion block in {f}")

if __name__ == '__main__':
    if SUGG.exists():
        main()
    else:
        print('[skip] suggestions file not found')
