"""
FAB - modelos 3D das aeronaves (metros, nariz para -Z, Y para cima, origem no CG).

Cada aeronave gera: fuselagem (com abertura da cabine), interior da cabine (banheira,
assento ejetavel, painel, para-sol, consoles e pedais), canopi de vidro com arcos,
asas, empenagem, motor (helice com spinner ou bocal de jato com entradas de ar),
trem de pouso, marcas (faixas e cocares da FAB) e, nos cacas, misseis nas pontas das asas.

As posicoes do olho do piloto e do trem seguem src/ReplicatedStorage/FAB/Aeronaves.lua.
"""
import math

import numpy as np

from malha import Cena, asa, caixa, cilindro, extrusao, loft, revolucao, superelipsoide, tubo

BRANCO = (236, 236, 232)
CINZA_CLARO = (176, 182, 186)
CINZA_MEDIO = (128, 136, 142)
CINZA_GRIPEN = (118, 124, 130)
VERDE_A29 = (92, 101, 88)
AZUL_FAB = (24, 52, 110)
VERMELHO = (190, 30, 34)
PRETO = (22, 22, 24)
GRAFITE = (48, 50, 54)
INTERIOR = (52, 56, 60)
BORRACHA = (20, 20, 20)
CROMO = (200, 204, 208)
VIDRO = (190, 215, 230)


def interpolar(estacoes, z):
    for a, b in zip(estacoes, estacoes[1:]):
        if a["z"] <= z <= b["z"]:
            t = (z - a["z"]) / max(b["z"] - a["z"], 1e-6)
            r = {}
            for k in ("larg", "alt", "cy", "n"):
                r[k] = a.get(k, 2.4) * (1 - t) + b.get(k, 2.4) * t
            r["z"] = z
            return r
    return dict(estacoes[-1])


def faixa_fuselagem(estacoes, z1, z2, fator=1.012, segs=40):
    secs = []
    for z in np.linspace(z1, z2, 4):
        e = interpolar(estacoes, z)
        e["larg"] *= fator
        e["alt"] *= fator
        secs.append(e)
    return loft(secs, segs, tampar=False)


def cocar(diametro, espessura=0.01):
    """Cocar da FAB: verde, amarelo, azul e estrela branca (disco no plano XZ)."""
    pecas = []
    for frac, cor, h in ((1.0, (0, 151, 57), 0), (0.72, (254, 221, 0), 1), (0.46, (0, 39, 118), 2)):
        d = cilindro(diametro * frac / 2, espessura, 32, "y").mover(0, h * 0.012, 0)
        pecas.append((d, cor))
    pts = []
    for k in range(10):
        r = diametro * (0.2 if k % 2 == 0 else 0.08)
        a = math.pi / 2 + k * math.pi / 5
        pts.append([r * math.cos(a), r * math.sin(a)])
    estrela = extrusao(pts, espessura).girar("x", 90).mover(0, 0.036, 0)
    pecas.append((estrela, (250, 250, 250)))
    return pecas


def helice(n_pas, diametro, corda=0.17):
    pas = None
    for k in range(n_pas):
        estacoes = []
        for r, c, tw in ((0.16, corda * 0.9, 38), (0.45 * diametro / 2, corda * 1.15, 24), (0.8 * diametro / 2, corda, 14), (diametro / 2, corda * 0.55, 9)):
            estacoes.append({"x": r, "z_ba": -c * 0.3, "corda": c, "y": 0, "torcao": tw, "esp": 0.08})
        pa = asa(estacoes, n=10)
        # a pa fica no plano XY girando em torno de Z
        pa = pa.girar("x", 90).girar("z", k * 360 / n_pas)
        pas = pa if pas is None else pas + pa
    return pas


def missil(comprimento=2.9, diametro=0.127):
    corpo = revolucao([(0, -comprimento / 2), (diametro * 0.35, -comprimento / 2 + 0.12), (diametro / 2, -comprimento / 2 + 0.3),
                       (diametro / 2, comprimento / 2), (diametro * 0.3, comprimento / 2 + 0.02)], 16)
    aletas = None
    for k in range(4):
        a = caixa(0.012, 0.32, 0.38).mover(0, diametro / 2 + 0.14, comprimento / 2 - 0.25).girar("z", 45 + k * 90)
        c = caixa(0.01, 0.16, 0.2).mover(0, diametro / 2 + 0.07, -comprimento / 2 + 0.55).girar("z", 45 + k * 90)
        aletas = (a + c) if aletas is None else aletas + a + c
    return corpo, aletas


