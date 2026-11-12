"""
FAB - biblioteca de modelagem procedural e exportador GLB.

Gera malhas trianguladas com numpy e grava arquivos .glb (glTF 2.0 binario) com
um no por peca. O nome de cada no segue o padrao "Nome@Material@RRGGBB[@transparencia]",
que o jogo usa para aplicar material e cor nas MeshParts.

Convencoes: Y para cima, nariz/frente para -Z (igual ao Roblox), unidades livres
(metros para aeronaves, studs para estruturas do mapa).
"""
import json
import math
import struct

import numpy as np


class Malha:
    def __init__(self, v=None, f=None, suave=True):
        self.v = np.zeros((0, 3)) if v is None else np.asarray(v, dtype=float)
        self.f = np.zeros((0, 3), dtype=np.int64) if f is None else np.asarray(f, dtype=np.int64)
        self.suave = suave

    def copia(self):
        return Malha(self.v.copy(), self.f.copy(), self.suave)

    def __add__(self, outra):
        if len(self.v) == 0:
            return outra.copia()
        return Malha(np.vstack([self.v, outra.v]), np.vstack([self.f, outra.f + len(self.v)]), self.suave and outra.suave)

    # transformacoes -----------------------------------------------------------
    def mover(self, x=0.0, y=0.0, z=0.0):
        m = self.copia()
        m.v = m.v + np.array([x, y, z])
        return m

    def escalar(self, sx, sy=None, sz=None):
        sy = sx if sy is None else sy
        sz = sx if sz is None else sz
        m = self.copia()
        m.v = m.v * np.array([sx, sy, sz])
        if sx * sy * sz < 0:
            m.f = m.f[:, ::-1]
        return m

    def girar(self, eixo, graus):
        a = math.radians(graus)
        c, s = math.cos(a), math.sin(a)
        if eixo == "x":
            r = np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
        elif eixo == "y":
            r = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
        else:
            r = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
        m = self.copia()
        m.v = m.v @ r.T
        return m

    def espelhar_x(self):
        return self.escalar(-1, 1, 1)

    def filtrar_faces(self, manter):
        """manter(centroides Nx3) -> mascara booleana"""
        c = self.v[self.f].mean(axis=1)
        m = self.copia()
        m.f = m.f[manter(c)]
        return m

    def inverter(self):
        m = self.copia()
        m.f = m.f[:, ::-1]
        return m

    def normais(self):
        v, f = self.v, self.f
        if len(f) == 0:
            return np.zeros_like(v)
        n_face = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
        n = np.zeros_like(v)
        for k in range(3):
            np.add.at(n, f[:, k], n_face)
        comp = np.linalg.norm(n, axis=1)
        comp[comp == 0] = 1
        return n / comp[:, None]

    def facetada(self):
        """Duplica vertices para normais duras (bordas vivas)."""
        v = self.v[self.f.reshape(-1)]
        f = np.arange(len(v)).reshape(-1, 3)
        return Malha(v, f, suave=False)


# primitivas -------------------------------------------------------------------
def grade(pontos, fechar_u=True, tampa_inicio=False, tampa_fim=False):
    """pontos: array (nv, nu, 3) - linhas ao longo de v, aneis ao longo de u."""
    p = np.asarray(pontos, dtype=float)
    nv, nu = p.shape[0], p.shape[1]
    v = p.reshape(-1, 3)
    faces = []
    ucols = nu if fechar_u else nu - 1
    for i in range(nv - 1):
        for j in range(ucols):
            a = i * nu + j
            b = i * nu + (j + 1) % nu
            c = (i + 1) * nu + (j + 1) % nu
            d = (i + 1) * nu + j
            faces.append([a, b, c])
            faces.append([a, c, d])
    m = Malha(v, np.array(faces, dtype=np.int64))
    if tampa_inicio:
        m = m + tampa(p[0], inverter=False)
    if tampa_fim:
        m = m + tampa(p[-1], inverter=True)
    return m


def tampa(anel, inverter=False):
    anel = np.asarray(anel, dtype=float)
    centro = anel.mean(axis=0)
    v = np.vstack([anel, centro])
    n = len(anel)
    f = [[n, (j + 1) % n, j] for j in range(n)]
    f = np.array(f, dtype=np.int64)
    if inverter:
        f = f[:, ::-1]
    return Malha(v, f, suave=False)


def revolucao(perfil, segs=32, fechar_pontas=True):
    """perfil: lista de (raio, z). Gira em torno do eixo Z."""
    aneis = []
    for r, z in perfil:
        anel = []
        for j in range(segs):
            a = 2 * math.pi * j / segs
            anel.append([r * math.cos(a), r * math.sin(a), z])
        aneis.append(anel)
    m = grade(aneis, True)
    if fechar_pontas:
        if perfil[0][0] > 1e-6:
            m = m + tampa(aneis[0], inverter=perfil[0][1] > perfil[-1][1])
        if perfil[-1][0] > 1e-6:
            m = m + tampa(aneis[-1], inverter=perfil[0][1] < perfil[-1][1])
    return m


