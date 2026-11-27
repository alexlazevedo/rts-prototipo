"""Kit de estilo em código — base comum de todos os assets do RTS.

Convenções (valem para todo asset):
  * metros, Y para cima, frente apontando para -Z (padrão do Godot)
  * materiais com nomes fixos; o jogo troca em tempo de execução:
      TeamColor -> cor do time      Glow -> emissivo da facção
  * partes que se movem ficam em grupos com pivô próprio
    (ex.: Turret, Rotor_L), o resto fica em Body
  * dentro de cada grupo, peças do mesmo material viram UMA malha
    (poucas chamadas de desenho = bom para celular)
"""
from __future__ import annotations

import numpy as np
import trimesh
from PIL import Image
from trimesh.visual import TextureVisuals
from trimesh.visual.material import PBRMaterial

T = trimesh.transformations


# ------------------------------------------------------------------ cores
def srgb(hexstr: str, a: int = 255):
    h = hexstr.lstrip("#")
    return [int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a]


TEAM_COLORS = {"blue": "2f7de1", "red": "d8402f", "yellow": "e8b52a", "green": "3fbf6a"}
ORE = "d9761c"      # minério: âmbar
CORE = "ff4fa3"     # Núcleo: magenta


# ------------------------------------------------------- texturas de detalhe
def _blur_noise(n: int, sigma: float, rng) -> np.ndarray:
    """Ruído suave e repetível nas bordas (tileable), normalizado para -1..1."""
    w = rng.standard_normal((n, n))
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    k = np.exp(-2 * (np.pi ** 2) * (sigma ** 2) * (fx ** 2 + fy ** 2))
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * k))
    out -= out.mean()
    return out / (np.abs(out).max() + 1e-9)


def detail_texture(style: str, n: int = 256, seed: int = 3) -> Image.Image:
    """Textura cinza multiplicada pela cor do material: painéis, rebites, sujeira."""
    rng = np.random.default_rng(seed)
    if style == "military":
        v = 0.88 + 0.07 * _blur_noise(n, 18, rng) + 0.03 * _blur_noise(n, 3, rng)
        row_h, seam, rivet = n // 4, 0.6, True
    elif style == "concrete":
        v = 0.86 + 0.08 * _blur_noise(n, 10, rng) + 0.05 * _blur_noise(n, 1.5, rng)
        row_h, seam, rivet = n // 2, 0.7, False
    elif style == "rock":  # rocha: só variação, sem juntas
        v = 0.85 + 0.09 * _blur_noise(n, 12, rng) + 0.06 * _blur_noise(n, 2, rng)
        img = (np.clip(v, 0.4, 1.0) * 255).astype(np.uint8)
        return Image.fromarray(img, "L").convert("RGB")
    else:  # ceramic (Energia): limpo, juntas finas
        v = 0.96 + 0.02 * _blur_noise(n, 24, rng)
        row_h, seam, rivet = n // 2, 0.78, False

    # painéis: faixas horizontais + juntas verticais em posições aleatórias por faixa
    for r0 in range(0, n, row_h):
        v[r0, :] *= seam
        v[(r0 + 1) % n, :] *= (1 + seam) / 2
        for x in rng.choice(n, size=2 if style != "ceramic" else 1, replace=False):
            v[r0:r0 + row_h, x] *= seam
            v[r0:r0 + row_h, (x + 1) % n] *= (1 + seam) / 2
            if rivet:
                for y in range(r0 + 6, r0 + row_h - 4, 10):
                    v[y, (x + 4) % n] *= 0.72
                    v[y, (x - 3) % n] *= 0.72
    if style == "military":  # arranhões claros curtos
        for _ in range(40):
            x0, y0 = rng.integers(0, n, 2)
            ang = rng.uniform(0, np.pi)
            for t in range(int(rng.integers(4, 14))):
                xx = int(x0 + t * np.cos(ang)) % n
                yy = int(y0 + t * np.sin(ang)) % n
                v[yy, xx] = max(v[yy, xx], 0.99)
    img = (np.clip(v, 0.4, 1.0) * 255).astype(np.uint8)
    return Image.fromarray(img, "L").convert("RGB")


