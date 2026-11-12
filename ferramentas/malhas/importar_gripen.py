"""
FAB - converte o "SAAB Jas 39A Gripen (Detailed Cockpit)" de ngkoret (CC-BY-4.0) em
malhas/Aeronave_F39.glb (exterior) para o jogo.
Credito obrigatorio: https://sketchfab.com/3d-models/saab-jas-39a-gripen-detailed-cockpit-f4646ccf489341c28c4118de38feface
- reorienta (nariz -Z, topo +Y), escala para 8,4 m de envergadura;
- junta as pecas da fuselagem, reduz por agrupamento de vertices e divide em pecas de <= 19000 triangulos;
- pinta em cinza FAB por regiao, adiciona canopi, trem de pouso e ancoras.
Fonte esperada em modelos_prontos/gripen_jas39a/ (scene.gltf + scene.bin), ou GRIPEN_FONTE.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from malha import Cena, Malha  # noqa: E402
import aeronaves  # noqa: E402
import gltf_leitor  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONTE = os.environ.get("GRIPEN_FONTE", os.path.join(RAIZ, "modelos_prontos", "gripen_jas39a"))
SAIDA = os.path.join(RAIZ, "malhas", "Aeronave_F39.glb")
ENVERGADURA = 8.4
MAT_EXT = "saab_jas39a_aircraft_normal_detail"
# fuselagem sem asas/bocal: o eixo do modelo e X para a frente, Y para cima, Z lateral
Z_NARIZ = -8.2  # ponta do pitot (compativel com a fisica/cabine antigas)
Y_DESLOC = 0.35


def para_jogo(V, esc, x_max):
    # (x frente, y cima, z lado) -> (X lado, Y cima, Z = -frente)
    return np.stack([V[:, 2] * esc, V[:, 1] * esc + Y_DESLOC, -(V[:, 0] - x_max) * esc + Z_NARIZ], axis=1)


def agrupar(V, I, celula):
    q = np.floor((V - V.min(0)) / celula).astype(np.int64)
    chave = (q[:, 0] * 100000 + q[:, 1]) * 100000 + q[:, 2]
    _, inv, cont = np.unique(chave, return_inverse=True, return_counts=True)
    novo = np.zeros((len(cont), 3))
    np.add.at(novo, inv, V)
    novo /= cont[:, None]
    F = inv[I]
    ok = (F[:, 0] != F[:, 1]) & (F[:, 1] != F[:, 2]) & (F[:, 0] != F[:, 2])
    return novo, F[ok]


MATS_CABINE = ("saab_jas39a_cockpit", "saab_jas39a_lables", "saab_jas39a_lables_1", "seat_saab_jas39", "saab_jas39a_interior",
               "sw_sight_saab_39c", "dynamic_mfd", "dynamic_mirror")


def cor_vertices(p, cache):
    """Cor media de cada vertice amostrada da textura difusa (reduzida)."""
    from PIL import Image
    nome = p["material"]
    if nome.startswith("sw_gauge"):
        nome = nome
    arq = os.path.join(FONTE, "textures", nome + "_diffuse.png")
    if p["uv"] is None or not os.path.exists(arq):
        return np.tile(np.array([[52.0, 54.0, 58.0]]), (len(p["V"]), 1))
    if arq not in cache:
        im = Image.open(arq).convert("RGB")
        im.thumbnail((1024, 1024))
        cache[arq] = np.asarray(im).astype(float)
    t = cache[arq]
    h, w = t.shape[:2]
    u = np.mod(p["uv"][:, 0], 1.0)
    v = np.mod(p["uv"][:, 1], 1.0)
    return t[np.clip((v * h).astype(int), 0, h - 1), np.clip((u * w).astype(int), 0, w - 1)]


def kmeans(X, k, it=12):
    rng = np.random.RandomState(1)
    C = X[rng.choice(len(X), k, replace=False)]
    for _ in range(it):
        d = ((X[:, None, :] - C[None]) ** 2).sum(-1)
        a = d.argmin(1)
        for j in range(k):
            if (a == j).any():
                C[j] = X[a == j].mean(0)
    return C, a


def construir_cabine(pecas, esc, x_max, alvo=110000):
    sel = [p for p in pecas if p["material"] in MATS_CABINE or p["material"].startswith("sw_gauge")]
    sel = [p for p in sel if p["nome"] != "Object_70"]
    cache = {}
    Vs, Fs, Cs, n = [], [], [], 0
    for p in sel:
        Vs.append(para_jogo(p["V"], esc, x_max))
        Fs.append(p["F"] + n)
        Cs.append(cor_vertices(p, cache))
        n += len(p["V"])
    V, I, C = np.vstack(Vs), np.vstack(Fs), np.vstack(Cs)
    print("cabine original:", len(I), "triangulos")
    celula = 0.006
    for _ in range(60):
        q = np.floor((V - V.min(0)) / celula).astype(np.int64)
        chave = (q[:, 0] * 100000 + q[:, 1]) * 100000 + q[:, 2]
        _, inv, cont = np.unique(chave, return_inverse=True, return_counts=True)
        novo = np.zeros((len(cont), 3)); cn = np.zeros((len(cont), 3))
        np.add.at(novo, inv, V); np.add.at(cn, inv, C)
        novo /= cont[:, None]; cn /= cont[:, None]
        F = inv[I]
        ok = (F[:, 0] != F[:, 1]) & (F[:, 1] != F[:, 2]) & (F[:, 0] != F[:, 2])
        F = F[ok]
        if len(F) <= alvo:
            break
        celula *= 1.1
    print("cabine reduzida:", len(F), "celula", round(celula, 4))
    return novo, F, cn


def carregar_fonte():
    _, pecas = gltf_leitor.carregar(FONTE)
    ext = [p for p in pecas if p["material"] == MAT_EXT]
    todos = np.vstack([p["V"] for p in ext])
    esc = ENVERGADURA / (todos[:, 2].max() - todos[:, 2].min())
    return pecas, ext, esc, todos[:, 0].max()


def adicionar_exterior(cena, pecas, ext, esc, x_max, alvo, vidro=True):
    Vs, Fs, n = [], [], 0
    for p in ext:
        Vs.append(para_jogo(p["V"], esc, x_max))
        Fs.append(p["F"] + n)
        n += len(p["V"])
    V = np.vstack(Vs)
    I = np.vstack(Fs)
    print("exterior original:", len(I), "triangulos, escala", round(esc, 4))
    celula = 0.03
    for _ in range(60):
        Vr, Fr = agrupar(V, I, celula)
        if len(Fr) <= alvo:
            break
        celula *= 1.1
    print("exterior reduzido:", len(Fr), "celula", round(celula, 3))
    V, I = Vr, Fr
    n_face = np.cross(V[I[:, 1]] - V[I[:, 0]], V[I[:, 2]] - V[I[:, 0]])
    n_face /= np.maximum(np.linalg.norm(n_face, axis=1), 1e-9)[:, None]
    c = V[I].mean(axis=1)
    cima = n_face[:, 1] > 0.3
    ruido = np.sin(c[:, 2] * 0.45 + np.sin(c[:, 0] * 0.35) * 1.2) + np.sin(c[:, 0] * 0.5 - c[:, 2] * 0.2)
    tom = np.digitize(ruido, [-0.4, 0.8])
    classe = np.where(cima, tom, 3)
    cores = {0: (110, 116, 122), 1: (100, 106, 112), 2: (120, 126, 132), 3: (150, 156, 162), 4: (60, 64, 68), 5: (36, 38, 42)}
    nomes = {0: "CinzaA", 1: "CinzaB", 2: "CinzaC", 3: "Ventre", 4: "Radome", 5: "Bocal"}
    classe = np.where(c[:, 2] < Z_NARIZ + 1.9, 4, classe)
    classe = np.where(c[:, 2] > 5.2, 5, classe)
    faixas = np.digitize(c[:, 2], np.quantile(c[:, 2], np.linspace(0.1, 0.9, 9)))
    for k in range(6):
        for s in range(10):
            sel = (classe == k) & (faixas == s)
            if not sel.any():
                continue
            F = I[sel]
            usado = np.unique(F)
            mapa = -np.ones(len(V), dtype=np.int64)
            mapa[usado] = np.arange(len(usado))
            m = Malha(V[usado], mapa[F], suave=True)
            if len(m.f) > 19000:
                raise ValueError("peca grande demais: %d" % len(m.f))
            mat = "Metal" if k == 5 else "SmoothPlastic"
            cena.adicionar("%s%d" % (nomes[k], s + 1), m, cores[k], mat, metal=0.15, rug=0.5)
    for p in pecas:
        if vidro and p["nome"] == "Object_15":
            Vg = para_jogo(p["V"], esc, x_max)
            cena.adicionar("Canopi", Malha(Vg, p["F"], suave=True), (150, 190, 205), "Glass", transparencia=0.55)
    rodas = [(0, -1.55, -4.3, 0.23, 0.15, -0.4), (-1.2, -1.55, 0.5, 0.3, 0.18, -0.5), (1.2, -1.55, 0.5, 0.3, 0.18, -0.5)]
    aeronaves.trem(cena, rodas)


def principal():
    pecas, ext, esc, x_max = carregar_fonte()
    cena = Cena()
    adicionar_exterior(cena, pecas, ext, esc, x_max, int(os.environ.get("ALVO", 70000)))
    cena.ancoras(1.0)
    cena.salvar_glb(SAIDA)
    print("salvo", SAIDA, cena.triangulos(), "triangulos,", len(cena.pecas), "pecas")
    if os.environ.get("PREVIAS"):
        cena.previa(os.path.join(os.environ["PREVIAS"], "F39_gripen.png"), titulo="F39")


def cabine_sim():
    """Retorna (cena, layout) da cabine do F-39 para Sim_F39.glb e CabineLayout.lua."""
    import cabines
    pecas, ext, esc, x_max = carregar_fonte()
    cena = Cena()
    adicionar_exterior(cena, pecas, ext, esc, x_max, int(os.environ.get("ALVO_SIM", 30000)), vidro=False)
    V, F, C = construir_cabine(pecas, esc, x_max, int(os.environ.get("ALVO_CABINE", 110000)))
    n_face = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    cf = C[F].mean(axis=1)
    cf = np.clip(cf * 0.8 + 6, 0, 255)  # a textura original e bem escura; clareia um pouco
    k = 16
    centros, rot = kmeans(cf, k)
    zc = V[F].mean(axis=1)[:, 2]
    faixas = np.digitize(zc, np.quantile(zc, np.linspace(0.1, 0.9, 9)))
    for j in range(k):
        for s in range(10):
            sel = (rot == j) & (faixas == s)
            if not sel.any():
                continue
            Fs = F[sel]
            usado = np.unique(Fs)
            mapa = -np.ones(len(V), dtype=np.int64)
            mapa[usado] = np.arange(len(usado))
            m = Malha(V[usado], mapa[Fs], suave=False)
            if len(m.f) > 19000:
                raise ValueError("peca de cabine grande demais: %d" % len(m.f))
            cor = tuple(int(x) for x in centros[j])
            cena.adicionar("Cabine%d_%d" % (j, s), m, cor, "SmoothPlastic", rug=0.7)

    # manche, manete e painel de interruptores (as pecas animadas ficam com nome proprio)
    lay = {}
    bx, by, bz = 0.0, -0.05, -4.0
    haste, botoes = cabines.manche(bx, by, bz)
    cena.adicionar("Manche", haste, (26, 26, 27), "SmoothPlastic", rug=0.5)
    cena.adicionar("MancheBotoes", botoes, (60, 62, 64), "SmoothPlastic", rug=0.5)
    lay["Manche"] = {"Pivo": [bx, by, bz]}
    mx, my, mz = -0.40, 0.66, -4.05
    cena.adicionar("Manete", cabines.manete(mx, my + 0.02, mz), (28, 28, 30), "SmoothPlastic", rug=0.6)
    lay["Manete"] = {"Pivo": [mx, my + 0.02, mz]}
    from malha import caixa
    cena.adicionar("PainelChaves", caixa(0.1, 0.02, 0.62, 0.004).mover(-0.36, 0.735, -3.95), (44, 46, 50), "SmoothPlastic", rug=0.6)
    ids = ["Bateria", "Bomba", "Ignicao", "Partida", "Luzes", "FreioEst"]
    lay["Interruptores"] = [{"Id": i, "P": [-0.36, 0.745, -4.2 + 0.1 * n], "R": [0, 0, 0]} for n, i in enumerate(ids)]
    # telas: tres MFDs do painel (posicoes medidas na malha original)
    inc = -11
    lay["Telas"] = [
        {"Nome": "MFD_E", "P": [-0.2155, 0.5535, -4.592], "R": [inc, 0, 0], "Tam": [0.16, 0.12], "Pagina": "PFD"},
        {"Nome": "MFD_D", "P": [0.2215, 0.5545, -4.592], "R": [inc, 0, 0], "Tam": [0.16, 0.12], "Pagina": "MAPA"},
        {"Nome": "MFD_C", "P": [0.0035, 0.482, -4.585], "R": [inc, 0, 0], "Tam": [0.12, 0.155], "Pagina": "ISIS"},
    ]
    lay["Mostradores"] = []
    lay["Luzes"] = []
    lay["HUD"] = {"P": [0, 0.887, -4.505], "R": [28, 0, 0], "Tam": [0.24, 0.19]}
    lay["Flape"] = {"P": [-0.40, 0.75, -3.45], "R": [0, 0, 0]}
    lay["Trem"] = {"P": [-0.36, 0.56, -4.57], "R": [inc, 0, 0]}
    lay["Olho"] = [0, 1.0, -3.6]
    lay["Rodas"] = True
    cena.ancoras()
    return cena, lay


if __name__ == "__main__":
    principal()