def superelipse(largura, altura, n=2.5, segs=32, base_plana=False, cy=0.0, deformar_baixo=1.0):
    """Secao transversal (x, y) com expoente n (2 = elipse, maior = mais quadrada)."""
    pts = []
    for j in range(segs):
        a = 2 * math.pi * j / segs
        c, s = math.cos(a), math.sin(a)
        x = (largura / 2) * math.copysign(abs(c) ** (2 / n), c)
        y = (altura / 2) * math.copysign(abs(s) ** (2 / n), s)
        if y < 0:
            y *= deformar_baixo
        pts.append([x, y + cy])
    return np.array(pts)


def loft(estacoes, segs=32, tampar=True):
    """estacoes: lista de dicts {z, larg, alt, cy, n, baixo} -> casca fechada."""
    aneis = []
    for e in estacoes:
        sec = superelipse(max(e["larg"], 1e-4), max(e["alt"], 1e-4), e.get("n", 2.4), segs, cy=e.get("cy", 0.0),
                          deformar_baixo=e.get("baixo", 1.0))
        anel = np.column_stack([sec[:, 0] + e.get("cx", 0.0), sec[:, 1], np.full(len(sec), e["z"])])
        aneis.append(anel)
    # aneis ordenados do nariz (-Z) para a cauda (+Z); a orientacao das faces aponta para fora
    m = grade(aneis, True)
    if tampar:
        m = m + tampa(aneis[0], inverter=True) + tampa(aneis[-1], inverter=False)
    return m


def naca(espessura=0.12, n=24, curvatura=0.0, pos_curv=0.4):
    """Perfil NACA 4 digitos fechado (x de 0 a 1 do bordo de ataque ao de fuga)."""
    xs = (1 - np.cos(np.linspace(0, math.pi, n))) / 2
    yt = 5 * espessura * (0.2969 * np.sqrt(xs) - 0.1260 * xs - 0.3516 * xs ** 2 + 0.2843 * xs ** 3 - 0.1036 * xs ** 4)
    if curvatura > 0:
        yc = np.where(xs < pos_curv, curvatura / pos_curv ** 2 * (2 * pos_curv * xs - xs ** 2),
                      curvatura / (1 - pos_curv) ** 2 * ((1 - 2 * pos_curv) + 2 * pos_curv * xs - xs ** 2))
    else:
        yc = np.zeros_like(xs)
    sup = np.column_stack([xs, yc + yt])
    inf = np.column_stack([xs, yc - yt])
    contorno = np.vstack([sup[::-1], inf[1:-1]])
    return contorno


def asa(estacoes, espessura=0.12, n=20, curvatura=0.0, lado=1):
    """Asa ao longo de +X (lado=1) ou -X. estacoes: lista de dicts
    {x (envergadura), z_ba (bordo de ataque), corda, y, torcao(graus), esp(opcional)}."""
    aneis = []
    for e in estacoes:
        perf = naca(e.get("esp", espessura), n, curvatura)
        c = e["corda"]
        tw = math.radians(e.get("torcao", 0.0))
        anel = []
        for px, py in perf:
            zz = px * c
            yy = py * c
            # torcao em torno de 25% da corda
            dz, dy = zz - 0.25 * c, yy
            zr = dz * math.cos(tw) + dy * math.sin(tw) + 0.25 * c
            yr = -dz * math.sin(tw) + dy * math.cos(tw)
            anel.append([e["x"] * lado, e["y"] + yr, e["z_ba"] + zr])
        aneis.append(anel)
    m = grade(aneis, True)
    if lado > 0:
        m = m.inverter()
    ponta = tampa(aneis[-1], inverter=(lado < 0))
    raiz = tampa(aneis[0], inverter=(lado > 0))
    return m + ponta + raiz


def superelipsoide(sx, sy, sz, n=4.0, segs_u=24, segs_v=14, so_cima=False):
    aneis = []
    vmin = 0.0 if so_cima else -math.pi / 2
    for i in range(segs_v + 1):
        phi = vmin + (math.pi / 2 - vmin) * i / segs_v
        anel = []
        for j in range(segs_u):
            th = 2 * math.pi * j / segs_u
            cp, sp = math.cos(phi), math.sin(phi)
            ct, st = math.cos(th), math.sin(th)
            def pw(x, e):
                return math.copysign(abs(x) ** e, x)
            e = 2 / n
            x = sx / 2 * pw(cp, e) * pw(ct, e)
            z = sz / 2 * pw(cp, e) * pw(st, e)
            y = sy / 2 * pw(sp, e)
            anel.append([x, y, z])
        aneis.append(anel)
    m = grade(aneis, True)
    m = m.inverter()
    if so_cima:
        m = m + tampa(aneis[0], inverter=False)
    return m


