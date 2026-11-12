"""
FAB - cabines do simulador.

Gera, para cada aeronave, um modelo "Sim_<ID>" com o exterior (fuselagem, asas, nariz,
helice, trem) e uma cabine interna detalhada: assento ejetavel com cintos e punho,
banheira com cavernas e chicotes eletricos, consoles laterais com placas, parafusos,
interruptores, botoes e seletores, painel com molduras de MFD (com botoes de funcao) ou
aros de instrumentos analogicos, para-sol, projetor e moldura do HUD, manche com punho
de caca, manete, pedais e espelhos.

As telas, os mostradores, os interruptores que funcionam, o vidro do HUD e os pivos do
manche, da manete e da helice sao exportados em CabineLayout.lua para o jogo montar as
partes vivas exatamente no lugar certo.

Unidades em metros, Y para cima, nariz para -Z (mesmo referencial da fisica).
"""
import math
import os
import random

import numpy as np

import aeronaves
from malha import Cena, Malha, caixa, cilindro, revolucao, superelipsoide, tubo, extrusao

# cores
PAINEL = (44, 46, 50)
PAINEL_ESCURO = (30, 31, 34)
PRETO = (14, 14, 15)
BORRACHA = (20, 20, 20)
LEGENDA = (214, 214, 206)
CROMO = (196, 200, 204)
METAL = (92, 96, 102)
VERDE_ASSENTO = (62, 70, 54)
CINTO = (72, 78, 56)
AMARELO = (232, 186, 18)
VERMELHO = (180, 24, 24)
INTERIOR = (56, 60, 64)
FIO = (34, 36, 38)


class Grupo:
    """Acumula muitas pecas pequenas num unico no (MeshPart)."""

    def __init__(self):
        self.partes = []

    def add(self, m):
        if m is not None and len(m.f):
            self.partes.append(m)

    def malha(self):
        if not self.partes:
            return Malha()
        vs, fs, base = [], [], 0
        for m in self.partes:
            vs.append(m.v)
            fs.append(m.f + base)
            base += len(m.v)
        return Malha(np.vstack(vs), np.vstack(fs), suave=all(m.suave for m in self.partes))


def dividir(m, limite=18000):
    """Divide uma malha grande em pedacos abaixo do limite de triangulos do Roblox."""
    if len(m.f) <= limite:
        return [m]
    pedacos = []
    for i in range(0, len(m.f), limite):
        f = m.f[i:i + limite]
        usados, inv = np.unique(f.reshape(-1), return_inverse=True)
        pedacos.append(Malha(m.v[usados], inv.reshape(-1, 3), m.suave))
    return pedacos


def rot(m, rx=0.0, ry=0.0, rz=0.0):
    """Mesma ordem do CFrame.Angles do Roblox (Z, depois Y, depois X)."""
    if rz:
        m = m.girar("z", rz)
    if ry:
        m = m.girar("y", ry)
    if rx:
        m = m.girar("x", rx)
    return m


class Quadro:
    """Referencial local de uma superficie (painel inclinado ou console).
    Local: u = direita, v = para cima ao longo da superficie, w = para fora (em direcao ao piloto)."""

    def __init__(self, centro, rx, ry=0.0):
        self.c = np.array(centro, dtype=float)
        self.rx, self.ry = rx, ry

    def malha(self, m):
        return rot(m, self.rx, self.ry).mover(*self.c)

    def ponto(self, u, v, w=0.0):
        p = Malha(np.array([[u, v, w]]), np.zeros((0, 3), dtype=np.int64))
        return rot(p, self.rx, self.ry).v[0] + self.c

    def item(self, u, v, w=0.0, **extra):
        p = self.ponto(u, v, w)
        d = {"P": [round(float(x), 4) for x in p], "R": [round(self.rx, 2), round(self.ry, 2), 0]}
        d.update(extra)
        return d


# ELEMENTOS DE DETALHE ---------------------------------------------------------------
def parafuso(u, v):
    return cilindro(0.0042, 0.003, 6).mover(u, v, 0.0015)


def interruptor_alavanca(g_cromo, g_preto, u, v, ang=25):
    g_preto.add(cilindro(0.0065, 0.004, 8).mover(u, v, 0.002))
    g_cromo.add(rot(cilindro(0.0022, 0.02, 6), ang).mover(u, v + 0.004, 0.011))
    g_cromo.add(superelipsoide(0.006, 0.006, 0.006, 2, 6, 4).mover(u, v + 0.009, 0.02))


def seletor(g_preto, g_leg, u, v, r=0.011):
    g_preto.add(revolucao([(r, 0), (r, 0.006), (r * 0.8, 0.013), (r * 0.75, 0.016)], 12).mover(u, v, 0))
    g_preto.add(caixa(0.004, r * 1.4, 0.006).mover(u, v + r * 0.1, 0.018))
    g_leg.add(caixa(0.0015, 0.004, 0.001).mover(u, v + r + 0.004, 0.0006))
    for a in (-60, -30, 0, 30, 60):
        ra = math.radians(a)
        g_leg.add(caixa(0.0012, 0.0035, 0.001).mover(u + math.sin(ra) * (r + 0.006), v + math.cos(ra) * (r + 0.006), 0.0006))


def botao(g, u, v, s=0.012):
    g.add(caixa(s, s * 0.8, 0.006).mover(u, v, 0.003))


def guarda(g_verm, g_cromo, g_preto, u, v):
    interruptor_alavanca(g_cromo, g_preto, u, v, 0)
    g_verm.add(caixa(0.018, 0.026, 0.004).mover(u, v + 0.002, 0.026))
    for s in (-1, 1):
        g_verm.add(caixa(0.002, 0.026, 0.024).mover(u + s * 0.009, v + 0.002, 0.014))


