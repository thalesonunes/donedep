#!/bin/bash

gradle_file="./data/repo_cache/security-token-e2e-tests/build.gradle.kts"

echo "Verificando o arquivo: $gradle_file"
cat "$gradle_file" | grep -n "JavaVersion"

echo -e "\nTentando extrair o número da versão:"
if grep -q "java\.sourceCompatibility.*JavaVersion\.VERSION_[0-9]" "$gradle_file"; then
  version=$(grep -oP "JavaVersion\.VERSION_\K[0-9]+" "$gradle_file" | head -1)
  echo "Versão extraída: $version"
else
  echo "Não encontrei o padrão esperado"
fi

echo -e "\nTestando com outras expressões regulares:"
if grep -q "VERSION_[0-9]" "$gradle_file"; then
  version=$(grep -oP "VERSION_\K[0-9]+" "$gradle_file" | head -1)
  echo "Versão extraída (simples): $version"
fi