def trem(cena, rodas, prefixo="Trem"):
    """rodas: lista de (x, y_contato, z, raio, largura, y_fixacao)"""
    estrutura, pneus = None, None
    for x, yc, z, r, w, yfix in rodas:
        centro_y = yc + r
        perna = tubo([[x, yfix, z], [x, centro_y + r * 0.2, z + 0.05]], 0.045 if r < 0.3 else 0.07, 10)
        pneu = revolucao([(r * 0.55, -w / 2), (r * 0.95, -w / 2), (r, -w * 0.3), (r, w * 0.3), (r * 0.95, w / 2), (r * 0.55, w / 2)], 20).girar("y", 90).mover(x, centro_y, z)
        roda = cilindro(r * 0.56, w * 0.9, 16, "x").mover(x, centro_y, z)
        estrutura = (perna + roda) if estrutura is None else estrutura + perna + roda
        pneus = pneu if pneus is None else pneus + pneu
    cena.adicionar(prefixo, estrutura, CINZA_CLARO, "Metal", metal=0.7, rug=0.4)
    cena.adicionar(prefixo + "Pneus", pneus, BORRACHA, "Rubber")


def assento_ejetavel(x, y_piso, z):
    """Assento ejetavel (estilo Martin-Baker): almofada, encosto, caixa de cabeca e punho."""
    almofada = caixa(0.46, 0.12, 0.46, 0.03).mover(x, y_piso + 0.42, z)
    encosto = caixa(0.48, 0.78, 0.16, 0.03).girar("x", -12).mover(x, y_piso + 0.86, z + 0.3)
    cabeca = caixa(0.44, 0.34, 0.24, 0.03).girar("x", -12).mover(x, y_piso + 1.35, z + 0.42)
    laterais = None
    for s in (-1, 1):
        lat = caixa(0.05, 0.9, 0.5).girar("x", -12).mover(x + s * 0.27, y_piso + 0.75, z + 0.18)
        laterais = lat if laterais is None else laterais + lat
    base = caixa(0.5, 0.3, 0.5).mover(x, y_piso + 0.2, z)
    estofado = almofada + encosto
    estrutura = cabeca + laterais + base
    punho = tubo([[x - 0.06, y_piso + 0.48, z - 0.24], [x - 0.06, y_piso + 0.58, z - 0.28], [x + 0.06, y_piso + 0.58, z - 0.28], [x + 0.06, y_piso + 0.48, z - 0.24]], 0.012, 8)
    return estofado, estrutura, punho


