"""Gera todas as malhas (.glb), o catalogo e previas em PNG."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import aeronaves  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SAIDA = os.path.join(RAIZ, "malhas")
PREVIAS = os.environ.get("PREVIAS")


def main(filtro=None):
    os.makedirs(SAIDA, exist_ok=True)
    catalogo = {}
    itens = []
    for spec in aeronaves.TODAS:
        itens.append(("Aeronave_" + spec["id"], lambda s=spec: aeronaves.construir(s), {"Unidade": "metro", "Pivos": {"Helice": [0, spec["helice"][1], spec["helice"][0]] if spec.get("helice") else None}}))
    try:
        import estruturas
        itens += estruturas.ITENS
    except ImportError:
        pass
    for nome, fn, meta in itens:
        if filtro and filtro not in nome:
            continue
        cena = fn()
        caminho = os.path.join(SAIDA, nome + ".glb")
        cena.salvar_glb(caminho)
        meta = dict(meta)
        meta["Arquivo"] = nome + ".glb"
        meta["Triangulos"] = cena.triangulos()
        catalogo[nome] = meta
        print("%-28s %6d triangulos" % (nome, cena.triangulos()))
        if PREVIAS:
            cena.previa(os.path.join(PREVIAS, nome + ".png"), titulo=nome)
    if not filtro:
        with open(os.path.join(SAIDA, "catalogo.json"), "w") as fh:
            json.dump(catalogo, fh, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
