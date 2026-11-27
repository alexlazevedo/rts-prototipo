"""Facção Militar — unidades e prédios.
Linguagem de formas: blindagem chanfrada, verde-oliva, esteiras e rodas,
motores com brilho âmbar. Unidades sem pernas (sem animação de corpo)."""
import numpy as np
from kit import (Asset, box, both_sides, cbox, cyl, hull, loft, mirror_x, ring, rot_x, rot_y,
                 section, sphere, crystal, T)
import trimesh

F = "militar"


# ======================================================== helpers da facção
def track_unit(a: Asset, length, width, x, y=0.0, wheels=5, h=0.9):
    """Esteira lateral: banda de borracha + rodas visíveis + saia de blindagem."""
    a.add("Track", cbox(width, h, length, 0.45, x=x, y=y))
    for i in range(wheels):
        z = -length / 2 + 0.55 + i * (length - 1.1) / (wheels - 1)
        a.add("Metal", cyl(h * 0.32, width + 0.06, "x", 12, x=x, y=y + h * 0.45, z=z))
    a.add("HullDark", cbox(width + 0.12, 0.28, length * 0.92, 0.3, x=x, y=y + h * 0.78))


def wheel(a: Asset, r, w, x, y, z, group="Body"):
    a.add("Track", cyl(r, w, "x", 16, x=x, y=y, z=z), group)
    a.add("Metal", cyl(r * 0.5, w + 0.04, "x", 10, x=x, y=y, z=z), group)


def team_plate(a, sx, sz, x, y, z, group="Body"):
    a.add("TeamColor", box(sx, 0.06, sz, x=x, y=y, z=z), group)


# ================================================================ unidades
def coletor():
    a = Asset("militar_coletor", F, "unit", "Caminhão minerador — coletor")
    for s in (1, -1):
        track_unit(a, 5.2, 0.7, s * 1.05, 0.0, wheels=4)
    a.add("Hull", cbox(2.0, 0.6, 5.0, 0.25, y=0.55))
    # cabine à frente
    a.add("Hull", hull(section(-2.5, 0.9, 0.55, 1.65, 0.3) + section(-1.1, 0.95, 0.65, 1.75, 0.3)))
    a.add("Glass", hull(section(-2.56, 0.7, 0.25, 1.85, 0.4) + section(-2.2, 0.72, 0.28, 1.9, 0.4)))
    # caçamba de minério
    for s in (1, -1):
        a.add("HullDark", box(0.14, 1.0, 3.0, x=s * 1.0, y=1.15, z=0.8))
    a.add("HullDark", box(2.14, 1.0, 0.14, y=1.15, z=2.3))
    a.add("HullDark", box(2.14, 1.0, 0.14, y=1.15, z=-0.7))
    rng = np.random.default_rng(4)
    for i in range(7):
        x, z = rng.uniform(-0.6, 0.6), rng.uniform(-0.3, 1.9)
        a.add("Ore", crystal(0.22, rng.uniform(0.6, 1.0), 5, x=x, y=1.4, z=z, tilt=(rng.uniform(-.4, .4), rng.uniform(-.4, .4))))
    # braço de perfuração frontal
    a.add("Metal", box(0.25, 0.25, 1.4, x=0.6, y=0.75, z=-3.0))
    a.add("Gun", cyl(0.32, 0.8, "z", 10, x=0.6, y=0.75, z=-3.9, r2=0.05))
    team_plate(a, 1.4, 0.5, 0, 2.42, -1.6)
    a.add("Glow", box(0.3, 0.12, 0.08, x=-0.55, y=1.2, z=-2.52))
    a.add("Glow", box(0.3, 0.12, 0.08, x=0.55, y=1.2, z=-2.52))
    return a