def construir(spec):
    cena = Cena()
    est = spec["estacoes"]
    ox, oy, oz = spec["olho"]
    sill = oy - 0.42
    cab_l = spec["cab_larg"]
    cz1, cz2 = spec["cab_z"]
    cor = spec["cor"]
    segs = 40

    # fuselagem com a abertura da cabine
    fus = loft(est, segs)

    def manter(c):
        dentro = (np.abs(c[:, 0]) < cab_l / 2 + 0.02) & (c[:, 2] > cz1) & (c[:, 2] < cz2) & (c[:, 1] > sill - 0.05)
        return ~dentro
    fus = fus.filtrar_faces(manter)
    cena.adicionar("Fuselagem", fus, cor, spec.get("material", "SmoothPlastic"), metal=0.2, rug=0.45)

    # faixas e cocares
    for z1, z2, c in spec.get("faixas", []):
        cena.adicionar("Faixa", faixa_fuselagem(est, z1, z2), c, "SmoothPlastic")

    # interior da cabine (faces para dentro)
    piso = sill - spec.get("prof_cabine", 0.95)
    comp = cz2 - cz1
    banheira = caixa(cab_l - 0.02, sill - piso, comp - 0.04).inverter().mover(0, (sill + piso) / 2, (cz1 + cz2) / 2)
    banheira = banheira.filtrar_faces(lambda c: c[:, 1] < sill - 0.01)
    cena.adicionar("InteriorCabine", banheira, INTERIOR, "SmoothPlastic", rug=0.9)
    trilhos = tubo([[-cab_l / 2, sill, cz1], [-cab_l / 2, sill, cz2]], 0.03, 8) + tubo([[cab_l / 2, sill, cz1], [cab_l / 2, sill, cz2]], 0.03, 8)
    cena.adicionar("Soleiras", trilhos, PRETO, "SmoothPlastic")
    assentos = spec.get("assentos", [(ox, oz + 0.35)])
    estof, estr, punhos = None, None, None
    for ax, az in assentos:
        e1, e2, e3 = assento_ejetavel(ax, piso, az)
        estof = e1 if estof is None else estof + e1
        estr = e2 if estr is None else estr + e2
        punhos = e3 if punhos is None else punhos + e3
    cena.adicionar("AssentoEstofado", estof, (64, 72, 58), "Fabric", rug=1)
    cena.adicionar("AssentoEstrutura", estr, GRAFITE, "Metal", metal=0.5, rug=0.5)
    cena.adicionar("PunhoEjecao", punhos, (240, 200, 20), "SmoothPlastic")
    # painel, para-sol e consoles
    largura_painel = spec.get("larg_painel", cab_l * 0.92)
    painel_z = oz - 0.72 + 0.03
    perfil = [[-largura_painel / 2, -0.2], [largura_painel / 2, -0.2], [largura_painel / 2, 0.16], [largura_painel * 0.3, 0.2], [-largura_painel * 0.3, 0.2], [-largura_painel / 2, 0.16]]
    painel = extrusao(perfil, 0.06).girar("x", -8).mover(spec.get("painel_x", 0), oy - 0.3, painel_z)
    parasol = superelipsoide(largura_painel + 0.06, 0.12, 0.34, n=3, segs_u=24, segs_v=6, so_cima=True).mover(spec.get("painel_x", 0), oy - 0.14, painel_z - 0.12)
    cena.adicionar("Painel", painel, (30, 32, 34), "SmoothPlastic", rug=0.8)
    cena.adicionar("ParaSol", parasol, (28, 28, 28), "Fabric", rug=1)
    consoles = None
    for s in (-1, 1):
        c = caixa(0.16, 0.2, comp * 0.55, 0.02).mover(s * (cab_l / 2 - 0.1), sill - 0.18, (cz1 + cz2) / 2 + 0.1)
        consoles = c if consoles is None else consoles + c
    pedais = None
    for ax, az in assentos:
        for s in (-1, 1):
            p = caixa(0.09, 0.2, 0.04).girar("x", 25).mover(ax + s * 0.13, piso + 0.18, painel_z - 0.12)
            pedais = p if pedais is None else pedais + p
    cena.adicionar("Consoles", consoles + pedais, (40, 42, 46), "Metal", metal=0.3)

    # canopi
    cz_c = spec["canopi_z"]
    cl = spec["canopi_comp"]
    ch = spec["canopi_alt"]
    dome = superelipsoide(cab_l + 0.05, ch * 2, cl, n=spec.get("canopi_n", 2.3), segs_u=40, segs_v=12, so_cima=True)
    dome = dome.filtrar_faces(lambda c: c[:, 1] > 0.005).mover(0, sill, cz_c)
    cena.adicionar("Canopi", dome, (150, 190, 205), "Glass", transparencia=0.55)
    # arcos do canopi (bordas e montantes)
    arcos = None
    for zr in spec.get("arcos", []):
        t = (zr - cz_c) / (cl / 2)
        if abs(t) >= 1:
            continue
        pts = []
        for k in range(17):
            a = math.pi * k / 16
            fx = math.cos(a)
            fy = math.sin(a)
            escala = (1 - abs(t) ** 2.3) ** (1 / 2.3)
            pts.append([fx * (cab_l + 0.05) / 2 * escala, sill + fy * ch * escala, zr])
        arco = tubo(pts, 0.025, 8)
        arcos = arco if arcos is None else arcos + arco
    borda = []
    for k in range(41):
        a = 2 * math.pi * k / 40
        borda.append([math.cos(a) * (cab_l + 0.06) / 2, sill + 0.01, cz_c + math.sin(a) * cl / 2])
    arcos = tubo(borda, 0.03, 8, fechado=True) if arcos is None else arcos + tubo(borda, 0.03, 8, fechado=True)
    cena.adicionar("ArcosCanopi", arcos, PRETO, "SmoothPlastic")

    # asas
    for lado in (1, -1):
        w = spec["asa"]
        estacoes = []
        for k, frac in enumerate(np.linspace(0, 1, 5)):
            x = w["raiz_x"] + frac * (w["semi"] - w["raiz_x"])
            corda = w["corda_raiz"] * (1 - frac) + w["corda_ponta"] * frac
            zba = w["z_ba"] + (x - w["raiz_x"]) * math.tan(math.radians(w["enfle"]))
            y = w["y"] + (x - w["raiz_x"]) * math.tan(math.radians(w.get("diedro", 0)))
            estacoes.append({"x": x, "z_ba": zba, "corda": corda, "y": y, "torcao": -w.get("torcao", 0) * frac,
                             "esp": w["esp_raiz"] * (1 - frac) + w["esp_ponta"] * frac})
        cena.adicionar("Asa", asa(estacoes, n=18, curvatura=w.get("curv", 0.0), lado=lado), spec.get("cor_asa", cor), spec.get("material", "SmoothPlastic"), metal=0.2, rug=0.45)
        # cocar na asa
        if spec.get("cocar_asa"):
            dx, dz, d = spec["cocar_asa"]
            ytopo = w["y"] + (dx - w["raiz_x"]) * math.tan(math.radians(w.get("diedro", 0))) + 0.5 * w["esp_ponta"] * w["corda_ponta"] + 0.012
            for peca, c in cocar(d):
                inclinacao = -lado * w.get("diedro", 0)
                cena.adicionar("Cocar", peca.girar("z", inclinacao).mover(lado * dx, ytopo, dz), c, "SmoothPlastic")
        # luz de navegacao na ponta
        ponta = estacoes[-1]
        luz = superelipsoide(0.08, 0.06, 0.16, n=2).mover(lado * (ponta["x"] + 0.02), ponta["y"], ponta["z_ba"] + 0.05)
        cena.adicionar("LuzNavegacao", luz, (40, 255, 80) if lado > 0 else (255, 40, 30), "Neon")

    # empenagem horizontal
    for lado in ((1, -1) if spec.get("ht") else ()):
        h = spec["ht"]
        estacoes = [{"x": h["raiz_x"], "z_ba": h["z_ba"], "corda": h["corda_raiz"], "y": h["y"], "esp": 0.09},
                    {"x": h["semi"], "z_ba": h["z_ba"] + (h["semi"] - h["raiz_x"]) * math.tan(math.radians(h["enfle"])), "corda": h["corda_ponta"],
                     "y": h["y"] + (h["semi"] - h["raiz_x"]) * math.tan(math.radians(h.get("diedro", 0))), "esp": 0.08}]
        cena.adicionar("Estabilizador", asa(estacoes, n=14, lado=lado), spec.get("cor_asa", cor), spec.get("material", "SmoothPlastic"))
    # deriva
    v = spec["vt"]
    estacoes = [{"x": 0, "z_ba": v["z_ba"], "corda": v["corda_raiz"], "y": 0, "esp": 0.1},
                {"x": v["altura"], "z_ba": v["z_ba"] + v["altura"] * math.tan(math.radians(v["enfle"])), "corda": v["corda_ponta"], "y": 0, "esp": 0.08}]
    deriva = asa(estacoes, n=14, lado=1).girar("z", 90).mover(0, v["y"], 0)
    cena.adicionar("Deriva", deriva, cor, spec.get("material", "SmoothPlastic"))
    if spec.get("faixa_deriva"):
        zf, hf, cf = spec["faixa_deriva"]
        cena.adicionar("BandeiraDeriva", caixa(0.11, hf, 0.5).mover(0, v["y"] + v["altura"] * 0.6, zf), cf, "SmoothPlastic")

    # motor
    if spec.get("helice"):
        hz, hy, npas, diam = spec["helice"]
        perfil_spinner = [(0, hz - spec.get("spinner_comp", 0.45)), (0.09, hz - spec.get("spinner_comp", 0.45) * 0.8), (0.17, hz - spec.get("spinner_comp", 0.45) * 0.4),
                          (spec.get("spinner_raio", 0.2), hz + 0.05), (spec.get("spinner_raio", 0.2) * 0.98, hz + 0.12)]
        cena.adicionar("Spinner", revolucao(perfil_spinner, 24).mover(0, hy, 0), spec.get("cor_spinner", PRETO), "SmoothPlastic", metal=0.3)
        cena.adicionar("Helice", helice(npas, diam).mover(0, hy, hz + 0.02), PRETO, "SmoothPlastic", rug=0.7)
        if spec.get("escapes"):
            esc = None
            for x, y, z in spec["escapes"]:
                e = cilindro(0.06, 0.25, 12, "x").mover(x, y, z)
                esc = e if esc is None else esc + e
            cena.adicionar("Escapamentos", esc, (70, 60, 52), "Metal", metal=0.8)
    if spec.get("bocais"):
        bocais, internos = None, None
        for x, y, z, r in spec["bocais"]:
            b = revolucao([(r * 1.02, z - 0.6), (r, z), (r * 0.92, z + 0.12), (r * 0.82, z + 0.12)], 24, fechar_pontas=False).mover(x, y, 0)
            i = revolucao([(r * 0.82, z + 0.1), (r * 0.6, z - 0.4), (0.0, z - 0.45)], 24, fechar_pontas=False).mover(x, y, 0)
            bocais = b if bocais is None else bocais + b
            internos = i if internos is None else internos + i
        cena.adicionar("Bocal", bocais, (110, 100, 92), "Metal", metal=0.9, rug=0.35)
        cena.adicionar("BocalInterno", internos, (30, 26, 24), "Metal", metal=0.6)
    if spec.get("entradas"):
        ent = None
        bocas = None
        for s in (-1, 1):
            e = spec["entradas"]
            duto = loft([{"z": e["z1"], "larg": e["larg"] * 0.95, "alt": e["alt"], "cy": e["y"], "n": 3.2, "cx": s * e["x"]},
                         {"z": e["z1"] + 0.3, "larg": e["larg"], "alt": e["alt"], "cy": e["y"], "n": 3.2, "cx": s * e["x"]},
                         {"z": e["z2"], "larg": e["larg"] * 0.4, "alt": e["alt"] * 0.6, "cy": e["y"], "n": 3.2, "cx": s * (e["x"] - 0.15)}], 24)
            boca = loft([{"z": e["z1"] - 0.005, "larg": e["larg"] * 0.85, "alt": e["alt"] * 0.85, "cy": e["y"], "n": 3.2, "cx": s * e["x"]},
                         {"z": e["z1"] + 0.004, "larg": e["larg"] * 0.85, "alt": e["alt"] * 0.85, "cy": e["y"], "n": 3.2, "cx": s * e["x"]}], 24)
            ent = duto if ent is None else ent + duto
            bocas = boca if bocas is None else bocas + boca
        cena.adicionar("EntradasAr", ent, cor, spec.get("material", "SmoothPlastic"))
        cena.adicionar("BocasEntrada", bocas, PRETO, "SmoothPlastic")
    if spec.get("canards"):
        c = spec["canards"]
        for lado in (1, -1):
            estacoes = [{"x": c["raiz_x"], "z_ba": c["z_ba"], "corda": c["corda_raiz"], "y": c["y"], "esp": 0.05},
                        {"x": c["semi"], "z_ba": c["z_ba"] + (c["semi"] - c["raiz_x"]) * math.tan(math.radians(c["enfle"])), "corda": c["corda_ponta"], "y": c["y"], "esp": 0.04}]
            cena.adicionar("Canard", asa(estacoes, n=12, lado=lado), cor, spec.get("material", "SmoothPlastic"))
    if spec.get("misseis"):
        corpos, aletas = None, None
        for x, y, z in spec["misseis"]:
            m1, m2 = missil()
            corpos = m1.mover(x, y, z) if corpos is None else corpos + m1.mover(x, y, z)
            aletas = m2.mover(x, y, z) if aletas is None else aletas + m2.mover(x, y, z)
        cena.adicionar("Misseis", corpos, (220, 220, 214), "SmoothPlastic")
        cena.adicionar("AletasMisseis", aletas, (200, 200, 196), "SmoothPlastic")
    # detalhes: tubo de pitot e antenas
    det = None
    for p in spec.get("pitot", []):
        t = tubo([p[0], p[1]], 0.015, 6)
        det = t if det is None else det + t
    for x, y, z, h in spec.get("antenas", []):
        a = caixa(0.02, h, 0.12).mover(x, y + h / 2, z)
        det = a if det is None else det + a
    if det is not None:
        cena.adicionar("Detalhes", det, GRAFITE, "Metal", metal=0.6)

    trem(cena, spec["rodas"])
    cena.ancoras(1.0)
    return cena


