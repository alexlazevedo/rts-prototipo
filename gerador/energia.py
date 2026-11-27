"""Facção Energia — unidades e prédios.
Linguagem de formas: monólitos e prismas brancos, juntas finas, núcleos escuros,
brilho verde-água. Tudo flutua: sem rodas, sem pernas. Partes que giram ficam
em grupos próprios (Ring, Orbit, Turret)."""
import numpy as np
from kit import Asset, box, cbox, crystal, cyl, hull, octa, prism, ring, rot_x, rot_y, sphere, mirror_x

F = "energia"


def hover_glow(a, r, y, x=0.0, z=0.0, group="Body"):
    """Disco de sustentação sob unidades flutuantes."""
    a.add("Glow", cyl(r, 0.05, "y", 20, x=x, y=y, z=z), group)


# ================================================================ unidades
def drone_extrator():
    a = Asset("energia_drone_extrator", F, "unit", "Drone extrator — coletor")
    Y = 1.6
    a.add("Shell", octa(1.25, 0.75, 1.7, y=Y))
    a.add("ShellAlt", octa(0.8, 0.45, 1.1, y=Y + 0.45))
    a.add("Glow", ring(1.05, 1.15, 0.12, 16, y=Y))
    a.add("Core", hull([(-0.45, Y - 0.3, -0.45), (0.45, Y - 0.3, -0.45), (-0.45, Y - 0.3, 0.45), (0.45, Y - 0.3, 0.45), (0, Y - 1.15, 0)]))
    a.add("Glow", sphere(0.14, 1, y=Y - 1.15))
    a.add("TeamColor", box(0.5, 0.08, 1.9, y=Y + 0.7, z=0.1))
    a.add("TeamColor", ring(1.15, 1.32, 0.1, 16, y=Y + 0.08))
    # berço traseiro com minério carregado
    a.add("ShellAlt", ring(0.55, 0.68, 0.18, 12, y=Y + 0.1, z=1.9))
    for i, (dx, h) in enumerate(((-0.15, 0.7), (0.18, 0.55), (0.0, 0.85))):
        a.add("Ore", crystal(0.16, h, 5, x=dx, y=Y - 0.15, z=1.9 + (i - 1) * 0.12, tilt=(0.2 * (i - 1), 0.25 * (1 - i))))
    for s in (1, -1):  # aletas
        fin = hull([(0.9, Y, -0.6), (0.9, Y, 0.6), (1.9, Y + 0.05, 0.9), (1.9, Y + 0.05, 1.2), (0.9, Y + 0.12, 0), (1.9, Y + 0.16, 1.05)])
        a.add("Shell", fin if s > 0 else mirror_x(fin))
    hover_glow(a, 0.7, 0.35)
    return a


def sentinela():
    a = Asset("energia_sentinela", F, "unit", "Sentinela flutuante — terrestre leve")
    Y = 1.3
    a.add("Shell", octa(0.75, 0.5, 2.1, y=Y))
    a.add("ShellAlt", octa(0.45, 0.32, 1.3, y=Y + 0.35, z=0.3))
    a.add("Core", octa(0.4, 0.3, 0.7, y=Y, z=-1.6))
    a.add("Glow", sphere(0.2, 1, y=Y, z=-2.1))
    for s in (1, -1):
        blade = hull([(0.5, Y, -0.9), (0.5, Y + 0.1, -0.9), (2.0, Y - 0.15, 0.7), (2.0, Y - 0.05, 0.7),
                      (0.5, Y, 0.8), (0.5, Y + 0.1, 0.8), (1.6, Y - 0.12, 1.2)])
        tip = hull([(1.75, Y - 0.16, 0.55), (2.05, Y - 0.16, 0.7), (1.65, Y - 0.13, 1.25),
                    (1.75, Y - 0.04, 0.55), (2.05, Y - 0.04, 0.7), (1.65, Y - 0.02, 1.25)])
        a.add("Shell", blade if s > 0 else mirror_x(blade))
        a.add("TeamColor", tip if s > 0 else mirror_x(tip))
        st = hull([(0.7, Y + 0.08, -0.4), (1.6, Y - 0.05, 0.55), (0.7, Y + 0.12, -0.1), (1.6, Y - 0.01, 0.85),
                   (0.7, Y + 0.16, -0.4), (1.6, Y + 0.03, 0.55)])
        a.add("TeamColor", st if s > 0 else mirror_x(st))
    a.add("Glow", box(0.9, 0.06, 0.06, y=Y + 0.05, z=1.95))
    hover_glow(a, 0.55, 0.3)
    return a


