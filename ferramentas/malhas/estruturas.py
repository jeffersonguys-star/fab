"""
FAB - malhas das estruturas do mapa e da maquina do simulador (unidade: studs).

- Capsula do simulador (carenagem arredondada, cupula de projecao, faixas, grades,
  modulo de projetores e vao da porta, com casca interna)
- Telhado em arco dos hangares e do centro de simulacao (com arcos estruturais e
  claraboias)
- Abrigo reforcado (HAS) de concreto
- Arvores (frondosa e palmeira)
"""
import math

import numpy as np

from malha import Cena, Malha, caixa, cilindro, grade, revolucao, superelipsoide, tampa, tubo

BRANCO = (238, 238, 236)
GRAFITE = (38, 40, 44)
AZUL = (24, 52, 110)
CINZA = (205, 206, 204)
METAL_TELHADO = (178, 182, 186)
ESTRUTURA = (70, 72, 76)
CONCRETO = (122, 126, 112)


def capsula():
    """Origem: centro da plataforma superior do simulador. Frente (cupula) para -Z."""
    c = Cena()
    cy, cz = 4.4, 0.5
    corpo = superelipsoide(9.2, 7.2, 9.6, n=5.5, segs_u=48, segs_v=20).mover(0, cy, cz + 0.2)
    cupula = superelipsoide(11.4, 10.0, 11.4, n=2.0, segs_u=48, segs_v=24).mover(0, cy + 0.4, cz - 3.0)
    cupula = cupula.filtrar_faces(lambda k: k[:, 2] < cz - 1.2)
    # vao da porta traseira
    def sem_porta(k):
        return ~((np.abs(k[:, 0]) < 1.55) & (k[:, 1] > cy - 3.0) & (k[:, 1] < cy + 1.85) & (k[:, 2] > cz + 4.0))
    corpo = corpo.filtrar_faces(sem_porta)
    c.adicionar("Carenagem", corpo + cupula, BRANCO, "SmoothPlastic", rug=0.35)
    interno = superelipsoide(8.6, 6.6, 9.0, n=5.5, segs_u=40, segs_v=16).inverter().mover(0, cy, cz + 0.2)
    interno = interno.filtrar_faces(sem_porta)
    c.adicionar("CascaInterna", interno, (34, 36, 40), "SmoothPlastic", rug=0.9)
    # faixa grafite e faixa azul (aneis levemente maiores que o corpo)
    def anel(y1, y2, escala):
        a = superelipsoide(9.2 * escala, 7.2 * escala, 9.6 * escala, n=5.5, segs_u=48, segs_v=40).mover(0, cy, cz + 0.2)
        a = a.filtrar_faces(lambda k: (k[:, 1] > y1) & (k[:, 1] < y2))
        return a.filtrar_faces(sem_porta)
    c.adicionar("FaixaGrafite", anel(cy - 2.75, cy - 1.75, 1.008), GRAFITE, "SmoothPlastic")
    c.adicionar("FaixaAzul", anel(cy - 1.55, cy - 1.25, 1.01), AZUL, "SmoothPlastic")
    # saia na base
    saia = superelipsoide(9.8, 1.2, 10.2, n=6, segs_u=40, segs_v=8).mover(0, cy - 3.75, cz + 0.2)
    c.adicionar("Saia", saia, CINZA, "Metal", metal=0.6, rug=0.4)
    # grades de ventilacao laterais
    grades = None
    for sx in (-1, 1):
        for i in range(7):
            g = caixa(0.18, 0.12, 2.6).mover(sx * 4.6, cy + 1.0 + i * 0.32, cz + 1.8)
            grades = g if grades is None else grades + g
    c.adicionar("Grades", grades, GRAFITE, "Metal")
    # modulo de projetores no teto, ventoinhas e projetores
    modulo = superelipsoide(5.2, 1.4, 4.2, n=5, segs_u=32, segs_v=10).mover(0, cy + 3.9, cz + 1.4)
    c.adicionar("ModuloTeto", modulo, (212, 214, 216), "Metal", metal=0.5)
    vent = None
    for i in (-1, 0, 1):
        v = cilindro(0.65, 0.25, 20, "y").mover(i * 1.5, cy + 4.65, cz + 1.4)
        vent = v if vent is None else vent + v
    for i in (-1, 1):
        p = cilindro(0.45, 1.6, 16, "z").girar("x", -20).mover(i * 1.8, cy + 4.1, cz - 1.0)
        vent = vent + p
    c.adicionar("Projetores", vent, GRAFITE, "Metal", metal=0.6)
    # moldura da porta
    moldura = tubo([[-1.6, cy - 3.0, cz + 4.75], [-1.6, cy + 1.9, cz + 4.75], [1.6, cy + 1.9, cz + 4.75], [1.6, cy - 3.0, cz + 4.75]], 0.18, 8)
    c.adicionar("MolduraPorta", moldura, GRAFITE, "Metal")
    # tela de projecao (dentro da cupula, faces para dentro)
    tela = superelipsoide(10.6, 9.2, 10.6, n=2.0, segs_u=40, segs_v=20).inverter().mover(0, cy + 0.4, cz - 3.0)
    tela = tela.filtrar_faces(lambda k: k[:, 2] < cz - 1.4)
    c.adicionar("TelaProjecao", tela, (245, 245, 245), "SmoothPlastic", rug=1)
    c.ancoras(1.0)
    return c