T25 = {
    "id": "T25", "cor": BRANCO,
    "olho": (-0.34, 0.78, -0.35), "cab_larg": 1.22, "cab_z": (-1.15, 0.95), "prof_cabine": 1.0,
    "assentos": [(-0.34, 0.0), (0.34, 0.0)], "larg_painel": 1.1,
    "canopi_z": -0.15, "canopi_comp": 2.3, "canopi_alt": 0.62, "arcos": [-0.95, 0.75],
    "estacoes": [
        {"z": -3.45, "larg": 0.82, "alt": 0.78, "cy": -0.13, "n": 2.6},
        {"z": -3.2, "larg": 1.02, "alt": 0.94, "cy": -0.10, "n": 2.6},
        {"z": -2.4, "larg": 1.14, "alt": 1.05, "cy": -0.07, "n": 2.6},
        {"z": -1.6, "larg": 1.22, "alt": 1.18, "cy": -0.06, "n": 2.7},
        {"z": -1.2, "larg": 1.26, "alt": 1.28, "cy": -0.03, "n": 2.8},
        {"z": 0.95, "larg": 1.26, "alt": 1.26, "cy": -0.27, "n": 2.8},
        {"z": 1.6, "larg": 1.08, "alt": 1.12, "cy": -0.17, "n": 2.7},
        {"z": 2.6, "larg": 0.82, "alt": 0.88, "cy": -0.05, "n": 2.6},
        {"z": 3.7, "larg": 0.52, "alt": 0.62, "cy": 0.06, "n": 2.5},
        {"z": 4.85, "larg": 0.18, "alt": 0.3, "cy": 0.15, "n": 2.3},
    ],
    "faixas": [], "cor_asa": (232, 102, 26), "cor_spinner": (226, 78, 22),
    "asa": {"raiz_x": 0.5, "semi": 5.5, "corda_raiz": 1.95, "corda_ponta": 1.25, "z_ba": -0.78, "enfle": 2.5, "y": -0.6, "diedro": 5,
            "esp_raiz": 0.15, "esp_ponta": 0.12, "torcao": 2, "curv": 0.02},
    "cocar_asa": (4.4, -0.35, 0.8),
    "ht": {"raiz_x": 0.15, "semi": 1.9, "corda_raiz": 1.0, "corda_ponta": 0.62, "z_ba": 3.85, "enfle": 8, "y": 0.12},
    "vt": {"altura": 1.35, "corda_raiz": 1.3, "corda_ponta": 0.7, "z_ba": 3.55, "enfle": 32, "y": 0.2},
    "faixa_deriva": (4.25, 0.6, (0, 151, 57)),
    "helice": (-3.55, -0.12, 2, 2.1), "spinner_comp": 0.42, "spinner_raio": 0.2,
    "escapes": [(0.45, -0.42, -2.4), (-0.45, -0.42, -2.4)],
    "pitot": [([5.0, -0.5, -0.75], [5.0, -0.5, -1.15])],
    "antenas": [(0, 0.55, 1.6, 0.25)],
    "rodas": [(0, -1.45, -1.9, 0.2, 0.13, -0.45), (-1.6, -1.45, 0.35, 0.26, 0.15, -0.7), (1.6, -1.45, 0.35, 0.26, 0.15, -0.7)],
}