def buggy():
    a = Asset("militar_buggy", F, "unit", "Buggy de assalto — terrestre leve")
    tur = a.group("Turret", (0, 1.45, 0.6))
    a.add("Hull", loft([(-2.3, 0.55, 0.22, 0.8, 0.5), (-1.0, 0.85, 0.35, 0.95, 0.4),
                        (1.3, 0.85, 0.38, 1.0, 0.4), (2.1, 0.7, 0.3, 1.0, 0.4)]))
    a.add("Glass", hull(section(-1.0, 0.6, 0.05, 1.3, 0.5) + section(-0.2, 0.65, 0.3, 1.55, 0.4)))
    for x in (-0.75, 0.75):  # santo antônio
        a.add("Metal", cyl(0.05, 0.9, "y", 6, x=x, y=1.75, z=0.1))
    a.add("Metal", cyl(0.05, 1.55, "x", 6, y=2.2, z=0.1))
    for s in (1, -1):
        for z in (-1.4, 1.35):
            wheel(a, 0.55, 0.45, s * 1.15, 0.55, z)
        a.add("HullDark", cbox(0.5, 0.18, 1.2, 0.4, x=s * 1.15, y=1.08, z=-1.4))  # para-lamas
        a.add("HullDark", cbox(0.5, 0.18, 1.2, 0.4, x=s * 1.15, y=1.08, z=1.35))
    team_plate(a, 0.9, 0.7, 0, 1.39, 1.2)
    # torre de metralhadora dupla
    a.add("HullDark", cyl(0.42, 0.3, "y", 12, y=1.55, z=0.6), tur)
    a.add("Hull", cbox(0.6, 0.35, 0.7, 0.3, y=1.68, z=0.55), tur)
    for x in (-0.12, 0.12):
        a.add("Gun", cyl(0.05, 1.0, "z", 8, x=x, y=1.85, z=-0.2), tur)
    a.add("Glow", box(0.5, 0.1, 0.06, y=1.0, z=2.12))
    return a


def tanque_cerco():
    a = Asset("militar_tanque_cerco", F, "unit", "Tanque de cerco — terrestre pesada")
    tur = a.group("Turret", (0, 1.75, 0.4))
    for s in (1, -1):
        track_unit(a, 6.6, 0.9, s * 1.55, 0.0, wheels=6, h=1.05)
    a.add("Hull", loft([(-3.3, 1.2, 0.35, 1.15, 0.35), (-2.4, 1.35, 0.55, 1.3, 0.3),
                        (2.8, 1.35, 0.55, 1.3, 0.3), (3.3, 1.2, 0.45, 1.25, 0.35)]))
    a.add("HullDark", cbox(1.9, 0.25, 1.6, 0.3, y=1.8, z=2.3))  # deck do motor
    for s in (1, -1):
        a.add("Metal", cyl(0.18, 0.5, "y", 10, x=s * 0.6, y=2.2, z=2.6))
        # patas estabilizadoras traseiras
        a.add("HullDark", hull([(s * 0.9, 0.9, 3.3), (s * 1.2, 0.9, 3.3), (s * 0.9, 0.2, 4.1), (s * 1.2, 0.2, 4.1),
                               (s * 0.9, 1.1, 3.2), (s * 1.2, 1.1, 3.2)]))
    # torre + canhão de artilharia longo
    a.add("Hull", loft([(-1.5, 1.05, 0.45, 2.3, 0.4), (-0.6, 1.25, 0.55, 2.35, 0.3), (1.6, 1.2, 0.55, 2.35, 0.3)]), tur)
    a.add("HullDark", cbox(0.75, 0.6, 1.1, 0.3, y=2.25, z=-1.4), tur)  # mantelete
    a.add("Gun", cyl(0.2, 4.4, "z", 12, y=2.5, z=-3.7, r2=0.16), tur)
    a.add("Gun", cyl(0.28, 0.6, "z", 12, y=2.5, z=-5.9), tur)  # freio de boca
    a.add("Metal", cyl(0.06, 0.8, "y", 6, x=0.7, y=3.25, z=1.0), tur)  # antena
    team_plate(a, 1.2, 1.0, 0, 2.92, 0.6, tur)
    a.add("Glow", box(0.8, 0.1, 0.06, y=1.6, z=3.32))
    return a


