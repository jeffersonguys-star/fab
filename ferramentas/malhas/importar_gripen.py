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
import decimar  # noqa: E402

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
    remover_manche = True
    cache = {}
    Vs, Fs, Cs, n = [], [], [], 0
    for p in sel:
        Vs.append(para_jogo(p["V"], esc, x_max))
        Fs.append(p["F"] + n)
        Cs.append(cor_vertices(p, cache))
        n += len(p["V"])
    V, I, C = np.vstack(Vs), np.vstack(Fs), np.vstack(Cs)
    print("cabine original:", len(I), "triangulos")
    # reduz cada peca original por colapso de arestas (proporcional ao tamanho), mantendo as cores
    total = sum(len(p["F"]) for p in sel)
    Vo, Fo, Co, n0 = [], [], [], 0
    k = 0
    for p in sel:
        alvo_p = max(60, int(alvo * len(p["F"]) / total))
        Vp = Vs[k]
        Vd, Fd, Cd = decimar.decimar(Vp, p["F"], alvo_p, C=Cs[k])
        Vo.append(Vd); Fo.append(Fd + n0); Co.append(Cd); n0 += len(Vd)
        k += 1
    novo, F, cn = np.vstack(Vo), np.vstack(Fo), np.vstack(Co)
    print("cabine reduzida:", len(F))
    # tira o manche original (o manche animado do simulador toma o lugar dele)
    cm = novo[F].mean(axis=1)
    caixa_m = (np.abs(cm[:, 0]) < 0.07) & (cm[:, 1] > 0.16) & (cm[:, 1] < 0.56) & (cm[:, 2] > -4.32) & (cm[:, 2] < -3.95)
    F = F[~caixa_m]
    print("faces do manche original removidas:", int(caixa_m.sum()))
    return novo, F, cn