T27 = {
    "id": "T27", "cor": BRANCO,
    "olho": (0, 0.95, -0.9), "cab_larg": 0.82, "cab_z": (-1.75, 1.3), "prof_cabine": 1.05,
    "assentos": [(0, -0.55), (0, 0.95)], "larg_painel": 0.74,
    "canopi_z": -0.22, "canopi_comp": 3.3, "canopi_alt": 0.72, "arcos": [-1.5, 0.35, 1.15], "canopi_n": 2.2,
    "estacoes": [
        {"z": -4.75, "larg": 0.6, "alt": 0.62, "cy": -0.08, "n": 2.4},
        {"z": -4.4, "larg": 0.9, "alt": 0.92, "cy": -0.1, "n": 2.5},
        {"z": -3.4, "larg": 1.02, "alt": 1.04, "cy": -0.08, "n": 2.5},
        {"z": -2.3, "larg": 1.0, "alt": 1.12, "cy": 0.0, "n": 2.6},
        {"z": -1.8, "larg": 0.98, "alt": 1.32, "cy": 0.0, "n": 2.6},
        {"z": 1.3, "larg": 0.98, "alt": 1.3, "cy": -0.12, "n": 2.6},
        {"z": 2.2, "larg": 0.86, "alt": 1.14, "cy": -0.05, "n": 2.5},
        {"z": 3.4, "larg": 0.6, "alt": 0.86, "cy": 0.05, "n": 2.4},
        {"z": 4.5, "larg": 0.36, "alt": 0.6, "cy": 0.15, "n": 2.3},
        {"z": 5.25, "larg": 0.14, "alt": 0.3, "cy": 0.22, "n": 2.2},
    ],
    "faixas": [(-4.1, -3.9, VERMELHO), (-3.85, -3.75, AZUL_FAB), (2.6, 2.9, VERMELHO)],
    "asa": {"raiz_x": 0.45, "semi": 5.57, "corda_raiz": 2.3, "corda_ponta": 1.15, "z_ba": -0.9, "enfle": 4, "y": -0.62, "diedro": 5.5,
            "esp_raiz": 0.15, "esp_ponta": 0.12, "torcao": 2, "curv": 0.02},
    "cocar_asa": (4.5, -0.55, 0.8),
    "ht": {"raiz_x": 0.12, "semi": 2.25, "corda_raiz": 1.1, "corda_ponta": 0.6, "z_ba": 4.05, "enfle": 12, "y": 0.2},
    "vt": {"altura": 1.6, "corda_raiz": 1.5, "corda_ponta": 0.75, "z_ba": 3.7, "enfle": 38, "y": 0.35},
    "faixa_deriva": (4.6, 0.7, (0, 151, 57)),
    "helice": (-4.85, -0.08, 3, 2.36), "spinner_comp": 0.5, "spinner_raio": 0.2,
    "escapes": [(0.48, -0.15, -3.6), (-0.48, -0.15, -3.6)],
    "pitot": [([5.1, -0.55, -0.9], [5.1, -0.55, -1.35])],
    "antenas": [(0, 0.6, 2.4, 0.3)],
    "rodas": [(0, -1.6, -2.4, 0.2, 0.13, -0.55), (-1.85, -1.6, 0.35, 0.28, 0.16, -0.75), (1.85, -1.6, 0.35, 0.28, 0.16, -0.75)],
}