def vtol():
    a = Asset("militar_vtol", F, "unit", "VTOL de ataque — aérea")
    Y = 6.0  # altitude de voo embutida no modelo (o jogo pode mover o grupo Body)
    rotL = a.group("Rotor_L", (-3.25, Y + 1.25, 0))
    rotR = a.group("Rotor_R", (3.25, Y + 1.25, 0))
    up = lambda m: m.apply_translation([0, Y, 0]) or m  # noqa: E731

    for m in loft([(-4.05, 0.18, 0.14, 0.95, 0.4), (-3.2, 0.62, 0.48, 1.02, 0.4), (-1.6, 0.92, 0.72, 1.15, 0.35),
                   (0.6, 0.92, 0.72, 1.2, 0.35), (1.7, 0.55, 0.48, 1.32, 0.4)]):
        a.add("Hull", up(m))
    for m in loft([(-3.0, 0.55, 0.12, 0.52, 0.5), (0.9, 0.78, 0.14, 0.5, 0.5)]):
        a.add("HullDark", up(m))
    for m in loft([(1.5, 0.34, 0.3, 1.38, 0.4), (4.3, 0.22, 0.2, 1.52, 0.4)]):
        a.add("Hull", up(m))
    a.add("Glass", up(hull(section(-3.25, 0.32, 0.05, 1.45, 0.5) + section(-2.4, 0.55, 0.32, 1.72, 0.45)
                           + section(-1.45, 0.5, 0.3, 1.78, 0.45))))
    a.add("HullDark", up(hull(section(-1.3, 0.42, 0.22, 1.95, 0.45) + section(0.9, 0.32, 0.16, 1.9, 0.45))))
    wing = hull([(0.7, 1.05, -0.75), (0.7, 1.33, -0.75), (0.7, 1.05, 0.75), (0.7, 1.33, 0.75),
                 (2.4, 1.12, -0.5), (2.4, 1.28, -0.5), (2.4, 1.12, 0.45), (2.4, 1.28, 0.45)])
    stripe = box(0.4, 0.08, 1.15, x=1.55, y=1.27, z=0)
    for s in (1, -1):
        a.add("Hull", up(wing.copy() if s > 0 else mirror_x(wing)))
        a.add("TeamColor", up(stripe.copy() if s > 0 else mirror_x(stripe)))
        a.add("Hull", up(ring(1.0, 1.2, 0.5, 32, x=s * 3.25, y=1.2)))
        a.add("TeamColor", up(ring(1.18, 1.26, 0.12, 32, x=s * 3.25, y=1.42)))
        a.add("Glow", up(cyl(0.97, 0.04, "y", 32, x=s * 3.25, y=1.0)))
        a.add("HullDark", up(cyl(0.17, 1.5, "z", 14, x=s * 1.65, y=0.82, z=-0.05)))
        a.add("Metal", up(cyl(0.17, 0.35, "z", 14, x=s * 1.65, y=0.82, z=-0.97, r2=0.02)))
        a.add("Metal", up(box(0.08, 0.3, 0.7, x=s * 1.65, y=0.87, z=-0.05)))
        a.add("Metal", up(cyl(0.2, 0.9, "z", 16, x=s * 0.72, y=1.55, z=1.1)))
        a.add("Glow", up(cyl(0.15, 0.04, "z", 16, x=s * 0.72, y=1.55, z=1.56)))
        # rotor (grupo próprio para girar)
        g = rotR if s > 0 else rotL
        a.add("Metal", up(cyl(0.22, 0.42, "y", 16, x=s * 3.25, y=1.05)), g)
        for k in range(6):
            b = box(1.85, 0.05, 0.22, y=-0.025)
            rot_x(b, 0.35)
            rot_y(b, k * np.pi / 3)
            b.apply_translation([s * 3.25, 1.25, 0])
            a.add("Metal", up(b), g)
    a.add("Hull", up(hull([(-1.0, 1.48, 3.65), (1.0, 1.48, 3.65), (-1.0, 1.58, 3.65), (1.0, 1.58, 3.65),
                           (-0.8, 1.48, 4.35), (0.8, 1.48, 4.35), (-0.8, 1.58, 4.35), (0.8, 1.58, 4.35)])))
    fin = hull([(-0.05, 1.55, 3.55), (0.05, 1.55, 3.55), (-0.05, 1.55, 4.4), (0.05, 1.55, 4.4),
                (-0.04, 2.45, 4.05), (0.04, 2.45, 4.05), (-0.04, 2.45, 4.55), (0.04, 2.45, 4.55)])
    for s in (1, -1):
        f = fin.copy()
        f.apply_translation([s * 0.72, 0, 0])
        a.add("TeamColor", up(f))
        a.add("Gun", up(cyl(0.055, 1.1, "z", 10, x=s * 0.1, y=0.5, z=-3.35)))
    a.add("Gun", up(sphere(0.32, 2, y=0.55, z=-2.75)))
    a.add("Metal", up(cyl(0.025, 0.6, "y", 6, y=2.25, z=0.4)))
    return a