TEX = {s: detail_texture(s) for s in ("military", "concrete", "ceramic", "rock")}


# ------------------------------------------------------------- materiais
def linear(hexstr: str):
    """glTF guarda baseColorFactor em espaço LINEAR; a paleta é escrita em sRGB (hex)."""
    c = np.array(srgb(hexstr)[:3]) / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return [float(x) for x in lin] + [1.0]


def _m(name, color, metal=0.2, rough=0.6, emissive=None, tex=None):
    kw = dict(name=name, baseColorFactor=linear(color), metallicFactor=metal, roughnessFactor=rough)
    if emissive:
        kw["emissiveFactor"] = emissive
    if tex:
        kw["baseColorTexture"] = TEX[tex]
    return PBRMaterial(**kw)


PALETTES = {
    "militar": {
        "Hull":      _m("Hull", "4b5233", 0.25, 0.65, tex="military"),
        "HullDark":  _m("HullDark", "33382a", 0.25, 0.7, tex="military"),
        "Concrete":  _m("Concrete", "8a8676", 0.0, 0.9, tex="concrete"),
        "Metal":     _m("Metal", "3a3d40", 0.8, 0.4),
        "Gun":       _m("Gun", "222426", 0.9, 0.35),
        "Track":     _m("Track", "1e1f1c", 0.3, 0.85),
        "Glass":     _m("Glass", "1b2a33", 0.6, 0.12),
        "TeamColor": _m("TeamColor", TEAM_COLORS["blue"], 0.1, 0.5),
        "Glow":      _m("Glow", "ffb347", 0.0, 1.0, emissive=[1.0, 0.62, 0.22]),
        "Ore":       _m("Ore", ORE, 0.1, 0.35, emissive=[0.28, 0.1, 0.0]),
        "CoreGlow":  _m("CoreGlow", CORE, 0.0, 0.6, emissive=[0.75, 0.05, 0.4]),
    },
    "energia": {
        "Shell":     _m("Shell", "e9ece8", 0.15, 0.35, tex="ceramic"),
        "ShellAlt":  _m("ShellAlt", "b9c4c1", 0.3, 0.4, tex="ceramic"),
        "Core":      _m("Core", "1f2b2a", 0.7, 0.3),
        "TeamColor": _m("TeamColor", TEAM_COLORS["blue"], 0.1, 0.45),
        "Glow":      _m("Glow", "1fcfb0", 0.0, 1.0, emissive=[0.05, 0.75, 0.6]),
        "Ore":       _m("Ore", ORE, 0.1, 0.35, emissive=[0.28, 0.1, 0.0]),
        "CoreGlow":  _m("CoreGlow", CORE, 0.0, 0.6, emissive=[0.75, 0.05, 0.4]),
    },
    "neutro": {
        "Rock":      _m("Rock", "a8845a", 0.0, 0.95, tex="rock"),
        "Ore":       _m("Ore", ORE, 0.1, 0.3, emissive=[0.32, 0.12, 0.0]),
        "CoreGlow":  _m("CoreGlow", CORE, 0.0, 0.6, emissive=[0.75, 0.05, 0.4]),
        "Metal":     _m("Metal", "3a3d40", 0.8, 0.4),
    },
}


# ------------------------------------------------------------- geometria
def hull(points):
    return trimesh.convex.convex_hull(np.asarray(points, dtype=float))