def obelisco():
    a = Asset("energia_obelisco", F, "unit", "Obelisco de cerco — terrestre pesada")
    rg = a.group("Ring", (0, 3.4, 0))
    a.add("Shell", prism(1.15, 2.6, 6, y=0.9, r_top=0.95))
    a.add("Core", prism(1.0, 0.5, 6, y=3.45, r_top=1.0))
    a.add("Shell", prism(0.95, 2.6, 6, y=3.9, r_top=0.45))
    a.add("ShellAlt", prism(1.3, 0.35, 6, y=0.55, r_top=1.15))
    a.add("TeamColor", prism(1.2, 0.3, 6, y=0.9, r_top=1.13))
    for ang in (0, np.pi):  # faixas de time em duas faces
        st = box(0.35, 4.6, 0.06, y=1.1, z=-0.98)
        rot_y(st, ang + np.pi / 6)
        a.add("TeamColor", st)
    a.add("Glow", crystal(0.4, 1.4, 6, y=6.9))
    a.add("Glow", crystal(0.4, 0.6, 6, y=6.95, tilt=(np.pi, 0)))
    a.add("ShellAlt", ring(1.6, 1.8, 0.14, 32, y=3.7), rg)
    a.add("ShellAlt", rot_x(ring(1.95, 2.1, 0.1, 32, y=3.4), 0.35, (0, 3.4, 0)), rg)
    for k in range(3):
        n = crystal(0.12, 0.5, 4, y=3.55)
        n.apply_translation([1.7, 0, 0])
        rot_y(n, k * 2 * np.pi / 3)
        a.add("Glow", n, rg)
    hover_glow(a, 1.0, 0.3)
    return a


def lamina():
    a = Asset("energia_lamina", F, "unit", "Lâmina aérea — aérea")
    Y = 6.0
    a.add("Shell", octa(0.7, 0.42, 2.6, y=Y, z=0.2))
    a.add("ShellAlt", octa(0.42, 0.3, 1.5, y=Y + 0.3, z=0.6))
    a.add("Core", hull([(0, Y + 0.32, -1.6), (0.3, Y + 0.38, -0.7), (-0.3, Y + 0.38, -0.7), (0, Y + 0.6, -0.5)]))
    for s in (1, -1):
        wing = hull([(0.45, Y - 0.05, -1.1), (0.45, Y + 0.12, -1.1), (0.45, Y - 0.05, 1.5), (0.45, Y + 0.12, 1.5),
                     (3.7, Y - 0.35, 1.9), (3.7, Y - 0.25, 1.9), (3.3, Y - 0.32, 2.5), (3.3, Y - 0.22, 2.5)])
        prong = hull([(0.95, Y - 0.12, -0.2), (1.25, Y - 0.12, -0.2), (0.95, Y + 0.08, -0.2), (1.25, Y + 0.08, -0.2),
                      (1.05, Y - 0.04, -3.3), (1.15, Y - 0.04, -3.3)])
        lead = hull([(0.5, Y + 0.13, -1.0), (0.5, Y + 0.13, -0.55), (3.6, Y - 0.22, 1.85), (3.45, Y - 0.22, 2.1),
                     (0.5, Y + 0.17, -1.0), (0.5, Y + 0.17, -0.55), (3.6, Y - 0.18, 1.85), (3.45, Y - 0.18, 2.1)])
        a.add("TeamColor", lead if s > 0 else mirror_x(lead))
        tip = hull([(3.35, Y - 0.36, 1.7), (3.8, Y - 0.36, 1.95), (3.35, Y - 0.33, 2.6),
                    (3.35, Y - 0.2, 1.7), (3.8, Y - 0.22, 1.95), (3.35, Y - 0.19, 2.6)])
        pod = cyl(0.26, 1.3, "z", 8, x=1.1, y=Y - 0.02, z=1.4, r2=0.2)
        for mat, m in (("Shell", wing), ("ShellAlt", prong), ("TeamColor", tip), ("ShellAlt", pod)):
            a.add(mat, m if s > 0 else mirror_x(m))
        g = cyl(0.19, 0.05, "z", 8, x=1.1, y=Y - 0.02, z=2.07)
        a.add("Glow", g if s > 0 else mirror_x(g))
        gt = crystal(0.06, 0.35, 4, x=1.1, y=Y - 0.04, z=-3.2, tilt=(-np.pi / 2, 0))
        a.add("Glow", gt if s > 0 else mirror_x(gt))
    a.add("Glow", box(0.5, 0.1, 0.08, y=Y + 0.05, z=2.75))
    return a