def antiaereo():
    a = Asset("militar_antiaereo", F, "unit", "Veículo de mísseis — antiaéreo")
    tur = a.group("Turret", (0, 1.7, 0.6))
    for s in (1, -1):
        for z in (-1.7, 0.0, 1.7):
            wheel(a, 0.6, 0.5, s * 1.3, 0.6, z)
    a.add("Hull", loft([(-2.7, 1.0, 0.3, 0.95, 0.4), (-2.0, 1.15, 0.5, 1.15, 0.3), (2.5, 1.15, 0.5, 1.15, 0.3)]))
    a.add("Hull", hull(section(-2.6, 0.9, 0.45, 1.85, 0.3) + section(-1.3, 0.95, 0.55, 1.95, 0.3)))
    a.add("Glass", hull(section(-2.66, 0.7, 0.2, 2.05, 0.4) + section(-2.4, 0.72, 0.25, 2.1, 0.4)))
    for s in (1, -1):
        a.add("HullDark", cbox(0.55, 0.15, 4.4, 0.4, x=s * 1.3, y=1.25, z=0))
    # torre: base giratória + dois lançadores inclinados + radar
    a.add("HullDark", cyl(0.75, 0.35, "y", 14, y=1.85, z=0.6), tur)
    a.add("Hull", cbox(1.0, 0.45, 1.1, 0.3, y=1.95, z=0.6), tur)
    for s in (1, -1):
        pod = cbox(0.7, 0.75, 1.6, 0.2, x=s * 0.95, y=-0.37, z=0)
        tubes = [cyl(0.11, 0.06, "z", 10, x=s * 0.95 + dx, y=dy, z=-0.82) for dx in (-0.17, 0.17) for dy in (-0.17, 0.17)]
        for m in [pod] + tubes:
            rot_x(m, 0.55)
            m.apply_translation([0, 2.55, 0.6])
        a.add("Hull", pod, tur)
        a.add("Glow", tubes, tur)
        a.add("TeamColor", rot_x(box(0.08, 0.5, 1.2, x=s * 1.31, y=2.3, z=0.6), 0.55, (0, 2.55, 0.6)), tur)
    a.add("Metal", cyl(0.05, 0.6, "y", 6, y=2.6, z=1.0), tur)
    dish = cyl(0.45, 0.08, "z", 14, y=3.0, z=1.0)
    rot_x(dish, -0.35, (0, 3.0, 1.0))
    a.add("Metal", dish, tur)
    return a


