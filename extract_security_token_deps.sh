#!/bin/bash

# Script para extrair dependências de security-token-e2e-tests
# Autor: Thales Nunes
# Data: 19/05/2025

PROJECT_DIR="/home/thalesnunes/Documentos/jone-dep/data/repo_cache/security-token-e2e-tests"
OUTPUT_FILE="/home/thalesnunes/Documentos/jone-dep/security_token_deps.json"

# Extrair valores do arquivo gradle.properties
extract_property_values() {
  # Se não existe o arquivo, sair
  if [ ! -f "$PROJECT_DIR/gradle.properties" ]; then
    echo "Arquivo gradle.properties não encontrado!" >&2
    exit 1
  fi

  # Ler o arquivo e extrair valores para um array associativo
  declare -A property_values
  while IFS='=' read -r key value || [ -n "$key" ]; do
    # Ignorar linhas em branco ou comentários
    if [[ $key =~ ^[[:space:]]*# ]] || [[ -z $key ]]; then
      continue
    fi
    
    # Remover espaços
    key=$(echo "$key" | tr -d '[:space:]')
    value=$(echo "$value" | tr -d '[:space:]')
    
    # Adicionar ao array associativo
    property_values["$key"]="$value"
    echo "Propriedade: $key = $value" >&2
  done < "$PROJECT_DIR/gradle.properties"
  
  # Exportar o array associativo para uso global
  export property_values
}

# Extrair dependências do build.gradle.kts
parse_dependencies() {
  local build_file="$PROJECT_DIR/build.gradle.kts"
  local props_file="$PROJECT_DIR/gradle.properties"
  
  # Criar um array para armazenar todas as dependências
  local deps_array="[]"
  
  # Criar um array associativo para as propriedades
  declare -A props
  
  # Ler gradle.properties e armazenar valores
  while IFS='=' read -r key value; do
    # Ignorar linhas vazias ou comentários
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    
    # Remover espaços em branco
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    
    # Armazenar no array
    props["$key"]="$value"
    echo "Propriedade carregada: $key = $value" >&2
  done < "$props_file"
  
  # Processar as dependências uma por uma
  while read -r line; do
    # Extrair configuração
    config=""
    if [[ "$line" =~ implementation\( ]]; then
      config="implementation"
    elif [[ "$line" =~ testImplementation\( ]]; then
      config="testImplementation"
    else
      continue
    fi
    
    # Extrair string de dependência
    dep_str=$(echo "$line" | grep -oP '"[^"]+"' | sed 's/"//g')
    
    # Dividir em partes (group:artifact:version)
    IFS=':' read -r group artifact version_expr <<< "$dep_str"
    
    # Resolver a versão
    resolved_version="$version_expr"
    
    # Se a versão contém uma variável ($kotlinVersion, etc)
    if [[ "$version_expr" =~ \$([a-zA-Z0-9_]+) ]]; then
      var_name="${BASH_REMATCH[1]}"
      if [[ -n "${props[$var_name]}" ]]; then
        resolved_version="${props[$var_name]}"
      fi
    fi
    
    echo "Dependência: $config - $group:$artifact:$resolved_version" >&2
    
    # Criar JSON para esta dependência
    dep_json="{\"group\":\"$group\",\"name\":\"$artifact\",\"version\":\"$resolved_version\",\"configuration\":\"$config\"}"
    
    # Adicionar ao array de dependências
    deps_array=$(echo "$deps_array" | jq --argjson dep "$dep_json" '. + [$dep]')
  done < <(grep -E "(implementation|testImplementation)\\(\"[^\"]+\"\\)" "$build_file")
  
  # Retornar array completo de dependências
  echo "$deps_array"
}

# Extrair dependências
deps=$(parse_dependencies)

# Verificar se obtivemos dependências
if [ "$deps" = "[]" ]; then
  echo "ERRO: Nenhuma dependência foi extraída!" >&2
  exit 1
fi

# Salvar em arquivo JSON formatado
echo "$deps" | jq '.' > "$OUTPUT_FILE"

echo "Dependências extraídas com sucesso para $OUTPUT_FILE" >&2
echo "Total de dependências: $(echo "$deps" | jq 'length')" >&2
