import os, re, json
base = r"c:\\Users\\matth\\Documents\\GOAP-in-GML"
modules = {}
for root, dirs, files in os.walk(os.path.join(base, 'GOAP', 'scripts')):
    for f in files:
        if f.endswith('.gml'):
            path = os.path.join(root, f)
            rel = os.path.relpath(path, base).replace('\\', '/')
            module = f[:-4]
            data = modules.setdefault(module, {'files': [], 'functions': [], 'resources': []})
            data['files'].append(rel)
            with open(path, encoding='utf-8') as fh:
                for line in fh:
                    m = re.match(r'\s*function\s+([A-Za-z0-9_]+)\s*\(', line)
                    if m:
                        data['functions'].append(m.group(1))
for f in os.listdir(base):
    if f.endswith('.gml') and not f.startswith('.'):
        path = os.path.join(base, f)
        rel = os.path.relpath(path, base).replace('\\', '/')
        module = f[:-4]
        data = modules.setdefault(module, {'files': [], 'functions': [], 'resources': []})
        data['files'].append(rel)
        with open(path, encoding='utf-8') as fh:
            for line in fh:
                m = re.match(r'\s*function\s+([A-Za-z0-9_]+)\s*\(', line)
                if m:
                    data['functions'].append(m.group(1))
for root, dirs, files in os.walk(os.path.join(base, 'GOAP', 'scripts')):
    for f in files:
        if f.endswith('.yy'):
            path = os.path.join(root, f)
            rel = os.path.relpath(path, base).replace('\\', '/')
            module = f[:-3]
            data = modules.setdefault(module, {'files': [], 'functions': [], 'resources': []})
            data['resources'].append(rel)
print(json.dumps(modules, indent=2))