# ================================================================ prédios
def base_central():
    a = Asset("militar_base", F, "building", "Base central — sede, recebe minério")
    a.add("Concrete", cbox(18, 1.0, 16, 0.08))  # laje
    a.add("Hull", loft([(-6.5, 7.0, 2.6, 3.6, 0.25), (6.5, 7.0, 2.6, 3.6, 0.25)]))
    a.add("HullDark", cbox(9, 2.0, 9, 0.2, y=6.2))
    a.add("Concrete", cyl(3.2, 0.3, "y", 24, y=8.35))  # heliponto
    a.add("TeamColor", ring(2.5, 2.9, 0.06, 24, y=8.53))
    a.add("TeamColor", box(0.5, 0.06, 2.6, x=-0.7, y=8.5))
    a.add("TeamColor", box(0.5, 0.06, 2.6, x=0.7, y=8.5))
    a.add("TeamColor", box(1.0, 0.06, 0.5, y=8.5))
    # baia de descarga de minério + portões
    a.add("Track", box(4.0, 3.2, 0.3, x=-3.5, y=1.0, z=-6.55))
    a.add("Track", box(4.0, 3.2, 0.3, x=3.5, y=1.0, z=-6.55))
    a.add("Glow", box(4.0, 0.15, 0.32, x=-3.5, y=4.3, z=-6.55))
    a.add("Glow", box(4.0, 0.15, 0.32, x=3.5, y=4.3, z=-6.55))
    a.add("Metal", cyl(0.15, 6.0, "y", 8, x=5.5, y=9.0, z=4.0))  # mastro
    a.add("Metal", rot_x(cyl(1.1, 0.15, "z", 16, x=5.5, y=11.5, z=4.0), -0.5, (5.5, 11.5, 4.0)))
    for x in (-7.5, 7.5):
        a.add("HullDark", cbox(2.5, 5.0, 4.0, 0.2, x=x, y=1.0, z=3.0))
        a.add("Metal", cyl(0.45, 2.0, "y", 12, x=x, y=7.0, z=3.0))
    a.add("TeamColor", box(0.12, 1.6, 6.0, x=7.02, y=4.6))
    a.add("TeamColor", box(0.12, 1.6, 6.0, x=-7.02, y=4.6))
    return a


def fabrica():
    a = Asset("militar_fabrica", F, "building", "Fábrica — unidades terrestres")
    a.add("Concrete", cbox(14, 0.6, 14, 0.08))
    a.add("Hull", loft([(-5.5, 5.5, 2.8, 3.4, 0.3), (5.5, 5.5, 2.8, 3.4, 0.3)]))
    a.add("HullDark", hull(section(-5.5, 5.0, 0.6, 6.5, 0.6) + section(5.5, 5.0, 0.6, 6.5, 0.6)))
    a.add("Track", box(5.5, 4.0, 0.3, y=0.6, z=-5.6))  # portão
    for i in range(4):
        a.add("Metal", box(5.5, 0.12, 0.34, y=1.2 + i * 0.9, z=-5.6))
    a.add("Glow", box(5.8, 0.18, 0.34, y=4.75, z=-5.6))
    a.add("TeamColor", box(5.8, 0.6, 0.12, y=5.3, z=-5.72))
    for x in (3.2, 4.4):
        a.add("Metal", cyl(0.45, 4.0, "y", 12, x=x, y=8.5, z=3.5))
        a.add("HullDark", cyl(0.55, 0.4, "y", 12, x=x, y=10.4, z=3.5))
    # guindaste
    a.add("Metal", box(0.4, 5.5, 0.4, x=-5.8, y=0.6, z=-3.5))
    a.add("Metal", box(0.4, 0.4, 6.0, x=-5.8, y=6.0, z=-5.5))
    a.add("Metal", cyl(0.04, 2.0, "y", 4, x=-5.8, y=5.0, z=-8.2))
    return a


def hangar():
    a = Asset("militar_hangar", F, "building", "Hangar — unidades aéreas")
    a.add("Concrete", cbox(16, 0.8, 14, 0.06))
    a.add("Concrete", cyl(4.0, 0.25, "y", 28, x=-2.5, y=0.9, z=0))
    a.add("TeamColor", ring(3.2, 3.6, 0.06, 28, x=-2.5, y=1.18))
    for i in range(10):  # luzes de borda do pad
        ang = i * 2 * np.pi / 10
        a.add("Glow", cyl(0.18, 0.15, "y", 8, x=-2.5 + 4.2 * np.cos(ang), y=0.85, z=4.2 * np.sin(ang)))
    # torre de controle
    a.add("Hull", cbox(3.0, 6.0, 3.0, 0.2, x=5.0, y=0.8, z=3.5))
    a.add("Glass", hull(section(2.0, 1.9, 0.6, 7.6, 0.3, 5.0) + section(5.0, 1.9, 0.6, 7.6, 0.3, 5.0)))
    a.add("HullDark", cbox(4.0, 0.4, 3.6, 0.3, x=5.0, y=8.2, z=3.5))
    a.add("Metal", cyl(0.08, 2.5, "y", 6, x=5.8, y=9.8, z=3.0))
    # cobertura lateral
    a.add("Hull", hull([(3.0, 4.5, -6.5), (7.5, 4.5, -6.5), (3.0, 5.0, -1.0), (7.5, 5.0, -1.0),
                       (3.0, 4.2, -6.5), (7.5, 4.2, -6.5), (3.0, 4.7, -1.0), (7.5, 4.7, -1.0)]))
    for x in (3.3, 7.2):
        for z in (-6.2, -1.3):
            a.add("Metal", cyl(0.15, 3.6, "y", 8, x=x, y=2.6, z=z))
    a.add("TeamColor", box(4.6, 0.08, 1.0, x=5.25, y=5.0, z=-3.8))
    return a