def prisma_defesa():
    a = Asset("energia_prisma", F, "unit", "Prisma de defesa — antiaéreo")
    orb = a.group("Orbit", (0, 2.2, 0))
    a.add("ShellAlt", prism(0.9, 0.4, 3, y=0.6, r_top=0.75, rot=np.pi / 2))
    a.add("Shell", prism(0.7, 2.6, 3, y=1.0, r_top=0.35, rot=np.pi / 2))
    a.add("Core", prism(0.62, 0.35, 3, y=2.0, r_top=0.6, rot=np.pi / 2))
    a.add("Glow", crystal(0.22, 0.7, 3, y=3.55))
    a.add("TeamColor", prism(0.72, 0.16, 3, y=1.4, r_top=0.66, rot=np.pi / 2))
    for k in range(3):
        p = prism(0.28, 1.3, 3, y=-0.65, r_top=0.08)
        p.apply_transform(np.eye(4))
        rot_x(p, -0.45)
        p.apply_translation([0, 2.2, -1.5])
        rot_y(p, k * 2 * np.pi / 3, (0, 0, 0))
        a.add("Shell", p, orb)
        g = sphere(0.1, 1, y=2.2 + 0.58, z=-1.5 - 0.28)
        rot_y(g, k * 2 * np.pi / 3)
        a.add("Glow", g, orb)
    a.add("Glow", ring(1.45, 1.52, 0.06, 32, y=2.2), orb)
    a.add("TeamColor", prism(0.92, 0.22, 3, y=0.98, r_top=0.8, rot=np.pi / 2))
    hover_glow(a, 0.75, 0.3)
    return a


# ================================================================ prédios
def plinth(a, r, h=0.8):
    a.add("ShellAlt", prism(r, h, 6, y=0.0, r_top=r * 0.94))
    a.add("TeamColor", prism(r * 0.95, 0.08, 6, y=h, r_top=r * 0.93))
    a.add("Shell", prism(r * 0.9, 0.2, 6, y=h, r_top=r * 0.86))


def base_central():
    a = Asset("energia_base", F, "building", "Base central — sede, recebe minério")
    sh = a.group("Shards", (0, 8.5, 0))
    plinth(a, 9.0, 1.0)
    a.add("Shell", prism(4.2, 3.0, 6, y=1.2, r_top=3.6))
    a.add("Core", prism(3.4, 0.9, 6, y=4.2, r_top=3.4))
    a.add("Shell", prism(3.2, 8.5, 6, y=5.1, r_top=0.6))
    a.add("Glow", crystal(0.6, 2.2, 6, y=13.4))
    for k in range(6):  # contrafortes
        ang = k * np.pi / 3
        bt = hull([(4.0, 1.2, -0.35), (4.0, 1.2, 0.35), (6.5, 1.2, -0.3), (6.5, 1.2, 0.3), (3.6, 6.5, -0.25), (3.6, 6.5, 0.25)])
        rot_y(bt, ang)
        a.add("ShellAlt", bt)
    for z in (-1, 1):  # portais de entrega de minério
        p = box(2.4, 2.2, 0.3, y=1.2, z=-4.0)
        rot_y(p, 0.55 * z)
        a.add("Glow", p)
    for k in range(3):
        c = crystal(0.7, 3.2, 5, y=7.2, tilt=(0.15, 0))
        c.apply_translation([5.2, 0, 0])
        rot_y(c, k * 2 * np.pi / 3 + 0.4)
        a.add("Shell", c, sh)
    return a