def adicionar_em_blocos(cena, nome, V, F, cor, material="SmoothPlastic", suave=True, limite=18000, **kw):
    """Divide as faces em poucas pecas (<= limite triangulos), ordenadas ao longo de Z."""
    if len(F) == 0:
        return
    ordem = np.argsort(V[F].mean(axis=1)[:, 2])
    F = F[ordem]
    n = int(np.ceil(len(F) / limite))
    for i in range(n):
        Fi = F[i * len(F) // n:(i + 1) * len(F) // n]
        usado = np.unique(Fi)
        mapa = -np.ones(len(V), dtype=np.int64)
        mapa[usado] = np.arange(len(usado))
        cena.adicionar("%s%d" % (nome, i + 1), Malha(V[usado], mapa[Fi], suave=suave), cor, material, **kw)


def carregar_fonte():
    _, pecas = gltf_leitor.carregar(FONTE)
    ext = [p for p in pecas if p["material"] == MAT_EXT]
    todos = np.vstack([p["V"] for p in ext])
    esc = ENVERGADURA / (todos[:, 2].max() - todos[:, 2].min())
    return pecas, ext, esc, todos[:, 0].max()


def adicionar_exterior(cena, pecas, ext, esc, x_max, alvo, vidro=True, sem_regiao_cabine=False, trem=True):
    Vs, Fs, n = [], [], 0
    for p in ext:
        Vs.append(para_jogo(p["V"], esc, x_max))
        Fs.append(p["F"] + n)
        n += len(p["V"])
    V = np.vstack(Vs)
    I = np.vstack(Fs)
    print("exterior original:", len(I), "triangulos, escala", round(esc, 4))
    # solda vertices coincidentes (as pecas originais se encostam) e reduz por colapso de arestas
    chave = np.round(V / 1e-4).astype(np.int64)
    _, primeiro, inv = np.unique(chave, axis=0, return_index=True, return_inverse=True)
    Vw = V[primeiro]
    Iw = inv.reshape(-1)[I]
    Vr, Fr = decimar.decimar(Vw, Iw, alvo)
    celula = 0
    V, I = Vr, Fr
    c = V[I].mean(axis=1)
    if sem_regiao_cabine:
        # na cabine o piloto nao ve a casca externa em volta dele: tira essa regiao (evita fragmentos na frente da camera)
        dentro = (np.abs(c[:, 0]) < 0.48) & (c[:, 2] > -4.95) & (c[:, 2] < -2.7) & (c[:, 1] > -0.15)
        I = I[~dentro]
        c = c[~dentro]
    print("exterior reduzido:", len(I), "celula", round(celula, 3))
    n_face = np.cross(V[I[:, 1]] - V[I[:, 0]], V[I[:, 2]] - V[I[:, 0]])
    n_face /= np.maximum(np.linalg.norm(n_face, axis=1), 1e-9)[:, None]
    cima = n_face[:, 1] > 0.25
    classe = np.where(cima, 0, 1)
    classe = np.where(c[:, 2] < Z_NARIZ + 1.9, 2, classe)
    classe = np.where(c[:, 2] > 5.2, 3, classe)
    cores = {0: (108, 114, 120), 1: (146, 152, 158), 2: (58, 62, 66), 3: (36, 38, 42)}
    nomes = {0: "Cinza", 1: "Ventre", 2: "Radome", 3: "Bocal"}
    for k in range(4):
        adicionar_em_blocos(cena, nomes[k], V, I[classe == k], cores[k], "Metal" if k == 3 else "SmoothPlastic", metal=0.15, rug=0.5)
    if vidro:
        for p in pecas:
            if p["nome"] == "Object_15":
                Vg = para_jogo(p["V"], esc, x_max)
                cena.adicionar("Canopi", Malha(Vg, p["F"], suave=True), (150, 190, 205), "Glass", transparencia=0.55)
    adicionar_armamento(cena, pecas, esc, x_max)
    adicionar_cocares(cena, V, I)
    return trem_gripen(cena) if trem else {}


MATS_ARMAS = {"lau_7": (150, 154, 158), "bol_451_container": (214, 216, 212), "lavett_71": (120, 124, 128),
              "lavett_75_launcher": (120, 124, 128), "saab_jas39a_pylon1": (112, 116, 120)}


def adicionar_armamento(cena, pecas, esc, x_max):
    """Cabides e misseis de curto alcance do modelo original, bem simplificados."""
    por_cor = {}
    for p in pecas:
        cor = MATS_ARMAS.get(p["material"])
        if cor is None:
            continue
        Vp = para_jogo(p["V"], esc, x_max)
        Vd, Fd = decimar.decimar(Vp, p["F"], max(80, len(p["F"]) // 5))
        por_cor.setdefault(cor, []).append((Vd, Fd))
    for i, (cor, lst) in enumerate(por_cor.items()):
        Vs_, Fs_, n_ = [], [], 0
        for Vd, Fd in lst:
            Vs_.append(Vd); Fs_.append(Fd + n_); n_ += len(Vd)
        adicionar_em_blocos(cena, "Armas%d_" % i, np.vstack(Vs_), np.vstack(Fs_), cor, "SmoothPlastic", metal=0.1, rug=0.5)


def superficie_y(V, I, x, z):
    """Alturas minima e maxima das faces que cobrem o ponto (x, z) visto de cima."""
    T = V[I][:, :, [0, 2]]
    a, b, c = T[:, 0], T[:, 1], T[:, 2]
    p = np.array([x, z])
    d = (b[:, 1] - c[:, 1]) * (a[:, 0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (a[:, 1] - c[:, 1])
    ok = np.abs(d) > 1e-12
    l1 = np.where(ok, ((b[:, 1] - c[:, 1]) * (p[0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (p[1] - c[:, 1])) / np.where(ok, d, 1), -1)
    l2 = np.where(ok, ((c[:, 1] - a[:, 1]) * (p[0] - c[:, 0]) + (a[:, 0] - c[:, 0]) * (p[1] - c[:, 1])) / np.where(ok, d, 1), -1)
    l3 = 1 - l1 - l2
    dentro = (l1 >= 0) & (l2 >= 0) & (l3 >= 0)
    if not dentro.any():
        return None
    Y = V[I][:, :, 1]
    yy = l1 * Y[:, 0] + l2 * Y[:, 1] + l3 * Y[:, 2]
    return yy[dentro].min(), yy[dentro].max()


def adicionar_cocares(cena, V, I):
    """Cocares da FAB nas asas (cima e baixo): o disco e assentado na altura da superficie."""
    import aeronaves as av
    from malha import Malha
    acum = {}
    for lado in (-1, 1):
        cx, cz, d = lado * 3.45, 2.0, 0.7
        ys = superficie_y(V, I, cx, cz)
        if ys is None:
            continue
        for topo in (True, False):
            y0 = ys[1] + 0.012 if topo else ys[0] - 0.012
            for k, (m, cor) in enumerate(av.cocar(d)):
                mm = m.copia()
                mm.v = mm.v * np.array([1.0, 0.3, 1.0])
                mm = mm.mover(cx, y0, cz)
                if not topo:
                    mm = mm.copia()
                    mm.v = mm.v.copy()
                    mm.v[:, 1] = 2 * y0 - mm.v[:, 1] + 0.0
                    mm.f = mm.f[:, ::-1]
                acum[cor] = acum[cor] + mm if cor in acum else mm
    nomes = {(0, 151, 57): "CocarVerde", (254, 221, 0): "CocarAmarelo", (0, 39, 118): "CocarAzul", (250, 250, 250): "CocarEstrela"}
    for cor, m in acum.items():
        cena.adicionar(nomes.get(cor, "Cocar"), m, cor, "SmoothPlastic", rug=0.6)


def trem_gripen(cena):
    """Trem de pouso do Gripen: pernas com amortecedor, garfo, freio e rodas; cada perna e uma peca com pivo de recolhimento."""
    from malha import tubo, cilindro, revolucao, caixa
    CROMO, CINZA, PRETO_B = (176, 182, 188), (92, 96, 102), (20, 20, 22)

    def pneu(r, w, x, yc, z):
        pn = revolucao([(r * 0.55, -w / 2), (r * 0.94, -w / 2), (r, -w * 0.32), (r, w * 0.32), (r * 0.94, w / 2), (r * 0.55, w / 2)], 24).girar("y", 90).mover(x, yc, z)
        aro = cilindro(r * 0.58, w * 0.86, 20, "x").mover(x, yc, z)
        return pn, aro

    # perna do nariz (rodas duplas)
    zN, rN, wN = -4.3, 0.21, 0.13
    ycN = -1.55 + rN
    pnA, arA = pneu(rN, wN, -0.1, ycN, zN)
    pnB, arB = pneu(rN, wN, 0.1, ycN, zN)
    perna = cilindro(0.055, 0.7, 14, "y").mover(0, -0.85, zN) + cilindro(0.038, 0.5, 12, "y").mover(0, -1.18, zN)
    garfo = tubo([[-0.13, ycN, zN], [-0.13, ycN + 0.12, zN], [0, ycN + 0.17, zN]], 0.016, 8) + tubo([[0.13, ycN, zN], [0.13, ycN + 0.12, zN], [0, ycN + 0.17, zN]], 0.016, 8)
    elo = tubo([[0, -0.78, zN], [0, -0.92, zN - 0.16], [0, -1.1, zN - 0.02]], 0.013, 8)
    escora = tubo([[0, -0.62, zN], [0, -0.42, zN + 0.55]], 0.022, 8)
    farol = caixa(0.07, 0.05, 0.05).mover(0, -0.7, zN - 0.07)
    cena.adicionar("TremNariz", perna + garfo + elo + escora + farol + arA + arB, CROMO, "Metal", metal=0.7, rug=0.35)
    cena.adicionar("TremNarizPneus", pnA + pnB, PRETO_B, "Rubber")

    art = {"TremNariz": {"Pivo": [0, -0.5, zN], "Eixo": [1, 0, 0], "Ang": -90}}
    # pernas principais
    zM, rM, wM, xM = 0.5, 0.33, 0.2, 1.2
    ycM = -1.55 + rM
    for lado, nome, ang in ((-1, "E", 90), (1, "D", -90)):
        x = lado * xM
        pn, ar = pneu(rM, wM, x, ycM, zM)
        amort = cilindro(0.07, 0.55, 16, "y").mover(x, -0.78, zM - 0.04) + cilindro(0.048, 0.5, 14, "y").mover(x, -1.1, zM - 0.05)
        eixo_ = cilindro(0.04, 0.34, 12, "x").mover(x, ycM, zM)
        disco = cilindro(0.2, 0.025, 20, "x").mover(x + lado * 0.1, ycM, zM)
        brace = tubo([[x, -0.72, zM - 0.04], [x - lado * 0.5, -0.5, zM + 0.35]], 0.026, 8)
        brace2 = tubo([[x, -0.95, zM - 0.05], [x - lado * 0.45, -0.52, zM - 0.5]], 0.02, 8)
        elo = tubo([[x, -0.92, zM - 0.03], [x, -1.0, zM - 0.17], [x, -1.18, zM - 0.06]], 0.014, 8)
        cena.adicionar("TremPrincipal%s" % nome, amort + eixo_ + disco + brace + brace2 + elo + ar, CROMO, "Metal", metal=0.7, rug=0.35)
        cena.adicionar("TremPrincipal%sPneus" % nome, pn, PRETO_B, "Rubber")
        art["TremPrincipal%s" % nome] = {"Pivo": [x * 0.96, -0.5, zM], "Eixo": [0, 0, 1], "Ang": ang}
    return art


def principal():
    pecas, ext, esc, x_max = carregar_fonte()
    cena = Cena()
    adicionar_exterior(cena, pecas, ext, esc, x_max, int(os.environ.get("ALVO", 45000)))
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
    art = adicionar_exterior(cena, pecas, ext, esc, x_max, int(os.environ.get("ALVO_SIM", 38000)), vidro=False, sem_regiao_cabine=True)
    V, F, C = construir_cabine(pecas, esc, x_max, int(os.environ.get("ALVO_CABINE", 70000)))
    cf = C[F].mean(axis=1)
    cf = np.clip(cf * 1.2 + 16, 0, 255)  # a textura original e bem escura; clareia um pouco
    k = 10
    centros, rot = kmeans(cf, k)
    for j in range(k):
        cor = tuple(int(x) for x in centros[j])
        adicionar_em_blocos(cena, "Cabine%d_" % j, V, F[rot == j], cor, "SmoothPlastic", suave=False, rug=0.7)

    # manche, manete e painel de interruptores (as pecas animadas ficam com nome proprio)
    lay = {}
    bx, by, bz = 0.0, 0.08, -4.08
    haste, botoes = cabines.manche(bx, by, bz)
    cena.adicionar("Manche", haste, (74, 76, 80), "SmoothPlastic", rug=0.5)
    cena.adicionar("MancheBotoes", botoes, (120, 122, 126), "SmoothPlastic", rug=0.5)
    lay["Manche"] = {"Pivo": [bx, by, bz]}
    mx, my, mz = -0.38, 0.70, -3.5
    cena.adicionar("Manete", cabines.manete(mx, my + 0.02, mz), (84, 86, 90), "SmoothPlastic", rug=0.6)
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
    from malha import tubo
    punho = tubo([[-0.08, 0.24, -3.86], [-0.08, 0.34, -3.9], [0.08, 0.34, -3.9], [0.08, 0.24, -3.86]], 0.014, 8)
    cena.adicionar("PunhoEjecao", punho, (232, 186, 18), "SmoothPlastic", rug=0.5)
    lay["Ejecao"] = {"P": [0, 0.34, -3.9], "R": [0, 0, 0]}
    lay["TremArt"] = art
    lay["Olho"] = [0, 1.0, -3.6]
    lay["Rodas"] = True
    cena.ancoras()
    return cena, lay


if __name__ == "__main__":
    principal()