def section(z, hw, hh, yc, ch=0.35, xc=0.0):
    """Seção octogonal (retângulo chanfrado) no plano XY, na posição z."""
    cx, cy = hw * ch, hh * ch
    return [
        (xc - hw + cx, yc + hh, z), (xc + hw - cx, yc + hh, z),
        (xc + hw, yc + hh - cy, z), (xc + hw, yc - hh + cy, z),
        (xc + hw - cx, yc - hh, z), (xc - hw + cx, yc - hh, z),
        (xc - hw, yc - hh + cy, z), (xc - hw, yc + hh - cy, z),
    ]


def loft(stations):
    """Lista de cascos convexos entre seções consecutivas."""
    return [hull(section(*a) + section(*b)) for a, b in zip(stations[:-1], stations[1:])]


def cbox(sx, sy, sz, ch=0.2, x=0.0, y=0.0, z=0.0):
    """Caixa chanfrada (base apoiada em y)."""
    hw, hh, hd = sx / 2, sy / 2, sz / 2
    return hull(section(z - hd, hw, hh, y + hh, ch, x) + section(z + hd, hw, hh, y + hh, ch, x))


def box(sx, sy, sz, x=0.0, y=0.0, z=0.0):
    m = trimesh.creation.box(extents=[sx, sy, sz])
    m.apply_translation([x, y + sy / 2, z])
    return m


def cyl(r, length, axis="y", sections=20, x=0.0, y=0.0, z=0.0, r2=None):
    if r2 is None:
        m = trimesh.creation.cylinder(radius=r, height=length, sections=sections)
    else:  # tronco de cone
        ang = np.linspace(0, 2 * np.pi, sections, endpoint=False)
        bot = [(r * np.cos(a), r * np.sin(a), -length / 2) for a in ang]
        top = [(r2 * np.cos(a), r2 * np.sin(a), length / 2) for a in ang]
        m = hull(bot + top)
    if axis == "x":
        m.apply_transform(T.rotation_matrix(np.pi / 2, [0, 1, 0]))
    elif axis == "y":
        m.apply_transform(T.rotation_matrix(-np.pi / 2, [1, 0, 0]))
    m.apply_translation([x, y, z])
    return m


def ring(r_in, r_out, h, sections=32, x=0.0, y=0.0, z=0.0):
    m = trimesh.creation.annulus(r_min=r_in, r_max=r_out, height=h, sections=sections)
    m.apply_transform(T.rotation_matrix(np.pi / 2, [1, 0, 0]))
    m.apply_translation([x, y, z])
    return m


def prism(r, h, n=6, y=0.0, r_top=None, x=0.0, z=0.0, rot=0.0):
    """Prisma de n lados em pé (monólitos, pedestais)."""
    r_top = r if r_top is None else r_top
    ang = np.linspace(0, 2 * np.pi, n, endpoint=False) + rot
    pts = [(x + r * np.cos(a), y, z + r * np.sin(a)) for a in ang]
    pts += [(x + r_top * np.cos(a), y + h, z + r_top * np.sin(a)) for a in ang]
    return hull(pts)


def crystal(r, h, n=6, x=0.0, y=0.0, z=0.0, tilt=(0.0, 0.0), point=0.35):
    """Cristal: prisma com ponta, opcionalmente inclinado."""
    ang = np.linspace(0, 2 * np.pi, n, endpoint=False)
    pts = [(r * np.cos(a), 0, r * np.sin(a)) for a in ang]
    pts += [(r * 0.85 * np.cos(a), h * (1 - point), r * 0.85 * np.sin(a)) for a in ang]
    pts += [(0, h, 0)]
    m = hull(pts)
    m.apply_transform(T.rotation_matrix(tilt[0], [1, 0, 0]))
    m.apply_transform(T.rotation_matrix(tilt[1], [0, 0, 1]))
    m.apply_translation([x, y, z])
    return m


def sphere(r, sub=2, x=0.0, y=0.0, z=0.0):
    m = trimesh.creation.icosphere(subdivisions=sub, radius=r)
    m.apply_translation([x, y, z])
    return m