A29 = dict(T27)
A29.update({
    "id": "A29", "cor": VERDE_A29,
    "olho": (0, 1.0, -1.1), "cab_z": (-1.95, 1.15), "assentos": [(0, -0.75), (0, 0.75)],
    "canopi_z": -0.42, "canopi_comp": 3.3, "arcos": [-1.7, 0.15, 0.95],
    "estacoes": [
        {"z": -5.6, "larg": 0.6, "alt": 0.62, "cy": -0.06, "n": 2.4},
        {"z": -5.2, "larg": 0.92, "alt": 0.94, "cy": -0.08, "n": 2.5},
        {"z": -3.8, "larg": 1.04, "alt": 1.08, "cy": -0.06, "n": 2.5},
        {"z": -2.5, "larg": 1.02, "alt": 1.16, "cy": 0.02, "n": 2.6},
        {"z": -2.0, "larg": 0.99, "alt": 1.36, "cy": 0.02, "n": 2.6},
        {"z": 1.15, "larg": 0.99, "alt": 1.32, "cy": -0.1, "n": 2.6},
        {"z": 2.2, "larg": 0.86, "alt": 1.16, "cy": -0.04, "n": 2.5},
        {"z": 3.6, "larg": 0.6, "alt": 0.88, "cy": 0.06, "n": 2.4},
        {"z": 4.9, "larg": 0.34, "alt": 0.6, "cy": 0.16, "n": 2.3},
        {"z": 5.7, "larg": 0.14, "alt": 0.3, "cy": 0.23, "n": 2.2},
    ],
    "faixas": [],
    "faixa_deriva": (5.0, 0.7, (0, 151, 57)),
    "ht": {"raiz_x": 0.12, "semi": 2.3, "corda_raiz": 1.15, "corda_ponta": 0.62, "z_ba": 4.45, "enfle": 12, "y": 0.22},
    "vt": {"altura": 1.7, "corda_raiz": 1.6, "corda_ponta": 0.8, "z_ba": 4.05, "enfle": 38, "y": 0.38},
    "helice": (-5.7, -0.07, 5, 2.38), "spinner_comp": 0.55, "spinner_raio": 0.21,
    "escapes": [(0.5, -0.12, -4.4), (-0.5, -0.12, -4.4)],
    "rodas": [(0, -1.65, -2.5, 0.21, 0.13, -0.55), (-1.95, -1.65, 0.4, 0.3, 0.17, -0.75), (1.95, -1.65, 0.4, 0.3, 0.17, -0.75)],
})

