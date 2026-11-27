"""Recursos e terreno (neutros): campo de minério, nó de Núcleo, peças de terreno."""
import numpy as np
from kit import Asset, box, crystal, cyl, hull, ring, rot_y

F = "neutro"


def rock(rng, r, h, x=0.0, z=0.0, y=0.0, n=14):
    pts = []
    for _ in range(n):
        ang = rng.uniform(0, 2 * np.pi)
        rr = r * rng.uniform(0.6, 1.0)
        pts.append((x + rr * np.cos(ang), y + rng.uniform(0, h), z + rr * np.sin(ang) * rng.uniform(0.7, 1.0)))
    pts += [(x + r * 0.9 * np.cos(a), y, z + r * 0.9 * np.sin(a)) for a in np.linspace(0, 2 * np.pi, 6, endpoint=False)]
    return hull(pts)


def campo_minerio():
    a = Asset("recurso_minerio", F, "resource", "Campo de minério — recurso principal")
    rng = np.random.default_rng(11)
    for _ in range(7):
        a.add("Rock", rock(rng, rng.uniform(1.0, 2.2), rng.uniform(0.4, 1.0), rng.uniform(-4, 4), rng.uniform(-3, 3)))
    for _ in range(26):
        x, z = rng.uniform(-4.2, 4.2), rng.uniform(-3.2, 3.2)
        h = rng.uniform(0.8, 2.6) * (1.2 - 0.12 * np.hypot(x, z) / 2)
        a.add("Ore", crystal(rng.uniform(0.18, 0.4), max(h, 0.6), int(rng.choice([5, 6])), x=x, y=0.1, z=z,
                             tilt=(rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45))))
    return a


def no_nucleo():
    a = Asset("recurso_nucleo", F, "resource", "Nó de Núcleo — recurso raro, centro do mapa")
    fl = a.group("Float", (0, 4.2, 0))
    rng = np.random.default_rng(5)
    for k in range(9):  # borda de cratera
        ang = k * 2 * np.pi / 9 + rng.uniform(-0.15, 0.15)
        a.add("Rock", rock(rng, rng.uniform(1.2, 1.8), rng.uniform(0.8, 1.6), 4.0 * np.cos(ang), 4.0 * np.sin(ang)))
    a.add("Rock", cyl(3.4, 0.3, "y", 9, y=0.0))
    for k in range(5):
        c = crystal(0.35, rng.uniform(1.0, 1.8), 5, tilt=(rng.uniform(0.3, 0.6), 0))
        c.apply_translation([0, 0.2, -1.6])
        rot_y(c, k * 2 * np.pi / 5)
        a.add("CoreGlow", c)
    a.add("CoreGlow", crystal(0.9, 3.6, 6, y=2.4), fl)
    a.add("CoreGlow", crystal(0.9, 1.4, 6, y=2.45, tilt=(np.pi, 0)), fl)
    a.add("Metal", ring(1.9, 2.05, 0.12, 24, y=4.2), fl)
    return a


def _cliff_ring(a, rng, w, d, h, step=1.6):
    """Colunas de rocha irregulares ao longo do perímetro de um platô w x d."""
    per = []
    for x in np.arange(-w / 2, w / 2 + 0.01, step):
        per += [(x, -d / 2), (x, d / 2)]
    for z in np.arange(-d / 2 + step, d / 2 - 0.01, step):
        per += [(-w / 2, z), (w / 2, z)]
    for x, z in per:
        a.add("Rock", rock(rng, step * 0.75, h * rng.uniform(0.85, 1.05), x, z, n=10))


def terreno_plato():
    a = Asset("terreno_plato", F, "terrain", "Platô 16x16 m — 4 m de altura")
    rng = np.random.default_rng(21)
    W = D = 16.0
    H = 4.0
    # topo vai até a borda exata (8 m) para que platôs vizinhos se encaixem sem fresta;
    # as rochas do penhasco ficam abaixo do topo e somem quando há vizinho
    a.add("Rock", box(W, H, D))
    _cliff_ring(a, rng, W - 0.6, D - 0.6, H - 0.25)
    return a


def terreno_rampa():
    a = Asset("terreno_rampa", F, "terrain", "Rampa 8 m — liga chão ao platô")
    rng = np.random.default_rng(31)
    a.add("Rock", hull([(-4, 0, -4.5), (4, 0, -4.5), (-4, 0, 4.5), (4, 0, 4.5), (-4, 4.0, 4.5), (4, 4.0, 4.5)]))
    for s in (1, -1):
        for z in np.arange(-3.6, 4.6, 1.5):
            hh = 4.0 * (z + 4.5) / 9.0 + 0.4
            a.add("Rock", rock(rng, 0.8, hh, s * 4.4, z, n=8))
    return a


RESOURCES = [campo_minerio, no_nucleo, terreno_plato, terreno_rampa]
