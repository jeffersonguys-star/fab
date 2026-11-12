"""
FAB - envia as malhas (.glb) da pasta malhas/ para o Roblox pela Open Cloud (Assets API).

So envia o que e novo ou mudou (compara o hash com malhas/ids.json). Cada arquivo vira
um asset do tipo Model com MeshParts. Os IDs ficam em malhas/ids.json e no modulo
src/ReplicatedStorage/FAB/MalhasIds.lua, que o servidor usa para carregar os modelos.

Variaveis: ROBLOX_API_KEY (segredo, precisa de asset:read e asset:write) e UNIVERSE_ID.
Usa apenas a biblioteca padrao do Python.
"""
import glob
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PASTA = os.path.join(RAIZ, "malhas")
IDS = os.path.join(PASTA, "ids.json")
MODULO = os.path.join(RAIZ, "src", "ReplicatedStorage", "FAB", "MalhasIds.lua")
CHAVE = os.environ.get("ROBLOX_API_KEY", "")
UNIVERSO = os.environ.get("UNIVERSE_ID", "")


def pedir(url, metodo="GET", dados=None, cabecalhos=None):
    req = urllib.request.Request(url, data=dados, method=metodo, headers=cabecalhos or {})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, json.loads(r.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as e:
        corpo = e.read().decode("utf-8", "replace")
        try:
            return e.code, json.loads(corpo)
        except ValueError:
            return e.code, {"erro": corpo}


def criador():
    """Dono dos assets: variavel CRIADOR_ID (opcional), dono da chave (introspeccao) ou dono da experiencia."""
    manual = os.environ.get("CRIADOR_ID", "").strip()
    if manual:
        tipo = "groupId" if os.environ.get("CRIADOR_TIPO", "").lower() == "group" else "userId"
        return tipo, manual
    dados = json.dumps({"apiKey": CHAVE}).encode("utf-8")
    status, r = pedir("https://apis.roblox.com/api-keys/v1/introspect", "POST", dados, {"Content-Type": "application/json"})
    if status == 200 and r.get("authorizedUserId"):
        return "userId", str(r["authorizedUserId"])
    status, r = pedir("https://games.roblox.com/v1/games?universeIds=%s" % UNIVERSO)
    if status == 200 and r.get("data"):
        c = r["data"][0]["creator"]
        return ("groupId" if c["type"] == "Group" else "userId"), str(c["id"])
    raise SystemExit("Nao consegui descobrir o dono dos assets. Crie a variavel CRIADOR_ID (numero do usuario Roblox). Resposta: %s" % (r,))


def enviar(caminho, nome, tipo_criador, id_criador):
    limite = "----FAB" + uuid.uuid4().hex
    pedido = {
        "assetType": "Model",
        "displayName": nome,
        "description": "FAB RP - malha gerada automaticamente",
        "creationContext": {"creator": {tipo_criador: id_criador}},
    }
    with open(caminho, "rb") as fh:
        arquivo = fh.read()
    partes = []
    partes.append(("--%s\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n%s\r\n" % (limite, json.dumps(pedido))).encode("utf-8"))
    partes.append(("--%s\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"%s\"\r\nContent-Type: model/gltf-binary\r\n\r\n"
                   % (limite, os.path.basename(caminho))).encode("utf-8"))
    partes.append(arquivo)
    partes.append(("\r\n--%s--\r\n" % limite).encode("utf-8"))
    corpo = b"".join(partes)
    status, r = pedir("https://apis.roblox.com/assets/v1/assets", "POST", corpo,
                      {"x-api-key": CHAVE, "Content-Type": "multipart/form-data; boundary=%s" % limite})
    if status not in (200, 201):
        print("  falhou ao enviar %s (%s): %s" % (nome, status, r))
        return None
    op = r.get("operationId") or (r.get("path", "").split("/")[-1])
    for _ in range(60):
        if r.get("done"):
            break
        time.sleep(3)
        status, r = pedir("https://apis.roblox.com/assets/v1/operations/%s" % op, cabecalhos={"x-api-key": CHAVE})
        if status != 200:
            print("  erro consultando a operacao de %s (%s): %s" % (nome, status, r))
            return None
    resp = r.get("response") or {}
    asset = resp.get("assetId")
    if not asset:
        print("  %s sem assetId: %s" % (nome, r))
        return None
    moder = (resp.get("moderationResult") or {}).get("moderationState", "?")
    print("  %s -> %s (moderacao: %s)" % (nome, asset, moder))
    return str(asset)


def gerar_modulo(ids):
    linhas = ["-- Gerado por automacao/enviar_malhas.py. Nao edite a mao.", "return {"]
    for nome in sorted(ids):
        linhas.append('\t%s = %s,' % (nome, ids[nome]["assetId"]))
    linhas.append("}")
    with open(MODULO, "w") as fh:
        fh.write("\n".join(linhas) + "\n")


def main():
    ids = {}
    if os.path.exists(IDS):
        with open(IDS) as fh:
            ids = json.load(fh)
    if not CHAVE or not UNIVERSO:
        print("Envio de malhas ignorado: ROBLOX_API_KEY ou UNIVERSE_ID nao configurados.")
        gerar_modulo(ids)
        return
    try:
        tipo, ident = criador()
    except SystemExit as e:
        print("Envio de malhas ignorado: %s" % e)
        gerar_modulo(ids)
        return
    print("Dono dos assets: %s %s" % (tipo, ident))
    mudou = False
    for caminho in sorted(glob.glob(os.path.join(PASTA, "*.glb"))):
        nome = os.path.splitext(os.path.basename(caminho))[0]
        with open(caminho, "rb") as fh:
            h = hashlib.sha256(fh.read()).hexdigest()
        atual = ids.get(nome)
        if atual and atual.get("hash") == h and atual.get("assetId"):
            continue
        print("Enviando %s ..." % nome)
        asset = enviar(caminho, nome, tipo, ident)
        if asset:
            ids[nome] = {"hash": h, "assetId": asset}
            mudou = True
    with open(IDS, "w") as fh:
        json.dump(ids, fh, indent=2, sort_keys=True)
    gerar_modulo(ids)
    print("Malhas no Roblox: %d%s" % (len(ids), " (atualizadas)" if mudou else ""))


if __name__ == "__main__":
    main()
