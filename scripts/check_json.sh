#!/bin/bash
# Script simples para verificar se o arquivo dependencies.json contém JSON válido

JSON_FILE="$(dirname "$0")/../data/dependencies.json"

if [ ! -f "$JSON_FILE" ]; then
  echo "Erro: Arquivo não encontrado: $JSON_FILE"
  exit 1
fi

echo "Verificando JSON: $JSON_FILE"

# Verificar com Python (mais simples e confiável)
python3 -m json.tool "$JSON_FILE" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ JSON válido"
  if command -v jq >/dev/null 2>&1; then
    echo "Projetos: $(jq 'length' "$JSON_FILE" 2>/dev/null || echo "N/A")"
  fi
  exit 0
else
  echo "❌ JSON INVÁLIDO"
  exit 1
fi