def legenda(g, u, v, larg=0.026):
    g.add(caixa(larg, 0.0035, 0.0008).mover(u, v, 0.0004))


def placas_superficie(q, x0, x1, y0, y1, rng, G, densidade=1.0):
    """Preenche uma area (coordenadas u, v do quadro q) com placas de comando realistas."""
    v = y1
    while v > y0 + 0.03:
        alt = rng.choice([0.05, 0.065, 0.08, 0.1])
        alt = min(alt, v - y0)
        u = x0
        while u < x1 - 0.03:
            larg = min(rng.choice([0.06, 0.08, 0.11, 0.14]), x1 - u)
            cu, cv = u + larg / 2, v - alt / 2
            placa = caixa(larg - 0.004, alt - 0.004, 0.006, 0).mover(cu, cv, 0.003)
            G["placa"].add(q.malha(placa))
            loc_c = Grupo()
            loc_p = Grupo()
            loc_l = Grupo()
            loc_v = Grupo()
            for su in (-1, 1):
                for sv in (-1, 1):
                    loc_p.add(parafuso(cu + su * (larg / 2 - 0.007), cv + sv * (alt / 2 - 0.007)).mover(0, 0, 0.006))
            n = max(1, int(larg / 0.03 * densidade))
            tipo_placa = rng.random()
            for k in range(n):
                pu = u + (k + 0.5) * larg / n
                pv = cv - 0.004
                r = rng.random()
                if tipo_placa < 0.45:
                    interruptor_alavanca(loc_c, loc_p, pu, pv, rng.choice([25, -25, 25]))
                elif tipo_placa < 0.7:
                    if r < 0.6:
                        seletor(loc_p, loc_l, pu, pv, 0.009 if larg < 0.1 else 0.011)
                    else:
                        botao(loc_p, pu, pv)
                elif tipo_placa < 0.85:
                    botao(loc_p, pu, pv, 0.014)
                    legenda(loc_l, pu, pv + 0.013, 0.012)
                else:
                    if r < 0.3:
                        guarda(loc_v, loc_c, loc_p, pu, pv)
                    else:
                        interruptor_alavanca(loc_c, loc_p, pu, pv)
                legenda(loc_l, pu, cv + alt / 2 - 0.012, min(0.022, larg / n * 0.8))
            for nome, grupo in (("cromo", loc_c), ("preto", loc_p), ("legenda", loc_l), ("vermelho", loc_v)):
                m = grupo.malha()
                if len(m.f):
                    G[nome].add(q.malha(m.mover(0, 0, 0.006)))
            u += larg
        v -= alt


def moldura_mfd(q, u, v, larg, alt, G, botoes=5, lados=("cima", "baixo", "esq", "dir")):
    """Moldura de tela multifuncao com botoes de funcao (OSB) e balancins."""
    b = 0.028
    fr = Grupo()
    fr.add(caixa(larg + 2 * b, b, 0.016).mover(u, v + alt / 2 + b / 2, 0.008))
    fr.add(caixa(larg + 2 * b, b, 0.016).mover(u, v - alt / 2 - b / 2, 0.008))
    fr.add(caixa(b, alt, 0.016).mover(u - larg / 2 - b / 2, v, 0.008))
    fr.add(caixa(b, alt, 0.016).mover(u + larg / 2 + b / 2, v, 0.008))
    G["moldura"].add(q.malha(fr.malha()))
    bt = Grupo()
    lg = Grupo()
    for lado in lados:
        for k in range(botoes):
            t = (k + 0.5) / botoes - 0.5
            if lado in ("cima", "baixo"):
                bu, bv = u + t * larg * 0.92, v + (alt / 2 + b / 2) * (1 if lado == "cima" else -1)
            else:
                bu, bv = u + (larg / 2 + b / 2) * (1 if lado == "dir" else -1), v + t * alt * 0.92
            bt.add(caixa(0.013, 0.011, 0.006).mover(bu, bv, 0.019))
    for su in (-1, 1):
        for sv in (-1, 1):
            bt.add(caixa(0.016, 0.009, 0.007).mover(u + su * (larg / 2 + b / 2), v + sv * (alt / 2 + b / 2), 0.019))
            lg.add(parafuso(u + su * (larg / 2 + b * 0.8), v + sv * (alt / 2 + b * 0.8)).mover(0, 0, 0.016))
    G["preto"].add(q.malha(bt.malha()))
    G["cromo"].add(q.malha(lg.malha()))


def aro_instrumento(q, u, v, diam, G):
    r = diam / 2
    aro = revolucao([(r, 0.0), (r + 0.009, 0.0), (r + 0.009, 0.012), (r + 0.004, 0.016), (r, 0.014)], 28)
    G["moldura"].add(q.malha(aro.mover(u, v, 0)))
    for k in range(4):
        a = math.radians(45 + k * 90)
        G["cromo"].add(q.malha(parafuso(u + math.cos(a) * (r + 0.016), v + math.sin(a) * (r + 0.016)).mover(0, 0, 0.0)))
    # caixa traseira do instrumento (visivel pelas frestas)
    G["placa"].add(q.malha(cilindro(r + 0.004, 0.05, 20).mover(u, v, -0.025)))