F5 = {
    "id": "F5", "cor": CINZA_MEDIO, "material": "SmoothPlastic",
    "olho": (0, 0.95, -3.2), "cab_larg": 0.78, "cab_z": (-3.95, -2.35), "prof_cabine": 1.05,
    "assentos": [(0, -2.85)], "larg_painel": 0.72,
    "canopi_z": -3.05, "canopi_comp": 2.1, "canopi_alt": 0.62, "arcos": [-3.85], "canopi_n": 2.2,
    "estacoes": [
        {"z": -7.6, "larg": 0.02, "alt": 0.02, "cy": -0.18, "n": 2.0},
        {"z": -7.0, "larg": 0.28, "alt": 0.22, "cy": -0.17, "n": 2.0},
        {"z": -6.0, "larg": 0.62, "alt": 0.5, "cy": -0.12, "n": 2.0},
        {"z": -4.9, "larg": 0.8, "alt": 0.78, "cy": -0.04, "n": 2.2},
        {"z": -4.0, "larg": 0.88, "alt": 1.06, "cy": 0.0, "n": 2.4},
        {"z": -2.3, "larg": 0.94, "alt": 1.08, "cy": -0.08, "n": 2.6},
        {"z": -1.2, "larg": 1.5, "alt": 1.15, "cy": -0.1, "n": 3.0},
        {"z": 1.0, "larg": 1.62, "alt": 1.12, "cy": -0.08, "n": 3.2},
        {"z": 3.5, "larg": 1.5, "alt": 1.0, "cy": -0.05, "n": 3.2},
        {"z": 5.6, "larg": 1.36, "alt": 0.82, "cy": -0.02, "n": 3.0},
        {"z": 6.3, "larg": 1.3, "alt": 0.7, "cy": -0.02, "n": 2.8},
    ],
    "asa": {"raiz_x": 0.7, "semi": 4.06, "corda_raiz": 3.4, "corda_ponta": 0.75, "z_ba": -0.75, "enfle": 32, "y": -0.25, "diedro": 0,
            "esp_raiz": 0.048, "esp_ponta": 0.048},
    "cocar_asa": (2.9, 1.4, 0.55),
    "ht": {"raiz_x": 0.65, "semi": 2.15, "corda_raiz": 1.45, "corda_ponta": 0.55, "z_ba": 4.8, "enfle": 28, "y": -0.15, "diedro": -4},
    "vt": {"altura": 2.1, "corda_raiz": 2.6, "corda_ponta": 0.95, "z_ba": 3.0, "enfle": 42, "y": 0.45},
    "faixa_deriva": (5.0, 0.55, (0, 151, 57)),
    "bocais": [(-0.36, -0.05, 6.35, 0.3), (0.36, -0.05, 6.35, 0.3)],
    "entradas": {"z1": -2.05, "z2": 0.4, "larg": 0.42, "alt": 0.62, "y": -0.12, "x": 0.72},
    "misseis": [(4.13, -0.25, 0.7), (-4.13, -0.25, 0.7)],
    "pitot": [([0, -0.18, -7.6], [0, -0.18, -8.3])],
    "antenas": [(0, 0.45, -1.5, 0.22)],
    "rodas": [(0, -1.4, -4.5, 0.23, 0.15, -0.35), (-1.3, -1.4, 0.6, 0.3, 0.18, -0.5), (1.3, -1.4, 0.6, 0.3, 0.18, -0.5)],
}

