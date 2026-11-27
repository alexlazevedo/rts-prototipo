"""Gera todos os assets (.glb) e o manifest.json. Uso: python3 build_all.py <pasta_saida> [filtro]"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(__file__))
import militar
mods = [militar]
try:
    import energia; mods.append(energia)
except ImportError:
    pass
try:
    import recursos; mods.append(recursos)
except ImportError:
    pass

out = sys.argv[1] if len(sys.argv) > 1 else "out"
filt = sys.argv[2] if len(sys.argv) > 2 else ""
os.makedirs(out, exist_ok=True)
manifest = []
for mod in mods:
    for fn in getattr(mod, "UNITS", []) + getattr(mod, "BUILDINGS", []) + getattr(mod, "RESOURCES", []):
        a = fn()
        if filt and filt not in a.name:
            continue
        t = time.time()
        info = a.export(os.path.join(out, a.name + ".glb"))
        info["kb"] = round(os.path.getsize(os.path.join(out, a.name + ".glb")) / 1024)
        manifest.append(info)
        print(f"{a.name:28s} {info['tris']:6d} tri  {info['kb']:5d} KB  {info['size_m']}  grupos={info['groups']}  ({time.time()-t:.1f}s)")
if not filt:
    json.dump(manifest, open(os.path.join(out, "manifest.json"), "w"), indent=1, ensure_ascii=False)
