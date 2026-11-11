#!/usr/bin/env bash
# FAB - monta o place com o Rojo e publica no Roblox pela Open Cloud.
# Variaveis necessarias: ROBLOX_API_KEY (segredo), UNIVERSE_ID e PLACE_ID (variaveis do repositorio).
set -euo pipefail

ROJO_VERSAO="7.6.1"

if ! command -v rojo >/dev/null 2>&1; then
  curl -sSL -o /tmp/rojo.zip "https://github.com/rojo-rbx/rojo/releases/download/v${ROJO_VERSAO}/rojo-${ROJO_VERSAO}-linux-x86_64.zip"
  unzip -o -q /tmp/rojo.zip -d /tmp/rojo
  export PATH="/tmp/rojo:$PATH"
fi

mkdir -p build
rojo build default.project.json -o build/FAB.rbxlx

if [ -z "${ROBLOX_API_KEY:-}" ] || [ -z "${UNIVERSE_ID:-}" ] || [ -z "${PLACE_ID:-}" ]; then
  echo "Publicacao ignorada: ROBLOX_API_KEY, UNIVERSE_ID ou PLACE_ID nao configurados."
  exit 0
fi

status=$(curl -sS -o build/resposta.json -w "%{http_code}" \
  -X POST "https://apis.roblox.com/universes/v1/${UNIVERSE_ID}/places/${PLACE_ID}/versions?versionType=Published" \
  -H "x-api-key: ${ROBLOX_API_KEY}" \
  -H "Content-Type: application/xml" \
  --data-binary @build/FAB.rbxlx)

echo "Resposta do Roblox (${status}): $(cat build/resposta.json)"
if [ "$status" != "200" ]; then
  exit 1
fi