def caixa(sx, sy, sz, chanfro=0.0):
    if chanfro <= 0:
        x, y, z = sx / 2, sy / 2, sz / 2
        v = np.array([[-x, -y, -z], [x, -y, -z], [x, y, -z], [-x, y, -z], [-x, -y, z], [x, -y, z], [x, y, z], [-x, y, z]])
        f = np.array([[0, 2, 1], [0, 3, 2], [4, 5, 6], [4, 6, 7], [0, 1, 5], [0, 5, 4], [3, 6, 2], [3, 7, 6], [1, 2, 6], [1, 6, 5], [0, 4, 7], [0, 7, 3]])
        return Malha(v, f).facetada()
    return superelipsoide(sx, sy, sz, n=max(4.0, min(sx, sy, sz) / chanfro * 2), segs_u=24, segs_v=10)


def cilindro(raio, comprimento, segs=24, eixo="z"):
    m = revolucao([(raio, -comprimento / 2), (raio, comprimento / 2)], segs)
    if eixo == "x":
        m = m.girar("y", 90)
    elif eixo == "y":
        m = m.girar("x", -90)
    return m


def tubo(caminho, raio, segs=10, fechado=False):
    """Tubo ao longo de uma polilinha (para arcos de canopi, corrimoes, cabos)."""
    p = np.asarray(caminho, dtype=float)
    aneis = []
    for i in range(len(p)):
        if i == 0:
            t = p[1] - p[0]
        elif i == len(p) - 1:
            t = p[-1] - p[-2]
        else:
            t = p[i + 1] - p[i - 1]
        t = t / (np.linalg.norm(t) + 1e-9)
        ref = np.array([0, 1, 0]) if abs(t[1]) < 0.9 else np.array([1, 0, 0])
        a = np.cross(t, ref)
        a /= np.linalg.norm(a)
        b = np.cross(t, a)
        anel = [p[i] + raio * (math.cos(2 * math.pi * j / segs) * a + math.sin(2 * math.pi * j / segs) * b) for j in range(segs)]
        aneis.append(anel)
    m = grade(aneis, True)
    if not fechado:
        m = m + tampa(aneis[0], True) + tampa(aneis[-1], False)
    return m


def extrusao(poligono, profundidade):
    """Poligono (x, y) convexo ou simples, extrudado em Z (centrado)."""
    pol = np.asarray(poligono, dtype=float)
    n = len(pol)
    tras = np.column_stack([pol, np.full(n, profundidade / 2)])
    frente = np.column_stack([pol, np.full(n, -profundidade / 2)])
    lados = grade([frente, tras], True)
    return (lados + tampa(frente, True) + tampa(tras, False)).facetada()