def assento(g, x, y_piso, z, oy, almofada_y):
    """Assento ejetavel detalhado (estilo Martin-Baker): balde, almofadas, paraquedas,
    caixa de cabeca com drogue, trilhos, cintos e punho de ejecao listrado."""
    yb = almofada_y
    # balde e estrutura
    g["assento_estr"].add(caixa(0.50, 0.30, 0.50, 0.025).mover(x, yb - 0.17, z))
    for s in (-1, 1):
        lat = extrusao([[-0.25, -0.05], [0.25, -0.05], [0.25, 0.18], [0.05, 0.22], [-0.25, 0.12]], 0.035)
        g["assento_estr"].add(lat.girar("y", 90).mover(x + s * 0.265, yb, z))
        # trilhos de ejecao atras do encosto
        g["assento_metal"].add(caixa(0.05, 1.05, 0.06).girar("x", -14).mover(x + s * 0.17, yb + 0.52, z + 0.42))
        # alcas laterais e cartuchos
        g["assento_metal"].add(cilindro(0.02, 0.16, 10, "y").mover(x + s * 0.29, yb + 0.05, z - 0.12))
    # almofada do assento e encosto
    g["assento_tecido"].add(caixa(0.44, 0.08, 0.44, 0.03).mover(x, yb, z - 0.01))
    g["assento_tecido"].add(caixa(0.43, 0.70, 0.12, 0.035).girar("x", -14).mover(x, yb + 0.40, z + 0.28))
    # encosto lombar e costuras
    for k in range(4):
        g["assento_costura"].add(caixa(0.40, 0.006, 0.006).girar("x", -14).mover(x, yb + 0.15 + k * 0.15, z + 0.215 - k * 0.037))
    # caixa de cabeca (paraquedas) com o tubo do drogue
    g["assento_estr"].add(caixa(0.40, 0.36, 0.26, 0.03).girar("x", -14).mover(x, yb + 0.92, z + 0.39))
    g["assento_tecido"].add(caixa(0.30, 0.20, 0.06, 0.025).girar("x", -14).mover(x, yb + 0.86, z + 0.255))
    g["assento_metal"].add(cilindro(0.06, 0.22, 14, "y").girar("x", -14).mover(x - 0.1, yb + 1.12, z + 0.47))
    g["assento_verm"].add(caixa(0.12, 0.03, 0.03).mover(x + 0.08, yb + 1.08, z + 0.32))
    # cintos de ombro e abdominais
    for s in (-1, 1):
        g["cinto"].add(tubo([[x + s * 0.12, yb + 0.72, z + 0.24], [x + s * 0.12, yb + 0.45, z + 0.13], [x + s * 0.08, yb + 0.18, z + 0.0]], 0.022, 4))
        g["cinto"].add(tubo([[x + s * 0.22, yb + 0.03, z + 0.16], [x + s * 0.16, yb + 0.12, z - 0.02], [x + s * 0.03, yb + 0.14, z - 0.08]], 0.02, 4))
        g["assento_metal"].add(caixa(0.05, 0.04, 0.012).mover(x + s * 0.05, yb + 0.15, z - 0.09))
    g["assento_metal"].add(cilindro(0.04, 0.02, 14, "z").mover(x, yb + 0.15, z - 0.095))
    # kit de sobrevivencia e punho de ejecao amarelo e preto entre as pernas
    pts = [[x - 0.05, yb - 0.02, z - 0.22], [x - 0.05, yb + 0.07, z - 0.25], [x + 0.05, yb + 0.07, z - 0.25], [x + 0.05, yb - 0.02, z - 0.22]]
    n = 9
    for k in range(n):
        a = k / n
        b = (k + 1) / n
        seg = []
        for t in np.linspace(a, b, 3):
            i = min(int(t * 3), 2)
            f = t * 3 - i
            p0, p1 = np.array(pts[i]), np.array(pts[min(i + 1, 3)])
            seg.append(list(p0 + (p1 - p0) * f))
        (g["amarelo"] if k % 2 == 0 else g["preto"]).add(tubo(seg, 0.011, 8))
    # mangueira de oxigenio
    g["fio"].add(tubo([[x + 0.18, yb + 0.05, z - 0.05], [x + 0.26, yb - 0.05, z - 0.1], [x + 0.33, yb - 0.02, z - 0.25]], 0.014, 8))


def manche(cx, base_y, z):
    """Manche de caca com coifa, haste e punho com chapeu, gatilho e botoes. Pivo na base."""
    g_p = Grupo()
    g_b = Grupo()
    g_b.add(revolucao([(0.075, 0.0), (0.06, 0.03), (0.035, 0.07), (0.022, 0.1)], 18).girar("x", -90).mover(cx, base_y, z))
    g_p.add(cilindro(0.016, 0.24, 12, "y").mover(cx, base_y + 0.2, z))
    punho = superelipsoide(0.05, 0.13, 0.06, 2.6, 14, 10).girar("x", 12).mover(cx, base_y + 0.37, z - 0.01)
    g_p.add(punho)
    g_p.add(caixa(0.06, 0.02, 0.06, 0.01).mover(cx, base_y + 0.305, z))
    g_p.add(caixa(0.012, 0.035, 0.014).girar("x", 25).mover(cx, base_y + 0.36, z - 0.04))  # gatilho
    for dx, dy in ((0, 0.43), (-0.016, 0.415), (0.016, 0.415)):
        g_b.add(cilindro(0.006, 0.01, 8, "y").mover(cx + dx, base_y + dy, z + 0.005))
    g_b.add(caixa(0.02, 0.012, 0.02).mover(cx - 0.024, base_y + 0.4, z + 0.012))
    return g_p.malha(), g_b.malha()


def manete(x, y, z):
    g = Grupo()
    g.add(caixa(0.022, 0.12, 0.022).mover(x, y + 0.06, z))
    g.add(superelipsoide(0.055, 0.075, 0.09, 2.6, 12, 8).mover(x - 0.008, y + 0.13, z - 0.01))
    for dz in (-0.03, 0.0, 0.03):
        g.add(cilindro(0.005, 0.01, 6, "x").mover(x + 0.025, y + 0.14, z + dz))
    return g.malha()


