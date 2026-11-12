"""Reducao de malha por colapso de arestas com metrica quadrica (Garland-Heckbert), com protecao de bordas e inversao de faces."""
import heapq

import numpy as np


def decimar(V, F, alvo_faces, peso_borda=50.0, C=None):
    """Se C (cor por vertice) for dado, devolve tambem as cores."""
    V = np.array(V, dtype=float)
    C = None if C is None else np.array(C, dtype=float)
    F = np.array(F, dtype=np.int64)
    # remove faces degeneradas
    ok = (F[:, 0] != F[:, 1]) & (F[:, 1] != F[:, 2]) & (F[:, 0] != F[:, 2])
    F = F[ok]
    if len(F) <= alvo_faces:
        return (V, F) if C is None else (V, F, C)
    nv = len(V)
    # quadricas por vertice (10 coeficientes simetricos como matriz 4x4)
    Q = np.zeros((nv, 4, 4))
    n = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    area = np.linalg.norm(n, axis=1)
    n = n / np.maximum(area, 1e-12)[:, None]
    d = -(n * V[F[:, 0]]).sum(1)
    P = np.c_[n, d]
    K = P[:, :, None] * P[:, None, :] * area[:, None, None]
    for k in range(3):
        np.add.at(Q, F[:, k], K)
    # bordas: planos perpendiculares as bordas
    ar = np.sort(np.r_[F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]], axis=1)
    chave = ar[:, 0] * nv + ar[:, 1]
    uniq, inv, cont = np.unique(chave, return_inverse=True, return_counts=True)
    fa = np.r_[np.arange(len(F)), np.arange(len(F)), np.arange(len(F))]
    borda = cont[inv] == 1
    for (a, b), f in zip(ar[borda], fa[borda]):
        e = V[b] - V[a]
        pn = np.cross(e, n[f])
        ln = np.linalg.norm(pn)
        if ln < 1e-12:
            continue
        pn /= ln
        pl = np.r_[pn, -pn @ V[a]]
        Kb = np.outer(pl, pl) * peso_borda * np.linalg.norm(e) ** 2
        Q[a] += Kb
        Q[b] += Kb
    vivo_f = np.ones(len(F), dtype=bool)
    Fl = F.copy()
    viz = [set() for _ in range(nv)]
    for i, f in enumerate(Fl):
        for v in f:
            viz[v].add(i)
    vivo_v = np.ones(nv, dtype=bool)
    versao = np.zeros(nv, dtype=np.int64)

    def custo(a, b):
        Qs = Q[a] + Q[b]
        melhor = None
        for p in (V[a], V[b], (V[a] + V[b]) / 2):
            h = np.r_[p, 1.0]
            c = h @ Qs @ h
            if melhor is None or c < melhor[0]:
                melhor = (c, p)
        return melhor

    heap = []
    for k in uniq:
        a, b = int(k // nv), int(k % nv)
        c, _ = custo(a, b)
        heapq.heappush(heap, (c, a, b, versao[a], versao[b]))
    faces_atuais = len(F)
    while faces_atuais > alvo_faces and heap:
        c, a, b, va, vb = heapq.heappop(heap)
        if not (vivo_v[a] and vivo_v[b]) or versao[a] != va or versao[b] != vb:
            continue
        c, p = custo(a, b)
        comuns = viz[a] & viz[b]
        # evita inversao: normais das faces vizinhas (sem as que somem) nao podem virar
        invalido = False
        for fi in (viz[a] | viz[b]) - comuns:
            f = Fl[fi]
            antes = np.cross(V[f[1]] - V[f[0]], V[f[2]] - V[f[0]])
            novo = [p if v in (a, b) else V[v] for v in f]
            depois = np.cross(novo[1] - novo[0], novo[2] - novo[0])
            na, nd = np.linalg.norm(antes), np.linalg.norm(depois)
            if na < 1e-14 or nd < 1e-14 or (antes @ depois) / (na * nd) < 0.3:
                invalido = True
                break
        if invalido:
            continue
        # colapsa b em a
        V[a] = p
        if C is not None:
            C[a] = (C[a] + C[b]) / 2
        Q[a] = Q[a] + Q[b]
        for fi in list(viz[b]):
            if fi in comuns:
                vivo_f[fi] = False
                for v in Fl[fi]:
                    if v != b:
                        viz[v].discard(fi)
                faces_atuais -= 1
            else:
                Fl[fi] = np.where(Fl[fi] == b, a, Fl[fi])
                viz[a].add(fi)
        viz[b] = set()
        vivo_v[b] = False
        versao[a] += 1
        vizinhos = set()
        for fi in viz[a]:
            for v in Fl[fi]:
                if v != a:
                    vizinhos.add(int(v))
        for v in vizinhos:
            c2, _ = custo(a, v)
            heapq.heappush(heap, (c2, a, v, versao[a], versao[v]))
    Fo = Fl[vivo_f]
    usado = np.unique(Fo)
    mapa = -np.ones(nv, dtype=np.int64)
    mapa[usado] = np.arange(len(usado))
    if C is None:
        return V[usado], mapa[Fo]
    return V[usado], mapa[Fo], C[usado]
