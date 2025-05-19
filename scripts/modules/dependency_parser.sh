#!/bin/bash

# JoneDep - Parser de dependências (Versão corrigida para JSON)
# Autor: Thales Nunes
# Data: 19/05/2025
# Versão: 1.1

# Importar módulos comuns
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Configurar LOG_FILE - será sobrescrito pelo valor do script principal se existir
DATA_DIR="$(dirname "${BASH_SOURCE[0]}")/../../../data"
LOG_FILE="${LOG_FILE:-"$DATA_DIR/jone-dep.log"}"

# Extrair variáveis de versão de um arquivo Gradle
extract_version_variables() {
  local file="$1"
  local variables="{}"
  
  if [ ! -f "$file" ]; then
    return
  fi
  
  # Criar um array associativo temporário para armazenar as variáveis e valores
  local var_lines=$(grep -E "^[[:space:]]*(def|val|const|final|var)[[:space:]]+[a-zA-Z0-9_]+(Version|_VERSION)[[:space:]]*=[[:space:]]*['\"]" "$file" 2>/dev/null)
  local prop_lines=$(grep -E "^[a-zA-Z0-9_]+(Version|_VERSION)[[:space:]]*=[[:space:]]*['\"]" "$file" 2>/dev/null)
  local ext_lines=$(grep -E "ext\.[a-zA-Z0-9_]+(Version|_VERSION)[[:space:]]*=[[:space:]]*['\"]" "$file" 2>/dev/null)
  
  # Combinar todas as linhas e processar
  local all_lines="${var_lines}${prop_lines}${ext_lines}"
  
  if [ -n "$all_lines" ]; then
    variables="{"
    while IFS= read -r line; do
      if [[ "$line" =~ ([a-zA-Z0-9_]+(Version|_VERSION))[[:space:]]*=[[:space:]]*[\'\"]([^\'\"]+) ]]; then
        local var_name="${BASH_REMATCH[1]}"
        local var_value="${BASH_REMATCH[3]}"
        
        # Adicionar a variável ao json
        if [ "$variables" != "{" ]; then
          variables="$variables,"
        fi
        variables="$variables\"$var_name\":\"$var_value\""
      fi
    done <<< "$all_lines"
    variables="$variables}"
  fi
  
  echo "$variables"
}

# Extrair dependências de um projeto
extract_dependencies() {
  local project_dir="$1"
  local dependencies_json="[]"
  
  # Procurar arquivos de construção
  local build_files=(
    "$project_dir/build.gradle"
    "$project_dir/build.gradle.kts"
    "$project_dir/pom.xml"
  )
  
  # Arrays para coletar todas as dependências
  local all_deps=()
  
  for build_file in "${build_files[@]}"; do
    if [ -f "$build_file" ]; then
      local file_extension="${build_file##*.}"
      
      # Extrair variáveis de versão do arquivo
      local version_vars=$(extract_version_variables "$build_file")
      
      # Processar dependências com base no tipo de arquivo
      case "$file_extension" in
        gradle|kts)
          # Dependências Gradle
          while read -r dep; do
            if [ -n "$dep" ]; then
              all_deps+=("$dep")
            fi
          done < <(parse_gradle_dependencies "$build_file" "$version_vars")
          
          # Version catalogs
          if [ -d "$project_dir/gradle" ]; then
            local catalog_files=($(find "$project_dir/gradle" -name "*.toml" -o -name "*.properties" 2>/dev/null))
            for catalog_file in "${catalog_files[@]}"; do
              while read -r dep; do
                if [ -n "$dep" ]; then
                  all_deps+=("$dep")
                fi
              done < <(parse_gradle_catalog "$catalog_file")
            done
          fi
          ;;
          
        xml)
          # Dependências Maven
          while read -r dep; do
            if [ -n "$dep" ]; then
              all_deps+=("$dep")
            fi
          done < <(parse_maven_dependencies "$build_file")
          ;;
      esac
    fi
  done
  
  # Construir o JSON de saída
  if [ ${#all_deps[@]} -gt 0 ]; then
    dependencies_json="["
    local first=true
    
    for dep in "${all_deps[@]}"; do
      # Filtrar entradas inválidas - garantir que não há mensagens de log misturadas
      if [[ "$dep" == "{"* && "$dep" == *"}" ]]; then
        # Verificar se a entrada parece ser um objeto JSON de dependência válido
        if [[ "$dep" == *"\"group\""* && "$dep" == *"\"name\""* && "$dep" == *"\"version\""* ]]; then
          if ! $first; then
            dependencies_json="$dependencies_json,"
          else
            first=false
          fi
          dependencies_json="$dependencies_json$dep"
        else
          # Registrar dependência inválida no log
          echo "Ignorando dependência com formato inválido: $dep" >> "$LOG_FILE" 2>&1
        fi
      else
        # Registrar entrada inválida no log
        echo "Ignorando entrada inválida que não é um objeto JSON: $dep" >> "$LOG_FILE" 2>&1
      fi
    done
    
    dependencies_json="$dependencies_json]"
    # Direcionar log para o arquivo de log
    echo "Encontradas ${#all_deps[@]} dependências em $project_dir" >> "$LOG_FILE" 2>&1
  else
    echo "Nenhuma dependência encontrada em $project_dir" >> "$LOG_FILE" 2>&1
  fi
  
  echo "$dependencies_json"
}

# Analisar dependências do Gradle
parse_gradle_dependencies() {
  local build_file="$1"
  local version_vars="$2"
  
  grep -E "(implementation|api|compile|runtime|testImplementation|testCompile)" "$build_file" | while read -r line; do
    # Remover comentários
    line=$(echo "$line" | sed 's/\/\/.*$//g')
    
    # Formato padrão: implementation 'org.springframework:spring-core:5.2.0'
    if [[ "$line" =~ (implementation|api|compile|runtime|testImplementation|testCompile)[[:space:]]*[\(]?[[:space:]]*[\'\"]([^:\'\"]+):([^:\'\"]+):([^\'\"]+) ]]; then
      local config="${BASH_REMATCH[1]}"
      local group="${BASH_REMATCH[2]}"
      local name="${BASH_REMATCH[3]}"
      local version="${BASH_REMATCH[4]}"
      
      # Verificar se a versão é uma variável e substituí-la se necessário
      if [[ "$version" =~ \$\{([a-zA-Z0-9_]+)\} ]]; then
        local var_name="${BASH_REMATCH[1]}"
        local var_value=$(echo "$version_vars" | grep -oP "\"$var_name\":\"\K[^\"]+")
        if [ -n "$var_value" ]; then
          version="$var_value"
        fi
      fi
      
      echo "{\"group\":\"$group\",\"name\":\"$name\",\"version\":\"$version\",\"configuration\":\"$config\"}"
    
    # Formato de mapa: implementation group: 'org.springframework', name: 'spring-core', version: '5.2.0'
    elif [[ "$line" =~ (implementation|api|compile|runtime|testImplementation|testCompile)[[:space:]]*[\(]?[[:space:]]*(group:|module:)[[:space:]]*[\'\"]([^\'\"]+) ]]; then
      local config="${BASH_REMATCH[1]}"
      local start_key="${BASH_REMATCH[2]}"
      local start_value="${BASH_REMATCH[3]}"
      
      local group=""
      local name=""
      local version=""
      
      if [[ "$start_key" == "group:" ]]; then
        group="$start_value"
        if [[ "$line" =~ name:[[:space:]]*[\'\"]([^\'\"]+) ]]; then
          name="${BASH_REMATCH[1]}"
        fi
        if [[ "$line" =~ version:[[:space:]]*[\'\"]([^\'\"]+) ]]; then
          version="${BASH_REMATCH[1]}"
        fi
      elif [[ "$start_key" == "module:" ]]; then
        name="$start_value"
        if [[ "$line" =~ group:[[:space:]]*[\'\"]([^\'\"]+) ]]; then
          group="${BASH_REMATCH[1]}"
        fi
        if [[ "$line" =~ version:[[:space:]]*[\'\"]([^\'\"]+) ]]; then
          version="${BASH_REMATCH[1]}"
        fi
      fi
      
      # Verificar se encontrou os valores necessários
      if [ -n "$group" ] && [ -n "$name" ]; then
        if [ -z "$version" ]; then
          version="managed"
        fi
        
        echo "{\"group\":\"$group\",\"name\":\"$name\",\"version\":\"$version\",\"configuration\":\"$config\"}"
      fi
    
    # DSL Kotlin: implementation(kotlin("stdlib-jdk8", kotlinVersion))
    elif [[ "$line" =~ (implementation|api|compile|runtime|testImplementation|testCompile)[\(]?[[:space:]]*kotlin[\(][\'\"]([^\'\"]+) ]]; then
      local config="${BASH_REMATCH[1]}"
      local name="${BASH_REMATCH[2]}"
      local group="org.jetbrains.kotlin"
      local version="managed"
      
      # Verificar se tem versão especificada
      if [[ "$line" =~ kotlin[\(][\'\"]([^\'\"]+)[\'\"][[:space:]]*,[[:space:]]*([a-zA-Z0-9_\$\{\}\.\-]+) ]]; then
        local var_version="${BASH_REMATCH[2]}"
        
        # Se a versão for uma variável de ${}
        if [[ "$var_version" =~ \$\{([a-zA-Z0-9_]+)\} ]]; then
          local var_name="${BASH_REMATCH[1]}"
          local var_value=$(echo "$version_vars" | grep -oP "\"$var_name\":\"\K[^\"]+")
          if [ -n "$var_value" ]; then
            version="$var_value"
          fi
        elif [[ "$var_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)? ]]; then
          # Se for diretamente uma versão numérica
          version="$var_version"
        fi
      fi
      
      echo "{\"group\":\"$group\",\"name\":\"kotlin-$name\",\"version\":\"$version\",\"configuration\":\"$config\"}"
    fi
  done
}

# Analisar catálogos de versão do Gradle
parse_gradle_catalog() {
  local catalog_file="$1"
  local in_libraries_section=0
  
  while IFS= read -r line; do
    # Detectar seções no arquivo .toml
    if [[ "$line" =~ ^\s*\[libraries\]\s*$ ]]; then
      in_libraries_section=1
      continue
    elif [[ "$line" =~ ^\s*\[[^]]+\]\s*$ ]]; then
      in_libraries_section=0
      continue
    fi
    
    # Processar apenas as linhas na seção libraries
    if [ $in_libraries_section -eq 1 ]; then
      if [[ "$line" =~ ([a-zA-Z0-9\.-]+)\ *=\ *\{\ *module\ *=\ *\"([^:\"]+):([^\"]+)\"\ *,\ *version(\.ref)?\ *=\ *\"?([^\"\ }]+) ]]; then
        local entry="${BASH_REMATCH[1]}"
        local group="${BASH_REMATCH[2]}"
        local name="${BASH_REMATCH[3]}"
        local version="${BASH_REMATCH[5]}"
        
        # Verificar se a versão é uma referência e buscar em outra seção
        # (isso é uma simplificação, um parsing completo de TOML requer mais trabalho)
        if [[ "$version" =~ ^[a-zA-Z] ]]; then
          # Buscar a versão na seção [versions]
          local version_value=$(grep -A50 "^\[versions\]" "$catalog_file" | grep -m1 -oP "$version\s*=\s*\"\K[^\"]+")
          if [ -n "$version_value" ]; then
            version="$version_value"
          fi
        fi
        
        echo "{\"group\":\"$group\",\"name\":\"$name\",\"version\":\"$version\",\"configuration\":\"catalog\"}"
      fi
    fi
  done < "$catalog_file"
}

# Analisar dependências do Maven
parse_maven_dependencies() {
  local pom_file="$1"
  local in_dependencies=0
  local current_group=""
  local current_artifact=""
  local current_version=""
  local current_scope=""
  
  # Ler XML linha por linha com um método simples baseado em marcadores
  while IFS= read -r line; do
    # Verificar início da seção de dependências
    if [[ "$line" =~ \<dependencies\> ]]; then
      in_dependencies=1
      continue
    elif [[ "$line" =~ \</dependencies\> ]]; then
      in_dependencies=0
      continue
    fi
    
    # Processar apenas se estiver dentro da seção de dependências
    if [ $in_dependencies -eq 1 ]; then
      # Detectar início de uma nova dependência
      if [[ "$line" =~ \<dependency\> ]]; then
        current_group=""
        current_artifact=""
        current_version=""
        current_scope="compile"
        continue
      # Extrair informações da dependência
      elif [[ "$line" =~ \<groupId\>(.*)\</groupId\> ]]; then
        current_group="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ \<artifactId\>(.*)\</artifactId\> ]]; then
        current_artifact="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ \<version\>(.*)\</version\> ]]; then
        current_version="${BASH_REMATCH[1]}"
        
        # Resolver referências a propriedades: ${property.name}
        if [[ "$current_version" =~ \$\{([^}]+)\} ]]; then
          local prop_name="${BASH_REMATCH[1]}"
          local prop_value=$(grep -oP "<$prop_name>\K[^<]+" "$pom_file" | head -1)
          
          if [ -n "$prop_value" ]; then
            current_version="$prop_value"
          fi
        fi
      elif [[ "$line" =~ \<scope\>(.*)\</scope\> ]]; then
        current_scope="${BASH_REMATCH[1]}"
      # Fim de uma dependência, salvar se tiver os dados mínimos
      elif [[ "$line" =~ \</dependency\> ]]; then
        if [ -n "$current_group" ] && [ -n "$current_artifact" ]; then
          # Se não houver versão especificada, usar "managed"
          if [ -z "$current_version" ]; then
            current_version="managed"
          fi
          
          echo "{\"group\":\"$current_group\",\"name\":\"$current_artifact\",\"version\":\"$current_version\",\"configuration\":\"$current_scope\"}"
        fi
        continue
      fi
    fi
  done < "$pom_file"
}

# Executar o script se for chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Se o primeiro argumento for um comando conhecido, executá-lo
  case "$1" in
    extract_dependencies)
      if [ -z "$2" ]; then
        echo "Erro: Diretório do projeto não especificado"
        echo "Uso: $0 extract_dependencies <diretório_do_projeto>"
        exit 1
      fi
      extract_dependencies "$2"
      ;;
    *)
      echo "Comando não reconhecido: $1"
      echo "Comandos disponíveis:"
      echo "  extract_dependencies <diretório_do_projeto>  - Extrair dependências de um projeto"
      exit 1
      ;;
  esac
fi
