"""
FAB - importa o modelo pronto do F-5EM (modelos_prontos/F5EM_original.glb, gerado por IA a partir de imagem)
e o transforma em Aeronave_F5.glb para o jogo:
- reorienta (nariz -Z, topo +Y) e escala para metros (14 m de comprimento, 8,1 m de envergadura);
- reduz os triangulos por agrupamento de vertices e divide em pecas de no maximo 19000 triangulos;
- pinta a camuflagem cinza por regiao (superficies superiores em tres tons, inferiores claras);
- adiciona trem de pouso, capota escura e as ancoras de alinhamento.
"""
import json
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from malha import Cena, Malha, caixa  # noqa: E402
import aeronaves  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ORIGEM = os.path.join(RAIZ, "modelos_prontos", "F5EM_original.glb")
SAIDA = os.path.join(RAIZ, "malhas", "Aeronave_F5.glb")

COMPRIMENTO = 14.0
ENVERGADURA = 8.1
ALTURA_ESCALA = 6.4


def ler_glb(caminho):
    b = open(caminho, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    ini = 20 + n + 8
    p = j["meshes"][0]["primitives"][0]

    def acc(i, dt, k):
        a = j["accessors"][i]
        v = j["bufferViews"][a["bufferView"]]
        return np.frombuffer(b, dtype=dt, count=a["count"] * k, offset=ini + v.get("byteOffset", 0) + a.get("byteOffset", 0))
    V = acc(p["attributes"]["POSITION"], np.float32, 3).reshape(-1, 3).astype(float)
    ct = j["accessors"][p["indices"]]["componentType"]
    I = acc(p["indices"], np.uint32 if ct == 5125 else np.uint16, 1).reshape(-1, 3).astype(np.int64)
    return V, I


def agrupar(V, I, celula):
    """Reducao por agrupamento de vertices em grade."""
    q = np.floor((V - V.min(0)) / celula).astype(np.int64)
    chave = (q[:, 0] * 100000 + q[:, 1]) * 100000 + q[:, 2]
    _, inv, cont = np.unique(chave, return_inverse=True, return_counts=True)
    novo = np.zeros((len(cont), 3))
    np.add.at(novo, inv, V)
    novo /= cont[:, None]
    F = inv[I]
    ok = (F[:, 0] != F[:, 1]) & (F[:, 1] != F[:, 2]) & (F[:, 0] != F[:, 2])
    F = F[ok]
    F = np.unique(np.sort(F, axis=1), axis=0) if False else F
    return novo, F


def principal():
    V, I = ler_glb(ORIGEM)
    # reorienta: modelo (x frente, y cima, z lado) -> jogo (X lado, Y cima, Z = -frente)
    V = np.stack([V[:, 2], V[:, 1], -V[:, 0]], axis=1)
    I = I[:, [0, 2, 1]]  # a troca de eixos preserva a orientacao (determinante +1); mantem a ordem original
    I = I[:, [0, 2, 1]]
    # escala nao uniforme
    ext = V.max(0) - V.min(0)
    esc = np.array([ENVERGADURA / ext[0], ALTURA_ESCALA / 1.0, COMPRIMENTO / ext[2]])
    esc[1] = esc[2] * 0.9
    V = V * esc
    # posiciona: nariz em z=-7, eixo da fuselagem em x=0, ventre a 0,5 m acima do chao do trem
    V[:, 0] -= (V[:, 0].max() + V[:, 0].min()) / 2
    V[:, 2] -= V[:, 2].min() - (-7.0)
    V[:, 1] += (-1.4 + 0.5) - V[:, 1].min()

    alvo = 46000
    celula = 0.07
    for _ in range(12):
        Vr, Fr = agrupar(V, I, celula)
        if len(Fr) <= alvo:
            break
        celula *= 1.08
    print("triangulos:", len(I), "->", len(Fr), "celula", round(celula, 3))
    V, I = Vr, Fr

    # classificacao por normal e ruido
    n_face = np.cross(V[I[:, 1]] - V[I[:, 0]], V[I[:, 2]] - V[I[:, 0]])
    n_face /= np.maximum(np.linalg.norm(n_face, axis=1), 1e-9)[:, None]
    c = V[I].mean(axis=1)
    cima = n_face[:, 1] > 0.35
    ruido = np.sin(c[:, 2] * 0.9 + np.sin(c[:, 0] * 0.8) * 1.6) + np.sin(c[:, 0] * 1.3 - c[:, 2] * 0.35)
    tom = np.digitize(ruido, [-0.5, 0.7])
    classe = np.where(cima, tom, 3)
    cores = {0: (120, 128, 124), 1: (96, 104, 102), 2: (146, 152, 154), 3: (178, 184, 188)}
    nomes = {0: "CamuflagemA", 1: "CamuflagemB", 2: "CamuflagemC", 3: "Ventre"}
    # capota: faces do dorso na regiao da cabine
    cabine = cima & (c[:, 2] > -4.1) & (c[:, 2] < -1.7) & (np.abs(c[:, 0]) < 0.42) & (c[:, 1] > V[:, 1].min() + 1.5) & (n_face[:, 1] > 0.5)
    classe = np.where(cabine, 4, classe)
    cores[4] = (40, 52, 60)
    nomes[4] = "Capota"

    cena = Cena()
    faixas = np.digitize(c[:, 2], np.quantile(c[:, 2], [0.34, 0.67]))
    for k in range(5):
        for s in range(3):
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
            mat = "Glass" if k == 4 else "SmoothPlastic"
            cena.adicionar("%s%d" % (nomes[k], s + 1), m, cores[k], mat, transparencia=0.35 if k == 4 else 0.0, metal=0.1, rug=0.55)

    # trem de pouso (estendido), mesmas posicoes do modelo de fisica
    rodas = [(0, -1.4, -4.3, 0.23, 0.15, -0.55), (-1.3, -1.4, 0.9, 0.3, 0.18, -0.65), (1.3, -1.4, 0.9, 0.3, 0.18, -0.65)]
    aeronaves.trem(cena, rodas)
    cena.ancoras(1.0)
    cena.salvar_glb(SAIDA)
    print("salvo", SAIDA, cena.triangulos(), "triangulos,", len(cena.pecas), "pecas")
    if os.environ.get("PREVIAS"):
        cena.previa(os.path.join(os.environ["PREVIAS"], "F5_importado.png"), titulo="F5")


if __name__ == "__main__":
    principal()