def telhado_arco(largura, profundidade, altura_parede, flecha, nome_espessura=1.2, costelas=18, claraboias=True):
    """Telhado em arco (origem no centro do piso do hangar, frente para -Z)."""
    c = Cena()
    segs = 56
    def arco(raio_extra, z):
        pts = []
        for k in range(segs + 1):
            a = math.pi * k / segs
            x = -math.cos(a) * (largura / 2 + raio_extra)
            y = altura_parede + math.sin(a) * (flecha + raio_extra)
            pts.append([x, y, z])
        return pts
    zs = np.linspace(-profundidade / 2 - 1.5, profundidade / 2 + 1.5, 10)
    externo = grade([arco(nome_espessura, z) for z in zs], fechar_u=False)
    interno = grade([arco(0, z) for z in zs], fechar_u=False).inverter()
    # bordas frontal e traseira
    bordas = None
    for z, inv in ((zs[0], True), (zs[-1], False)):
        a = arco(nome_espessura, z)
        b = arco(0, z)
        bd = grade([a, b], fechar_u=False)
        if inv:
            bd = bd.inverter()
        bordas = bd if bordas is None else bordas + bd
    telhado = externo + bordas
    if claraboias:
        def fora_claraboia(k):
            ang = np.arccos(np.clip(-k[:, 0] / (largura / 2 + nome_espessura), -1, 1))
            faixa = (np.abs(ang - math.pi * 0.35) < 0.05) | (np.abs(ang - math.pi * 0.65) < 0.05)
            return ~faixa
        telhado = telhado.filtrar_faces(fora_claraboia)
        luz = externo.filtrar_faces(lambda k: ~fora_claraboia(k))
        c.adicionar("Claraboias", luz, (220, 235, 245), "Glass", transparencia=0.5)
    c.adicionar("Telhado", telhado, METAL_TELHADO, "CorrodedMetal", metal=0.6, rug=0.5)
    c.adicionar("Forro", interno, (150, 154, 158), "Metal", metal=0.4)
    # costelas estruturais por dentro (trelicas em arco)
    est = None
    for z in np.arange(-profundidade / 2 + 4, profundidade / 2 - 2, costelas):
        pts = arco(-0.9, z)
        t = tubo(pts[::2], 0.55, 8)
        est = t if est is None else est + t
    # tirantes longitudinais
    for frac in (0.2, 0.5, 0.8):
        a = math.pi * frac
        x = -math.cos(a) * (largura / 2 - 0.9)
        y = altura_parede + math.sin(a) * (flecha - 0.9)
        t = tubo([[x, y, -profundidade / 2], [x, y, profundidade / 2]], 0.35, 6)
        est = est + t
    c.adicionar("Estrutura", est, ESTRUTURA, "Metal", metal=0.7)
    c.ancoras(1.0)
    return c


def abrigo_has(largura=90, altura=40, profundidade=140, espessura=5):
    """Abrigo reforcado de concreto (abobada), origem no centro do piso, porta para -Z."""
    c = Cena()
    segs = 40
    def arco(extra, z):
        pts = []
        for k in range(segs + 1):
            a = math.pi * k / segs
            pts.append([-math.cos(a) * (largura / 2 + extra), math.sin(a) * (altura + extra), z])
        return pts
    zs = [-profundidade / 2, -profundidade / 2 + 8, profundidade / 2]
    externo = grade([arco(espessura, z) for z in zs], fechar_u=False)
    interno = grade([arco(0, z) for z in zs], fechar_u=False).inverter()
    frente = grade([arco(espessura, zs[0]), arco(0, zs[0])], fechar_u=False).inverter()
    c.adicionar("Abobada", externo + frente, CONCRETO, "Concrete", rug=0.95)
    c.adicionar("AbobadaInterna", interno, (150, 150, 144), "Concrete", rug=0.95)
    # parede do fundo
    fundo_pts = arco(0, profundidade / 2)
    fundo = tampa(fundo_pts, inverter=True)
    c.adicionar("Fundo", fundo, (140, 140, 134), "Concrete")
    # moldura de aco do portal
    moldura = tubo(arco(0.6, -profundidade / 2 - 0.5), 0.9, 8)
    c.adicionar("Portal", moldura, (88, 92, 86), "Metal", metal=0.6)
    c.ancoras(1.0)
    return c