# CABINE COMPLETA ----------------------------------------------------------------------
CONF = {
    "F39": {"paineis": "wad", "hud": "largo", "manche_x": 0.0},
    "F5": {"paineis": "mfd_quadrado", "hud": "normal"},
    "A29": {"paineis": "mfd_retrato", "hud": "normal"},
    "T27": {"paineis": "analogico"},
    "T25": {"paineis": "analogico_lado"},
}


def construir(spec):
    rng = random.Random(hash(spec["id"]) % 1000)
    pid = spec["id"]
    conf = CONF[pid]
    ox, oy, oz = spec["olho"]
    sill = oy - 0.42
    cab_l = spec["cab_larg"] if "cab_larg" in spec else 0.84
    cz1, cz2 = spec["cab_z"]
    piso = sill - spec.get("prof_cabine", 1.0)
    lado = pid == "T25"
    px = 0.0 if lado else ox  # centro do painel
    painel_w = spec.get("larg_painel", cab_l * 0.92)
    G = {k: Grupo() for k in ("placa", "cromo", "preto", "legenda", "vermelho", "moldura", "painel", "parasol", "assento_estr",
                              "assento_metal", "assento_tecido", "assento_costura", "assento_verm", "cinto", "amarelo", "fio",
                              "estrutura", "console", "pedal", "hud", "espelho", "borracha", "arco")}
    layout = {"Olho": [ox, oy, oz], "Telas": [], "Mostradores": [], "Interruptores": [], "Luzes": []}

    cena_ext = aeronaves.construir(spec)
    cena = Cena()
    remover = {"InteriorCabine", "AssentoEstofado", "AssentoEstrutura", "PunhoEjecao", "Painel", "ParaSol", "Consoles", "Ancora_Origem",
               "Ancora_Frente", "Ancora_Cima", "Soleiras"}
    remover.add("ArcosCanopi")  # refeitos abaixo, mais finos e foscos

    def fora_da_cabine(c):
        dentro = (np.abs(c[:, 0]) < cab_l / 2 + 0.03) & (c[:, 2] > cz1 + 0.02) & (c[:, 2] < cz2 - 0.02) & (c[:, 1] > piso + 0.02)
        return ~dentro
    for nome, malha, cor, metal, rug, alfa in cena_ext.pecas:
        base = nome.split("@")[0]
        if base in remover:
            continue
        if base in ("Fuselagem", "Faixa", "Cocar", "Detalhes", "BandeiraDeriva"):
            malha = malha.filtrar_faces(fora_da_cabine)
        cena.pecas.append((nome, malha, cor, metal, rug, alfa))
        if base == "Canopi":
            # face interna do vidro (o MeshPart so desenha um lado)
            partes = nome.split("@")
            cena.pecas.append(("CanopiInterno@" + "@".join(partes[1:]), malha.inverter(), cor, metal, rug, alfa))

    # BANHEIRA: pele interna com cavernas, longarinas e chicotes ----------------------------
    comp = cz2 - cz1
    meia = cab_l / 2 - 0.01
    G["estrutura"].add(caixa(cab_l - 0.02, 0.02, comp - 0.04).mover(0, piso + 0.01, (cz1 + cz2) / 2))
    for s in (-1, 1):
        G["estrutura"].add(caixa(0.012, sill - piso, comp - 0.04).mover(s * meia, (sill + piso) / 2, (cz1 + cz2) / 2))
        z = cz1 + 0.12
        while z < cz2 - 0.08:
            G["console"].add(caixa(0.03, sill - piso - 0.04, 0.025).mover(s * (meia - 0.02), (sill + piso) / 2, z))
            z += 0.17
        for yy in (piso + 0.25, sill - 0.1):
            G["console"].add(caixa(0.02, 0.025, comp - 0.1).mover(s * (meia - 0.018), yy, (cz1 + cz2) / 2))
        for k in range(3):
            yy = sill - 0.16 - k * 0.04
            pts = []
            for t in np.linspace(cz1 + 0.15, cz2 - 0.1, 7):
                pts.append([s * (meia - 0.035 - 0.004 * math.sin(t * 9 + k)), yy + 0.012 * math.sin(t * 5 + k * 2), t])
            G["fio"].add(tubo(pts, 0.008 + 0.003 * k, 6))
        # soleira acolchoada
        G["borracha"].add(caixa(0.05, 0.022, comp - 0.05, 0.008).mover(s * (cab_l / 2 - 0.015), sill - 0.012, (cz1 + cz2) / 2))

    # CONSOLES LATERAIS --------------------------------------------------------------------
    consoles = [(-1, ox), (1, ox)] if not lado else [(-1, 0.0), (1, 0.0)]
    topo_console = oy - 0.64
    zc1, zc2 = oz - 0.5, min(oz + 0.45, cz2 - 0.12)
    for s, cx in consoles:
        largc = 0.17 if not lado else 0.2
        xc = s * (meia - largc / 2 - 0.02)
        G["console"].add(caixa(largc, topo_console - piso, zc2 - zc1, 0.004).mover(xc, (topo_console + piso) / 2, (zc1 + zc2) / 2))
        q = Quadro((xc, topo_console + 0.001, (zc1 + zc2) / 2), -90)
        placas_superficie(q, -largc / 2 + 0.005, largc / 2 - 0.005, -(zc2 - zc1) / 2 + 0.005, (zc2 - zc1) / 2 - 0.005, rng, G, 1.0)
        # face lateral voltada para o piloto (placas verticais)
        q2 = Quadro((xc - s * (largc / 2 + 0.001), (topo_console + piso) / 2 + 0.1, (zc1 + zc2) / 2), 0, -90 * s)
        placas_superficie(q2, -(zc2 - zc1) / 2 + 0.02, (zc2 - zc1) / 2 - 0.02, -0.08, 0.08, rng, G, 0.6)
    if lado:
        # pedestal central entre os assentos (T-25)
        G["console"].add(caixa(0.18, topo_console - piso + 0.05, 0.7, 0.005).mover(0, (topo_console + piso) / 2, oz - 0.15))
        q = Quadro((0, topo_console + 0.051, oz - 0.15), -90)
        placas_superficie(q, -0.085, 0.085, -0.34, 0.34, rng, G, 0.8)

    # PAINEL PRINCIPAL ----------------------------------------------------------------------
    t = 10.0
    zP = oz - 0.69
    yc = oy - 0.47
    alt_painel = 0.46
    qp = Quadro((px, yc, zP), -t)
    perfil = [[-painel_w / 2, -alt_painel / 2], [painel_w / 2, -alt_painel / 2], [painel_w / 2, alt_painel / 2 - 0.05],
              [painel_w / 2 - 0.05, alt_painel / 2], [-painel_w / 2 + 0.05, alt_painel / 2], [-painel_w / 2, alt_painel / 2 - 0.05]]
    G["painel"].add(qp.malha(extrusao(perfil, 0.04).mover(0, 0, -0.02)))
    # caixa de avionicos atras do painel e parede ate o piso
    G["console"].add(caixa(painel_w, yc - piso, 0.05).mover(px, (yc + piso) / 2 - 0.1, zP - 0.12))
    # para-sol (capota) e lábio de borracha
    ps = superelipsoide(painel_w + 0.08, 0.09, 0.42, n=4.5, segs_u=32, segs_v=8, so_cima=True)
    G["parasol"].add(ps.mover(px, oy - 0.25, zP - 0.12))
    G["borracha"].add(tubo([[px - painel_w / 2 - 0.02, oy - 0.245, zP + 0.07], [px - painel_w * 0.25, oy - 0.245, zP + 0.09],
                            [px + painel_w * 0.25, oy - 0.245, zP + 0.09], [px + painel_w / 2 + 0.02, oy - 0.245, zP + 0.07]], 0.014, 8))

    tipo = conf["paineis"]
    luzes_alerta = []

    def tela(nome, u, v, w, h, pagina, botoes=5):
        moldura_mfd(qp, u, v, w, h, G, botoes)
        layout["Telas"].append(qp.item(u, v, 0.017, Nome=nome, Tam=[w, h], Pagina=pagina))

    def mostrador(nome, u, v, d):
        aro_instrumento(qp, u, v, d, G)
        layout["Mostradores"].append(qp.item(u, v, 0.004, Nome=nome, Diam=d))

    if tipo == "wad":
        # Gripen E: tela unica de area ampla (19 x 8 polegadas) e tela reserva
        tela("WAD", 0.0, 0.03, 0.48, 0.2, "WAD", 7)
        tela("Reserva", 0.30, 0.05, 0.075, 0.075, "ISIS", 2)
        luzes_alerta = [(-0.3, 0.13), (-0.3, 0.09), (0.3, 0.15)]
        placas_superficie(qp, -painel_w / 2 + 0.02, painel_w / 2 - 0.02, -alt_painel / 2 + 0.02, -0.11, rng, G, 0.9)
        placas_superficie(qp, -0.36, -0.27, -0.06, 0.06, rng, G, 0.7)
    elif tipo in ("mfd_quadrado", "mfd_retrato"):
        w, h = (0.15, 0.15) if tipo == "mfd_quadrado" else (0.145, 0.19)
        tela("MFD_E", -0.135, 0.0, w, h, "PFD", 5)
        tela("MFD_D", 0.135, 0.0, w, h, "MAPA", 5)
        mostrador("ISIS", 0.0, 0.07, 0.07)
        # painel de controle frontal (UFCP) sob o para-sol
        uf = Grupo()
        uf.add(caixa(0.2, 0.065, 0.03, 0.004).mover(0, 0, 0.015))
        for i in range(3):
            for j in range(5):
                uf.add(caixa(0.016, 0.012, 0.006).mover(-0.07 + j * 0.035 * 0.85 + 0.01, -0.012 - i * 0.0, 0.032) if i == 0 else Malha())
        for j in range(6):
            uf.add(caixa(0.014, 0.011, 0.006).mover(-0.085 + j * 0.034, -0.022, 0.033))
        G["moldura"].add(qp.malha(uf.malha().mover(0, 0.18, 0)))
        layout["Telas"].append(qp.item(0.0, 0.192, 0.031, Nome="UFCP", Tam=[0.15, 0.022], Pagina="UFCP"))
        luzes_alerta = [(-0.3, 0.13), (0.3, 0.13)]
        placas_superficie(qp, -painel_w / 2 + 0.02, painel_w / 2 - 0.02, -alt_painel / 2 + 0.02, -0.12, rng, G, 0.9)
        mostrador("Acelerometro", -0.3, 0.03, 0.06)
        if pid == "F5":
            mostrador("Combustivel", 0.3, 0.03, 0.06)
    else:
        # analogicos: seis basicos + motor
        d = 0.082
        if tipo == "analogico_lado":
            cu = ox
            base_motor = 0.05
        else:
            cu = 0.0
            base_motor = 0.21
        v1, v2 = (0.13, 0.03) if tipo == "analogico_lado" else (0.08, -0.03)
        mostrador("ASI", cu - 0.1, v1, d)
        mostrador("Atitude", cu, v1, d)
        mostrador("ALT", cu + 0.1, v1, d)
        mostrador("Curva", cu - 0.1, v2, d)
        mostrador("HI", cu, v2, d)
        mostrador("VSI", cu + 0.1, v2, d)
        if tipo == "analogico_lado":
            # terceira fileira do piloto e segunda coluna de instrumentos de motor (painel real do T-25)
            mostrador("Relogio", cu - 0.1, -0.07, d)
            mostrador("Temp", cu, -0.07, d)
            mostrador("G", cu + 0.1, -0.07, d)
            for nome_i, vi in (("Temp", 0.13), ("Relogio", 0.06), ("Comb", -0.01)):
                mostrador(nome_i, -0.115, vi, 0.058)
        mostrador("RPM", base_motor, 0.13, 0.058)
        mostrador("Comb", base_motor, 0.06, 0.058)
        mostrador("G", base_motor, -0.01 if tipo == "analogico" else -0.01, 0.058)
        if tipo == "analogico":
            mostrador("Relogio", -0.21, 0.08, 0.058)
            mostrador("Temp", -0.21, 0.01, 0.058)
            layout["Telas"].append(qp.item(0.3, 0.05, 0.004, Nome="Anunciadores", Tam=[0.07, 0.17], Pagina="ANUN"))
            placas_superficie(qp, -painel_w / 2 + 0.02, painel_w / 2 - 0.02, -alt_painel / 2 + 0.02, -0.1, rng, G, 0.9)
        else:
            layout["Telas"].append(qp.item(0.14, 0.06, 0.004, Nome="Anunciadores", Tam=[0.07, 0.17], Pagina="ANUN"))
            # pilha de radios a direita
            for k in range(4):
                G["moldura"].add(qp.malha(caixa(0.2, 0.045, 0.03, 0.003).mover(0.36, 0.14 - k * 0.055, 0.015)))
                for j in range(3):
                    seletor_g = Grupo()
                    seletor(seletor_g, G["legenda"], 0.29 + j * 0.06, 0.14 - k * 0.055, 0.008)
                    G["preto"].add(qp.malha(seletor_g.malha().mover(0, 0, 0.03)))
            placas_superficie(qp, -painel_w / 2 + 0.02, 0.24, -alt_painel / 2 + 0.02, -0.12, rng, G, 0.9)
            for fila in range(3):
                for col in range(14):
                    G["preto"].add(qp.malha(cilindro(0.0075, 0.012, 10, "z").mover(0.18 + col * 0.0185, -0.13 - fila * 0.026, 0.006)))
        luzes_alerta = [(cu - 0.2, 0.15), (cu + 0.2, 0.15)] if tipo == "analogico" else [(-0.5, 0.15)]
    for u, v in luzes_alerta:
        G["moldura"].add(qp.malha(caixa(0.04, 0.024, 0.014, 0.003).mover(u, v, 0.007)))
        layout["Luzes"].append(qp.item(u, v, 0.0145, Tam=[0.032, 0.018]))

    # INTERRUPTORES QUE FUNCIONAM (painel inferior esquerdo, inclinado) ---------------------
    qi = Quadro((px - (0.0 if not lado else -0.0), oy - 0.79, oz - 0.6), -40)
    jato = spec.get("bocais") is not None
    ids = ["Bateria", "Bomba"] + (["Ignicao"] if jato else ["Mistura", "Magnetos"]) + ["Partida", "Luzes", "FreioEst"]
    largura_fila = min(painel_w * 0.8, 0.42)
    centro_fila = (ox if lado else 0.0)
    G["painel"].add(qi.malha(caixa(largura_fila + 0.06, 0.12, 0.03, 0.006).mover(centro_fila - (px if not lado else 0), 0, -0.015)))
    for i, ident in enumerate(ids):
        u = centro_fila - (px if not lado else 0) - largura_fila / 2 + (i + 0.5) * largura_fila / len(ids)
        layout["Interruptores"].append(qi.item(u, 0.0, 0.0, Id=ident))
    # alavanca do trem a esquerda do painel e flape no console esquerdo
    layout["Trem"] = qp.item(-painel_w / 2 + 0.06 if not lado else -0.08, -0.08, 0.0)
    G["moldura"].add(qp.malha(caixa(0.07, 0.12, 0.012, 0.004).mover(layout_trem_u := (-painel_w / 2 + 0.06 if not lado else -0.08), -0.08, 0.006)))
    xm = -(meia - 0.17 / 2 - 0.02) if not lado else 0.0
    layout["Flape"] = {"P": [xm + (0.04 if not lado else 0.0), topo_console + 0.01, oz + 0.2], "R": [0, 0, 0]}

    # HUD -------------------------------------------------------------------------------------
    if conf.get("hud"):
        largo = conf["hud"] == "largo"
        hz = zP - 0.13
        hy = oy - 0.25 + 0.08
        G["hud"].add(caixa(0.2 if largo else 0.15, 0.06, 0.2, 0.01).mover(px, hy + 0.02, hz - 0.03))
        G["hud"].add(caixa(0.22 if largo else 0.17, 0.02, 0.06, 0.004).mover(px, hy + 0.06, hz + 0.06))
        gw, gh = (0.2, 0.17) if largo else (0.14, 0.13)
        gy = oy - 0.05
        gz = zP - 0.07
        for s in (-1, 1):
            G["hud"].add(tubo([[px + s * gw / 2, hy + 0.06, hz + 0.05], [px + s * gw / 2, gy + gh / 2, gz + 0.015]], 0.006, 6))
        G["hud"].add(tubo([[px - gw / 2, gy + gh / 2, gz + 0.015], [px + gw / 2, gy + gh / 2, gz + 0.015]], 0.005, 6))
        layout["HUD"] = {"P": [px, gy, gz], "R": [28, 0, 0], "Tam": [gw, gh]}

    # MANCHE, MANETE, PEDAIS ------------------------------------------------------------------
    manche_x = ox
    base_m = piso + 0.18
    zm = oz - 0.36
    haste, botoes = manche(manche_x, base_m, zm)
    layout["Manche"] = {"Pivo": [manche_x, base_m, zm]}
    if lado:
        xt, yt, zt = 0.0, topo_console + 0.05, oz - 0.2
    else:
        xt, yt, zt = -(meia - 0.17 / 2 - 0.02) + 0.02, topo_console, oz + 0.0
    G["console"].add(caixa(0.05, 0.02, 0.26, 0.004).mover(xt, yt + 0.01, zt))
    G["preto"].add(caixa(0.012, 0.004, 0.22).mover(xt, yt + 0.021, zt))
    alav = manete(xt, yt + 0.02, zt)
    layout["Manete"] = {"Pivo": [xt, yt + 0.02, zt]}
    manche2 = None
    if pid == "T25":
        # quadrante com tres alavancas (potencia, helice, mistura), botao amarelo e placas vermelhas, como no avião real
        for dx in (-0.04, 0.04):
            G["preto"].add(manete(xt + dx, yt + 0.02, zt + 0.01))
        G["amarelo"].add(superelipsoide(0.03, 0.03, 0.04, 2.4, 10, 8).mover(xt + 0.04, yt + 0.175, zt))
        G["vermelho"].add(caixa(0.1, 0.002, 0.07).girar("x", -22).mover(xt, topo_console + 0.056, oz - 0.46))
        for ux in (-0.5, 0.5):
            G["vermelho"].add(qp.malha(caixa(0.07, 0.026, 0.004).mover(ux, 0.2, 0.002)))
        G["vermelho"].add(qp.malha(caixa(0.022, 0.022, 0.006).mover(0.0, -0.05, 0.003)))
        # segundo manche (assento direito), fixo
        manche2 = manche(0.34, base_m, zm)
    for s in (-1, 1):
        ped = Grupo()
        ped.add(caixa(0.1, 0.2, 0.025, 0.006).girar("x", 25))
        ped.add(caixa(0.02, 0.18, 0.02).mover(0, 0.1, 0.05).girar("x", -20))
        G["pedal"].add(ped.malha().mover(ox + s * 0.13, piso + 0.17, zP - 0.15))

    # ASSENTOS ------------------------------------------------------------------------------
    for ax, az in spec.get("assentos", [(ox, oz + 0.35)]):
        assento(G, ax, piso, az + 0.05, oy, oy - 0.82)
    traseiro = [a for a in spec.get("assentos", []) if a[1] > oz + 0.6]
    for ax, az in traseiro:
        # painel e para-sol da nacele traseira
        qpt = Quadro((ax, oy - 0.42, az - 0.62), -10)
        G["painel"].add(qpt.malha(extrusao(perfil, 0.04)))
        G["parasol"].add(superelipsoide(painel_w + 0.06, 0.12, 0.3, n=3, segs_u=24, segs_v=6, so_cima=True).mover(ax, oy - 0.2, az - 0.72))
        placas_superficie(qpt, -painel_w / 2 + 0.02, painel_w / 2 - 0.02, -alt_painel / 2 + 0.02, alt_painel / 2 - 0.03, rng, G, 0.8)

    # ARCOS DO CANOPI E ESPELHOS RETROVISORES ---------------------------------------------------
    cz_c, cl = spec["canopi_z"], spec["canopi_comp"]
    ch = spec.get("canopi_alt", 0.7)
    arcos = spec.get("arcos", []) if pid != "F39" else []
    for zr in arcos:
        tt = (zr - cz_c) / (cl / 2)
        if abs(tt) >= 1:
            continue
        esc = (1 - abs(tt) ** 2.3) ** (1 / 2.3)
        pts = [[math.cos(math.pi * k / 16) * (cab_l + 0.05) / 2 * esc, sill + math.sin(math.pi * k / 16) * ch * esc, zr] for k in range(17)]
        G["arco"].add(tubo(pts, 0.034 if pid == "T25" else 0.016, 10))
    def pw(c, e):
        return math.copysign(abs(c) ** e, c)
    borda = [[pw(math.cos(2 * math.pi * k / 48), 2 / 7) * (cab_l + 0.06) / 2, sill + 0.01, cz_c + pw(math.sin(2 * math.pi * k / 48), 2 / 7) * cl / 2] for k in range(49)]
    G["arco"].add(tubo(borda, 0.034 if pid == "T25" else 0.016, 10, fechado=True))
    if arcos and pid != "T25":
        za = arcos[0]
        tt = (za - cz_c) / (cl / 2)
        esc = (1 - abs(tt) ** 2.3) ** (1 / 2.3)
        for s in (-1, 0, 1):
            a = math.pi / 2 - s * 0.55
            mx = math.cos(a) * (cab_l + 0.05) / 2 * esc * 0.92
            my = sill + math.sin(a) * ch * esc * 0.92 - 0.03
            G["hud"].add(caixa(0.1, 0.035, 0.01, 0.004).girar("y", -s * 20).mover(px + mx, my, za + 0.04))
            G["espelho"].add(caixa(0.092, 0.028, 0.002).girar("y", -s * 20).mover(px + mx, my, za + 0.046))

    # GRAVAR -----------------------------------------------------------------------------------
    materiais = {
        "placa": ("PlacasComando", PAINEL, "SmoothPlastic", 0.2, 0.7),
        "cromo": ("Interruptores", CROMO, "Metal", 0.9, 0.3),
        "preto": ("Botoes", PRETO, "SmoothPlastic", 0.0, 0.6),
        "legenda": ("Legendas", LEGENDA, "SmoothPlastic", 0.0, 0.6),
        "vermelho": ("Guardas", VERMELHO, "SmoothPlastic", 0.0, 0.5),
        "moldura": ("Molduras", PAINEL_ESCURO, "SmoothPlastic", 0.1, 0.6),
        "painel": ("PainelPrincipal", PAINEL, "SmoothPlastic", 0.1, 0.75),
        "parasol": ("ParaSol", (24, 24, 25), "Fabric", 0.0, 1.0),
        "assento_estr": ("AssentoEstrutura", (52, 56, 50), "SmoothPlastic", 0.2, 0.6),
        "assento_metal": ("AssentoMetal", METAL, "Metal", 0.8, 0.4),
        "assento_tecido": ("AssentoTecido", VERDE_ASSENTO, "Fabric", 0.0, 1.0),
        "assento_costura": ("AssentoCostura", (46, 52, 40), "Fabric", 0.0, 1.0),
        "assento_verm": ("AssentoAlerta", VERMELHO, "SmoothPlastic", 0.0, 0.6),
        "cinto": ("Cintos", CINTO, "Fabric", 0.0, 1.0),
        "amarelo": ("PunhoEjecao", AMARELO, "SmoothPlastic", 0.0, 0.5),
        "fio": ("Chicotes", FIO, "Rubber", 0.0, 0.8),
        "estrutura": ("Banheira", INTERIOR, "SmoothPlastic", 0.1, 0.85),
        "console": ("Consoles", (48, 51, 55), "Metal", 0.3, 0.6),
        "pedal": ("Pedais", METAL, "DiamondPlate", 0.6, 0.5),
        "hud": ("HUDEstrutura", (36, 38, 40), "Metal", 0.5, 0.5),
        "espelho": ("Espelhos", (200, 210, 215), "Foil", 1.0, 0.05),
        "arco": ("ArcosCanopi", (40, 42, 45), "SmoothPlastic", 0.4, 0.6),
        "borracha": ("Acolchoados", (46, 48, 52), "Fabric", 0.0, 0.9),
    }
    if pid == "T25":
        claro = {
            "placa": ((70, 72, 74), "SmoothPlastic"), "painel": ((196, 198, 194), "SmoothPlastic"),
            "moldura": ((34, 36, 38), "SmoothPlastic"), "console": ((168, 172, 170), "SmoothPlastic"),
            "estrutura": ((184, 188, 184), "SmoothPlastic"), "assento_tecido": ((38, 40, 44), "Fabric"),
            "assento_costura": ((30, 32, 36), "Fabric"), "assento_estr": ((150, 154, 150), "SmoothPlastic"),
            "cinto": ((78, 94, 124), "Fabric"), "arco": ((200, 202, 198), "SmoothPlastic"), "legenda": ((236, 236, 228), "SmoothPlastic"),
        }
        for chave, (cor2, mat2) in claro.items():
            n0, _, _, me, ru = materiais[chave]
            materiais[chave] = (n0, cor2, mat2, me, ru)
    for chave, (nome, cor, mat, metal, rug) in materiais.items():
        m = G[chave].malha()
        if len(m.f) == 0:
            continue
        for i, pedaco in enumerate(dividir(m)):
            cena.adicionar(nome if i == 0 else "%s%d" % (nome, i + 1), pedaco, cor, mat, metal=metal, rug=rug)
    if manche2 is not None:
        cena.adicionar("ManchePassageiro", manche2[0], (26, 26, 27), "SmoothPlastic", rug=0.5)
        cena.adicionar("ManchePassageiroBotoes", manche2[1], (60, 62, 64), "SmoothPlastic", rug=0.5)
    cena.adicionar("Manche", haste, (26, 26, 27), "SmoothPlastic", rug=0.5)
    cena.adicionar("MancheBotoes", botoes, (60, 62, 64), "SmoothPlastic", rug=0.5)
    cena.adicionar("Manete", alav, (28, 28, 30), "SmoothPlastic", rug=0.6)
    cena.ancoras()
    if spec.get("helice"):
        hz, hy, _, _ = spec["helice"]
        layout["Helice"] = {"Pivo": [0, hy, hz]}
    layout["Rodas"] = True
    return cena, layout