def torre():
    a = Asset("militar_torre", F, "building", "Torre de defesa — terra e ar")
    tur = a.group("Turret", (0, 4.2, 0))
    a.add("Concrete", prism_oct(3.2, 2.6))
    a.add("Hull", cbox(3.6, 1.6, 3.6, 0.3, y=2.6))
    a.add("TeamColor", box(3.7, 0.3, 3.7, y=3.4))
    a.add("HullDark", cyl(1.4, 0.4, "y", 16, y=4.3), tur)
    a.add("Hull", loft([(-1.4, 1.2, 0.6, 5.0, 0.35), (1.2, 1.1, 0.55, 5.0, 0.35)]), tur)
    for x in (-0.4, 0.4):
        a.add("Gun", cyl(0.14, 2.6, "z", 10, x=x, y=5.0, z=-2.6), tur)
    a.add("Glow", box(1.0, 0.12, 0.06, y=5.35, z=-1.42), tur)
    a.add("Metal", cyl(0.05, 0.8, "y", 6, x=0.7, y=6.0, z=0.9), tur)
    a.add("Metal", rot_x(cyl(0.45, 0.08, "z", 12, x=0.7, y=6.45, z=0.9), -0.4, (0.7, 6.45, 0.9)), tur)
    return a


def prism_oct(r, h):
    from kit import prism
    return prism(r, h, 8, 0.0, r_top=r * 0.82, rot=np.pi / 8)


def laboratorio():
    a = Asset("militar_laboratorio", F, "building", "Laboratório — nível 2")
    a.add("Concrete", cbox(13, 0.6, 12, 0.08))
    a.add("Hull", cbox(8.0, 3.6, 7.0, 0.2, x=-1.5, y=0.6))
    dome = sphere(3.0, 2, x=-1.5, y=4.2)
    dome = trimesh.intersections.slice_mesh_plane(dome, [0, 1, 0], [0, 4.2, 0], cap=True)
    a.add("HullDark", dome)
    a.add("Glass", ring(2.6, 3.05, 0.4, 24, x=-1.5, y=5.2))
    # tanque de Núcleo (cápsula com brilho magenta)
    a.add("Metal", cyl(1.1, 0.4, "y", 16, x=4.2, y=0.8, z=2.5))
    a.add("CoreGlow", cyl(0.55, 3.0, "y", 12, x=4.2, y=2.6, z=2.5))
    for k in range(4):
        ang = k * np.pi / 2 + np.pi / 4
        a.add("Metal", cyl(0.08, 3.2, "y", 6, x=4.2 + 0.95 * np.cos(ang), y=2.6, z=2.5 + 0.95 * np.sin(ang)))
    a.add("Metal", cyl(1.1, 0.4, "y", 16, x=4.2, y=4.4, z=2.5))
    a.add("Metal", ring(0.92, 1.0, 0.25, 16, x=4.2, y=2.6, z=2.5))
    a.add("TeamColor", box(8.1, 0.5, 0.1, x=-1.5, y=3.4, z=-3.55))
    a.add("Metal", cyl(0.1, 3.0, "y", 6, x=-4.5, y=5.5, z=-2.5))
    a.add("Metal", rot_x(cyl(0.9, 0.1, "z", 14, x=-4.5, y=7.0, z=-2.5), -0.6, (-4.5, 7.0, -2.5)))
    return a


UNITS = [coletor, buggy, tanque_cerco, vtol, antiaereo]
BUILDINGS = [base_central, fabrica, hangar, torre, laboratorio]