def arvore_frondosa(semente=1):
    rng = np.random.default_rng(semente)
    c = Cena()
    tronco = revolucao([(0.9, 0), (0.75, 4), (0.55, 9), (0.35, 12)], 10)
    tronco = tronco.girar("x", -90)
    galhos = None
    for k in range(4):
        a = k * math.pi / 2 + rng.uniform(-0.3, 0.3)
        g = tubo([[0, 8, 0], [math.cos(a) * 3, 11.5, math.sin(a) * 3]], 0.3, 6)
        galhos = g if galhos is None else galhos + g
    c.adicionar("Tronco", tronco + galhos, (92, 68, 46), "Wood", rug=1)
    copa = None
    for k in range(7):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.5, 3.5)
        tam = rng.uniform(5.5, 8)
        b = superelipsoide(tam, tam * 0.75, tam, n=2.0, segs_u=12, segs_v=7)
        # deforma um pouco para nao ficar perfeita
        b.v = b.v * (1 + rng.uniform(-0.08, 0.08, size=(len(b.v), 1)))
        b = b.mover(math.cos(a) * r, 12 + rng.uniform(-1, 2.5), math.sin(a) * r)
        copa = b if copa is None else copa + b
    c.adicionar("Copa", copa, (58, 96, 44), "Grass", rug=1)
    c.ancoras(1.0)
    return c


def palmeira(semente=2):
    rng = np.random.default_rng(semente)
    c = Cena()
    caminho = []
    for k in range(9):
        t = k / 8
        caminho.append([math.sin(t * 1.3) * 2.2, t * 22, 0])
    raio_tronco = 0.55
    tronco = tubo(caminho, raio_tronco, 10)
    c.adicionar("Tronco", tronco, (120, 98, 72), "Wood", rug=1)
    topo = np.array(caminho[-1])
    folhas = None
    for k in range(9):
        a = 2 * math.pi * k / 9 + rng.uniform(-0.15, 0.15)
        pts = []
        for i in range(7):
            t = i / 6
            r = t * 9
            y = 1.6 * math.sin(t * math.pi * 0.7) - t * t * 4.5
            pts.append(topo + np.array([math.cos(a) * r, y, math.sin(a) * r]))
        # folha como fita: duas linhas paralelas
        largura = 1.4
        lado = np.array([-math.sin(a), 0, math.cos(a)])
        esq = [p + lado * largura * math.sin(min(1, i / 6 + 0.1) * math.pi) for i, p in enumerate(pts)]
        dir_ = [p - lado * largura * math.sin(min(1, i / 6 + 0.1) * math.pi) for i, p in enumerate(pts)]
        f1 = grade([esq, pts, dir_], fechar_u=False)
        f2 = f1.inverter()
        folha = f1 + f2
        folhas = folha if folhas is None else folhas + folha
    c.adicionar("Folhas", folhas, (62, 112, 48), "Grass", rug=1)
    cocos = None
    for k in range(4):
        a = k * math.pi / 2
        cc = superelipsoide(0.8, 0.8, 0.8, n=2, segs_u=8, segs_v=5).mover(topo[0] + math.cos(a) * 0.6, topo[1] - 0.6, math.sin(a) * 0.6)
        cocos = cc if cocos is None else cocos + cc
    c.adicionar("Cocos", cocos, (90, 70, 40), "SmoothPlastic")
    c.ancoras(1.0)
    return c


ITENS = [
    ("Simulador_Capsula", capsula, {"Unidade": "stud"}),
    ("Hangar_Telhado", lambda: telhado_arco(214, 178, 60 * 0.62, 60 - 60 * 0.62), {"Unidade": "stud"}),
    ("CentroSimulacao_Telhado", lambda: telhado_arco(130, 80, 31, 18, costelas=14), {"Unidade": "stud"}),
    ("Abrigo_HAS", abrigo_has, {"Unidade": "stud"}),
    ("Arvore_Frondosa", lambda: arvore_frondosa(1), {"Unidade": "stud"}),
    ("Arvore_Frondosa2", lambda: arvore_frondosa(7), {"Unidade": "stud"}),
    ("Arvore_Palmeira", palmeira, {"Unidade": "stud"}),
]
