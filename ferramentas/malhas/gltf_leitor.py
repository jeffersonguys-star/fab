"""Leitor minimo de glTF (scene.gltf + scene.bin) com transformacoes de no."""
import json, os
import numpy as np

def _mat(n):
    if 'matrix' in n:
        return np.array(n['matrix']).reshape(4, 4).T
    m = np.eye(4)
    t = n.get('translation', [0, 0, 0]); x, y, z, w = n.get('rotation', [0, 0, 0, 1]); s = n.get('scale', [1, 1, 1])
    R = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)], [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)], [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
    m[:3, :3] = R * np.array(s); m[:3, 3] = t
    return m

def carregar(pasta):
    g = json.load(open(os.path.join(pasta, 'scene.gltf')))
    buf = np.fromfile(os.path.join(pasta, g['buffers'][0]['uri']), dtype=np.uint8)
    def acc(i):
        a = g['accessors'][i]; v = g['bufferViews'][a['bufferView']]
        k = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
        dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a['componentType']]
        off = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        n = a['count'] * k
        if v.get('byteStride') and v['byteStride'] != k * np.dtype(dt).itemsize:
            raw = buf[off: off + v['byteStride'] * a['count']].reshape(a['count'], v['byteStride'])
            return raw[:, :k * np.dtype(dt).itemsize].copy().view(dt).reshape(a['count'], k)
        return buf[off: off + n * np.dtype(dt).itemsize].view(dt).reshape(a['count'], k)
    saida = []
    def andar(i, P):
        n = g['nodes'][i]; W = P @ _mat(n)
        if 'mesh' in n:
            for p in g['meshes'][n['mesh']]['primitives']:
                V = acc(p['attributes']['POSITION']).astype(float)
                V = (np.c_[V, np.ones(len(V))] @ W.T)[:, :3]
                F = acc(p['indices']).reshape(-1, 3).astype(np.int64)
                uv = acc(p['attributes']['TEXCOORD_0']).astype(float) if 'TEXCOORD_0' in p['attributes'] else None
                mat = g['materials'][p['material']]
                saida.append(dict(nome=n.get('name'), material=mat.get('name'), V=V, F=F, uv=uv, matdef=mat))
        for c in n.get('children', []):
            andar(c, W)
    for r in g['scenes'][0]['nodes']:
        andar(r, np.eye(4))
    return g, saida