F39 = {
    "id": "F39", "cor": CINZA_GRIPEN,
    "olho": (0, 1.0, -3.6), "cab_larg": 0.8, "cab_z": (-4.35, -2.75), "prof_cabine": 1.05,
    "assentos": [(0, -3.25)], "larg_painel": 0.74,
    "canopi_z": -3.45, "canopi_comp": 2.2, "canopi_alt": 0.66, "arcos": [-4.25], "canopi_n": 2.2,
    "estacoes": [
        {"z": -7.5, "larg": 0.04, "alt": 0.04, "cy": -0.2, "n": 2.0},
        {"z": -6.8, "larg": 0.42, "alt": 0.36, "cy": -0.18, "n": 2.1},
        {"z": -5.6, "larg": 0.8, "alt": 0.74, "cy": -0.1, "n": 2.3},
        {"z": -4.4, "larg": 0.92, "alt": 1.1, "cy": 0.0, "n": 2.5},
        {"z": -2.7, "larg": 1.0, "alt": 1.12, "cy": -0.08, "n": 2.6},
        {"z": -1.4, "larg": 1.9, "alt": 1.2, "cy": -0.12, "n": 3.0},
        {"z": 1.5, "larg": 1.95, "alt": 1.18, "cy": -0.08, "n": 3.2},
        {"z": 4.6, "larg": 1.3, "alt": 1.05, "cy": -0.02, "n": 3.0},
        {"z": 6.6, "larg": 1.0, "alt": 0.95, "cy": 0.0, "n": 2.6},
        {"z": 7.4, "larg": 0.95, "alt": 0.9, "cy": 0.0, "n": 2.4},
    ],
    "asa": {"raiz_x": 0.9, "semi": 4.3, "corda_raiz": 5.4, "corda_ponta": 0.9, "z_ba": 0.2, "enfle": 45, "y": -0.22, "diedro": -1,
            "esp_raiz": 0.045, "esp_ponta": 0.04},
    "cocar_asa": (3.0, 3.6, 0.6),
    "canards": {"raiz_x": 0.85, "semi": 2.2, "corda_raiz": 1.4, "corda_ponta": 0.55, "z_ba": -2.0, "enfle": 43, "y": 0.18},
    "ht": None,
    "vt": {"altura": 2.5, "corda_raiz": 3.2, "corda_ponta": 1.0, "z_ba": 3.4, "enfle": 48, "y": 0.5},
    "faixa_deriva": (5.6, 0.6, (0, 151, 57)),
    "bocais": [(0, 0.0, 7.45, 0.45)],
    "entradas": {"z1": -2.6, "z2": 0.8, "larg": 0.5, "alt": 0.72, "y": -0.05, "x": 0.82},
    "misseis": [(4.36, -0.27, 2.2), (-4.36, -0.27, 2.2)],
    "pitot": [([0, -0.2, -7.5], [0, -0.2, -8.2])],
    "antenas": [(0, 0.6, 0.5, 0.2)],
    "rodas": [(0, -1.55, -4.3, 0.23, 0.15, -0.4), (-1.2, -1.55, 0.5, 0.3, 0.18, -0.5), (1.2, -1.55, 0.5, 0.3, 0.18, -0.5)],
}

TODAS = [T25, T27, A29, F5, F39]