# exportacao -------------------------------------------------------------------
class Cena:
    def __init__(self):
        self.pecas = []  # (nome, malha, cor rgb 0-1, metalico, rugosidade, alfa)

    def adicionar(self, nome, malha, cor, material="SmoothPlastic", transparencia=0.0, metal=0.0, rug=0.6):
        r, g, b = cor
        hexa = "%02X%02X%02X" % (int(r), int(g), int(b))
        nome_no = "%s@%s@%s" % (nome, material, hexa)
        if transparencia > 0:
            nome_no += "@%g" % transparencia
        self.pecas.append((nome_no, malha, (r / 255, g / 255, b / 255), metal, rug, 1 - transparencia))

    def ancoras(self, comprimento=1.0):
        """Tres marcadores: origem, frente (-Z) e cima (+Y), usados para alinhar no jogo."""
        cubo = caixa(0.02 * comprimento, 0.02 * comprimento, 0.02 * comprimento)
        self.adicionar("Ancora_Origem", cubo, (255, 0, 255), "Neon")
        self.adicionar("Ancora_Frente", cubo.mover(0, 0, -comprimento), (255, 0, 255), "Neon")
        self.adicionar("Ancora_Cima", cubo.mover(0, comprimento, 0), (255, 0, 255), "Neon")

    def triangulos(self):
        return sum(len(m.f) for _, m, *_ in self.pecas)

    def salvar_glb(self, caminho):
        binario = bytearray()
        buffer_views, accessors, meshes, nodes, materiais = [], [], [], [], []

        def alinhar():
            while len(binario) % 4:
                binario.append(0)

        for nome, malha, cor, metal, rug, alfa in self.pecas:
            if len(malha.f) == 0:
                continue
            if len(malha.f) > 19000:
                raise ValueError("%s tem %d triangulos (limite 19000)" % (nome, len(malha.f)))
            m = malha if malha.suave else malha
            v = m.v.astype(np.float32)
            n = m.normais().astype(np.float32)
            idx = m.f.astype(np.uint32).reshape(-1)
            for dados, tipo, comp, alvo in ((v, "VEC3", 3, 34962), (n, "VEC3", 3, 34962), (idx, "SCALAR", 1, 34963)):
                alinhar()
                inicio = len(binario)
                binario.extend(dados.tobytes())
                buffer_views.append({"buffer": 0, "byteOffset": inicio, "byteLength": len(binario) - inicio, "target": alvo})
                acc = {"bufferView": len(buffer_views) - 1, "count": int(len(dados) if comp == 1 else len(dados)),
                       "type": tipo, "componentType": 5126 if tipo == "VEC3" else 5125}
                if tipo == "VEC3":
                    acc["count"] = int(dados.shape[0])
                    acc["min"] = [float(x) for x in dados.min(axis=0)]
                    acc["max"] = [float(x) for x in dados.max(axis=0)]
                accessors.append(acc)
            ip = len(accessors) - 3
            materiais.append({"name": nome, "pbrMetallicRoughness": {"baseColorFactor": [cor[0], cor[1], cor[2], alfa],
                                                                     "metallicFactor": metal, "roughnessFactor": rug},
                              "doubleSided": False, **({"alphaMode": "BLEND"} if alfa < 1 else {})})
            meshes.append({"name": nome, "primitives": [{"attributes": {"POSITION": ip, "NORMAL": ip + 1}, "indices": ip + 2,
                                                         "material": len(materiais) - 1}]})
            nodes.append({"name": nome, "mesh": len(meshes) - 1})
        alinhar()
        gltf = {
            "asset": {"version": "2.0", "generator": "FAB malhas"},
            "scene": 0,
            "scenes": [{"nodes": list(range(len(nodes)))}],
            "nodes": nodes, "meshes": meshes, "materials": materiais,
            "accessors": accessors, "bufferViews": buffer_views,
            "buffers": [{"byteLength": len(binario)}],
        }
        js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        while len(js) % 4:
            js += b" "
        total = 12 + 8 + len(js) + 8 + len(binario)
        with open(caminho, "wb") as fh:
            fh.write(struct.pack("<III", 0x46546C67, 2, total))
            fh.write(struct.pack("<II", len(js), 0x4E4F534A))
            fh.write(js)
            fh.write(struct.pack("<II", len(binario), 0x004E4942))
            fh.write(binario)

    def previa(self, caminho, vistas=((20, -60), (20, 30), (85, -90)), titulo=""):
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d.art3d import Poly3DCollection
        fig = plt.figure(figsize=(7 * len(vistas), 6))
        tudo = np.vstack([m.v for n, m, *_ in self.pecas if not n.startswith("Ancora") and len(m.v)])
        lo, hi = tudo.min(axis=0), tudo.max(axis=0)
        centro = (lo + hi) / 2
        raio = (hi - lo).max() / 2 * 0.62
        luz = np.array([0.4, 0.8, -0.3])
        luz /= np.linalg.norm(luz)
        for k, (elev, azim) in enumerate(vistas):
            ax = fig.add_subplot(1, len(vistas), k + 1, projection="3d")
            for nome, malha, cor, metal, rug, alfa in self.pecas:
                if nome.startswith("Ancora") or len(malha.f) == 0:
                    continue
                tri = malha.v[malha.f]
                # troca eixos: (x, z, y) para o matplotlib ter Y para cima
                tri_plot = tri[:, :, [0, 2, 1]] * np.array([1, -1, 1])
                nf = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
                nf /= (np.linalg.norm(nf, axis=1)[:, None] + 1e-9)
                inten = 0.35 + 0.65 * np.clip(nf @ luz, 0, 1)
                cores = np.clip(np.array(cor)[None, :] * inten[:, None], 0, 1)
                pc = Poly3DCollection(tri_plot, facecolors=np.column_stack([cores, np.full(len(cores), max(alfa, 0.25))]), edgecolor="none")
                ax.add_collection3d(pc)
            ax.set_xlim(centro[0] - raio, centro[0] + raio)
            ax.set_ylim(-centro[2] - raio, -centro[2] + raio)
            ax.set_zlim(centro[1] - raio, centro[1] + raio)
            ax.view_init(elev=elev, azim=azim)
            ax.set_axis_off()
        fig.suptitle(titulo)
        fig.tight_layout()
        fig.savefig(caminho, dpi=85)
        plt.close(fig)