def fabrica():
    a = Asset("energia_fabrica", F, "building", "Fábrica — unidades terrestres")
    plinth(a, 7.0, 0.8)
    for s in (1, -1):
        a.add("Shell", prism(1.4, 8.0, 4, x=s * 3.6, y=1.0, r_top=0.9, rot=np.pi / 4))
        a.add("Core", box(0.4, 6.0, 0.4, x=s * 2.55, y=1.5, z=0))
        a.add("TeamColor", box(0.08, 5.0, 0.6, x=s * 4.6, y=2.0))
    a.add("ShellAlt", cbox(9.0, 1.0, 1.8, 0.4, y=8.4))
    a.add("Glow", box(4.8, 6.4, 0.12, y=1.3))  # campo de energia do portal
    a.add("Glow", crystal(0.35, 1.2, 6, y=9.4))
    for k, ang in enumerate((0.9, 2.2, 4.1, 5.4)):
        pl = prism(0.45, 2.2, 4, y=0.9, r_top=0.15)
        pl.apply_translation([5.3, 0, 0])
        rot_y(pl, ang)
        a.add("ShellAlt", pl)
    return a


def hangar():
    a = Asset("energia_hangar", F, "building", "Hangar — unidades aéreas")
    rg = a.group("Ring", (0, 6.0, 0))
    plinth(a, 7.5, 0.6)
    a.add("Shell", prism(2.6, 0.9, 6, y=0.8, r_top=2.4))
    a.add("Glow", cyl(2.1, 0.06, "y", 24, y=1.72))
    for k in range(3):
        p = hull([(5.2, 0.8, -0.5), (5.2, 0.8, 0.5), (6.0, 0.8, 0), (4.8, 6.8, -0.3), (4.8, 6.8, 0.3), (5.4, 6.8, 0)])
        rot_y(p, k * 2 * np.pi / 3 + np.pi / 6)
        a.add("Shell", p)
    a.add("ShellAlt", ring(5.2, 5.9, 0.5, 6 * 6, y=6.0), rg)
    a.add("Glow", ring(5.0, 5.15, 0.12, 36, y=5.7), rg)
    a.add("TeamColor", ring(5.9, 6.0, 0.3, 36, y=6.0), rg)
    return a


def torre():
    a = Asset("energia_torre", F, "building", "Torre de defesa — terra e ar")
    tur = a.group("Turret", (0, 5.2, 0))
    a.add("ShellAlt", prism(2.6, 0.6, 6, r_top=2.4))
    a.add("Shell", prism(1.9, 3.4, 6, y=0.6, r_top=1.0))
    a.add("TeamColor", prism(1.55, 0.25, 6, y=2.2, r_top=1.5))
    a.add("Core", prism(1.05, 0.4, 6, y=4.0, r_top=1.1))
    a.add("Glow", crystal(0.55, 2.0, 6, y=4.6), tur)
    a.add("Glow", crystal(0.55, 0.7, 6, y=4.65, tilt=(np.pi, 0)), tur)
    for k in range(3):
        c = crystal(0.18, 1.1, 4, y=4.8)
        c.apply_translation([1.3, 0, 0])
        rot_y(c, k * 2 * np.pi / 3)
        a.add("Shell", c, tur)
    return a


def laboratorio():
    a = Asset("energia_laboratorio", F, "building", "Laboratório — nível 2")
    rg = a.group("Ring", (0, 8.0, 0))
    plinth(a, 6.5, 0.6)
    for i, (s, h) in enumerate(((7.0, 2.4), (5.4, 2.0), (3.8, 1.8))):
        y = 0.8 + sum(hh for _, hh in ((7.0, 2.4), (5.4, 2.0), (3.8, 1.8))[:i])
        a.add("Shell" if i != 1 else "ShellAlt", rot_y(cbox(s, h, s, 0.25, y=y), (i % 2) * np.pi / 4))
    a.add("Core", box(3.0, 1.0, 0.1, y=1.5, z=-3.52))
    a.add("Glow", box(2.6, 0.2, 0.12, y=1.9, z=-3.55))
    a.add("CoreGlow", sphere(0.9, 2, y=8.0))
    a.add("ShellAlt", ring(1.3, 1.45, 0.12, 32, y=8.0), rg)
    a.add("ShellAlt", rot_x(ring(1.55, 1.68, 0.1, 32, y=8.0), 1.1, (0, 8.0, 0)), rg)
    a.add("TeamColor", rot_y(box(7.1, 0.25, 7.1, y=2.9), 0.0))
    return a


UNITS = [drone_extrator, sentinela, obelisco, lamina, prisma_defesa]
BUILDINGS = [base_central, fabrica, hangar, torre, laboratorio]