def octa(rx, ry, rz, x=0.0, y=0.0, z=0.0):
    return hull([(x + rx, y, z), (x - rx, y, z), (x, y + ry, z), (x, y - ry, z), (x, y, z + rz), (x, y, z - rz)])


def rot_y(m, ang, about=(0, 0, 0)):
    m.apply_transform(T.rotation_matrix(ang, [0, 1, 0], point=about))
    return m


def rot_x(m, ang, about=(0, 0, 0)):
    m.apply_transform(T.rotation_matrix(ang, [1, 0, 0], point=about))
    return m


def rot_z(m, ang, about=(0, 0, 0)):
    m.apply_transform(T.rotation_matrix(ang, [0, 0, 1], point=about))
    return m


def mirror_x(m):
    m2 = m.copy()
    m2.apply_transform(np.diag([-1, 1, 1, 1]))
    m2.invert()
    return m2


def both_sides(m):
    """Retorna [m, espelho] — para peças simétricas."""
    return [m, mirror_x(m)]


# --------------------------------------------------------------- asset
class Asset:
    def __init__(self, name: str, faction: str, kind: str, role: str = ""):
        self.name, self.faction, self.kind, self.role = name, faction, kind, role
        self.groups = {"Body": (0.0, 0.0, 0.0)}
        self.parts: list[tuple[str, str, trimesh.Trimesh]] = []

    def group(self, name, pivot=(0.0, 0.0, 0.0)):
        self.groups[name] = tuple(pivot)
        return name

    def add(self, mat, meshes, group="Body"):
        if isinstance(meshes, trimesh.Trimesh):
            meshes = [meshes]
        for m in meshes:
            self.parts.append((group, mat, m))
        return self

    # -- exportação
    def _finalize(self, mesh, mat, tile=2.0):
        ms = trimesh.graph.smooth_shade(mesh, angle=np.radians(35))
        F = ms.faces
        V = ms.vertices[F].reshape(-1, 3)
        N = ms.vertex_normals[F].reshape(-1, 3)
        out = trimesh.Trimesh(V, np.arange(len(V)).reshape(-1, 3), vertex_normals=N, process=False)
        if mat.baseColorTexture is not None:
            fn = ms.face_normals
            ax = np.repeat(np.abs(fn).argmax(1), 3)
            uv = np.zeros((len(V), 2))
            for a, (i, j) in {0: (2, 1), 1: (0, 2), 2: (0, 1)}.items():
                sel = ax == a
                uv[sel] = V[sel][:, [i, j]] / tile
            out.visual = TextureVisuals(uv=uv, material=mat)
        else:
            out.visual = TextureVisuals(material=mat)
        return out

    def export(self, path):
        pal = PALETTES[self.faction]
        scene = trimesh.Scene()
        root = self.name
        scene.graph.update(frame_from=scene.graph.base_frame, frame_to=root, matrix=np.eye(4))
        tris = 0
        for g, pivot in self.groups.items():
            members = [(mat, m) for (gg, mat, m) in self.parts if gg == g]
            if not members:
                continue
            scene.graph.update(frame_from=root, frame_to=g, matrix=T.translation_matrix(pivot))
            for mat in sorted({mm for mm, _ in members}):
                geo = trimesh.util.concatenate([m for mm, m in members if mm == mat])
                geo.apply_translation(-np.asarray(pivot))
                fin = self._finalize(geo, pal[mat])
                tris += len(geo.faces)
                scene.add_geometry(fin, node_name=f"{g}_{mat}", geom_name=f"{self.name}_{g}_{mat}", parent_node_name=g)
        scene.export(path)
        b = scene.bounds
        return {"name": self.name, "faction": self.faction, "kind": self.kind, "role": self.role,
                "tris": int(tris), "size_m": [round(float(x), 2) for x in (b[1] - b[0])],
                "groups": [g for g in self.groups if any(p[0] == g for p in self.parts)]}