def lua_valor(v, nivel=1):
    tab = "\t" * nivel
    if isinstance(v, dict):
        itens = []
        for k in sorted(v.keys()):
            itens.append("%s%s = %s" % (tab, k, lua_valor(v[k], nivel + 1)))
        return "{\n" + ",\n".join(itens) + "\n" + "\t" * (nivel - 1) + "}"
    if isinstance(v, (list, tuple)):
        if all(isinstance(x, (int, float)) for x in v):
            return "{ " + ", ".join(("%.4f" % x).rstrip("0").rstrip(".") if isinstance(x, float) else str(x) for x in v) + " }"
        return "{\n" + ",\n".join(tab + lua_valor(x, nivel + 1) for x in v) + "\n" + "\t" * (nivel - 1) + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return ("%.4f" % v).rstrip("0").rstrip(".")
    return '"%s"' % v


def gerar_layout(layouts, caminho):
    with open(caminho, "w") as fh:
        fh.write("-- Gerado por ferramentas/malhas/cabines.py. Nao edite a mao.\n")
        fh.write("-- Posicoes em metros no referencial da aeronave (nariz para -Z). R em graus (ordem do CFrame.Angles).\n")
        fh.write("return " + lua_valor(layouts) + "\n")


ITENS = []
for _spec in aeronaves.TODAS:
    ITENS.append(("Sim_" + _spec["id"], (lambda s=_spec: construir(s)[0]), {"Unidade": "metro"}))


if __name__ == "__main__":
    import sys
    raiz = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    layouts = {}
    for spec in aeronaves.TODAS:
        if len(sys.argv) > 1 and sys.argv[1] != spec["id"]:
            continue
        cena, lay = construir(spec)
        layouts[spec["id"]] = lay
        cena.salvar_glb(os.path.join(raiz, "malhas", "Sim_%s.glb" % spec["id"]))
        print("Sim_%s: %d triangulos, %d nos" % (spec["id"], cena.triangulos(), len(cena.pecas)))
    if len(sys.argv) == 1:
        gerar_layout(layouts, os.path.join(raiz, "src", "ReplicatedStorage", "FAB", "CabineLayout.lua"))
