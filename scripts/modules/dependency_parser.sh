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
  
  # Determinar o tipo de arquivo (kotlin DSL ou groovy)
  local is_kotlin_dsl=false
  if [[ "$file" == *".kts" ]]; then
    is_kotlin_dsl=true
  fi
  
  # Extrair variáveis de diferentes lugares
  
  # 1. Variáveis locais ou globais (def, val, const, var, etc.)
  local var_patterns=(
    # Padrão para Groovy/Gradle: def someVersion = "1.2.3"
    "^[[:space:]]*(def|val|const|final|var)[[:space:]]+[a-zA-Z0-9_]+(Version|_VERSION)[[:space:]]*=[[:space:]]*['\"]([^'\"]+)"
    # Padrão para propriedades simples: someVersion = "1.2.3"
    "^[[:space:]]*[a-zA-Z0-9_]+(Version|_VERSION)[[:space:]]*=[[:space:]]*['\"]([^'\"]+)"
    # Padrão para ext properties: ext.someVersion = "1.2.3"
    "ext\.[a-zA-Z0-9_]+(Version|_VERSION)[[:space:]]*=[[:space:]]*['\"]([^'\"]+)"
    # Padrão para blocos ext { }
    "^[[:space:]]*[a-zA-Z0-9_]+(Version|_VERSION)[[:space:]]*=[[:space:]]*['\"]([^'\"]+)"
  )
  
  # Incluir todos os arquivos extras relevantes
  local gradle_files=("$file")
  
  # Adicionar gradle.properties se existir
  local project_dir=$(dirname "$file")
  if [ -f "$project_dir/gradle.properties" ]; then
    gradle_files+=("$project_dir/gradle.properties")
  fi
  
  # Inicializar o JSON
  variables="{"
  local first=true
  
  # Processar todos os arquivos
  for gradle_file in "${gradle_files[@]}"; do
    local file_content=$(<"$gradle_file")
    
    # Processar todas as linhas do arquivo
    while IFS= read -r line; do
      # Remover comentários
      line=$(echo "$line" | sed 's/\/\/.*$//g')
      
      # Verificar se a linha contém uma definição de versão
      if [[ "$gradle_file" == *"gradle.properties"* ]]; then
        # Formato especial para gradle.properties: key=value
        if [[ "$line" =~ ^([a-zA-Z0-9_.]+)(Version|\.version)[[:space:]]*=[[:space:]]*([^[:space:]]+) ]]; then
          local var_name="${BASH_REMATCH[1]}Version"
          local var_value="${BASH_REMATCH[3]}"
          
          # Remover aspas se presentes
          var_value=$(echo "$var_value" | tr -d '"' | tr -d "'")
          
          # Adicionar ao JSON
          if ! $first; then
            variables="$variables,"
          else
            first=false
          fi
          variables="$variables\"$var_name\":\"$var_value\""
          
          log_debug "Extraída variável de gradle.properties: $var_name = $var_value"
        fi
      else
        # Para arquivos Gradle regulares
        for pattern in "${var_patterns[@]}"; do
          if [[ "$line" =~ $pattern ]]; then
            # Extrair nome da variável
            local var_name
            if [[ "$line" =~ ([a-zA-Z0-9_]+(Version|_VERSION)) ]]; then
              var_name="${BASH_REMATCH[1]}"
            else
              continue
            fi
            
            # Extrair valor da variável
            local var_value
            if [[ "$line" =~ =[[:space:]]*[\'\"]([^\'\"]+) ]]; then
              var_value="${BASH_REMATCH[1]}"
            else
              continue
            fi
            
            # Adicionar ao JSON
            if ! $first; then
              variables="$variables,"
            else
              first=false
            fi
            variables="$variables\"$var_name\":\"$var_value\""
            
            log_debug "Extraída variável de $gradle_file: $var_name = $var_value"
            break
          fi
        done
      fi
    done <<< "$file_content"
    
    # Se for um arquivo Kotlin DSL, procurar por blocos extras
    if $is_kotlin_dsl && [[ "$gradle_file" == *".kts" ]]; then
      # Extrair variáveis do bloco extra do Kotlin
      local in_extra_block=false
      local block_content=""
      
      while IFS= read -r line; do
        if [[ "$line" =~ extra[[:space:]]*\{ ]]; then
          in_extra_block=true
          continue
        fi
        
        if $in_extra_block; then
          if [[ "$line" =~ \} ]]; then
            in_extra_block=false
            continue
          fi
          
          if [[ "$line" =~ set\([[:space:]]*\"([a-zA-Z0-9_]+Version)\"[[:space:]]*,[[:space:]]*\"([^\"]+)\" ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${BASH_REMATCH[2]}"
            
            # Adicionar ao JSON
            if ! $first; then
              variables="$variables,"
            else
              first=false
            fi
            variables="$variables\"$var_name\":\"$var_value\""
            
            log_debug "Extraída variável do bloco extra do Kotlin DSL: $var_name = $var_value"
          fi
        fi
      done <<< "$file_content"
    fi
  done
  
  # Fechar o JSON
  variables="$variables}"
  
  echo "$variables"
}

# Resolva uma variável de versão usando o contexto do projeto
resolve_version_variable() {
  local variable="$1"           # A variável a ser resolvida (ex: $kotlinVersion)
  local project_dir="$2"        # Diretório do projeto
  local project_context="$3"    # Contexto do projeto em formato JSON
  
  # Verificar se é uma variável
  if [[ ! "$variable" =~ ^\$.*$ ]] && [[ ! "$variable" =~ ^\$\{.*\}$ ]] && [[ ! "$variable" =~ \$\{\{property ]]; then
    echo "$variable"  # Retornar o valor original se não for uma variável
    return 0
  fi
  
  # Extrair o nome da variável removendo $ ou ${...} ou ${property(...)}
  local var_name
  local is_kotlin_property=false
  
  if [[ "$variable" =~ ^\$\{(.*)\}$ ]]; then
    var_name="${BASH_REMATCH[1]}"
  elif [[ "$variable" =~ ^\$(.*) ]]; then
    var_name="${BASH_REMATCH[1]}"
  elif [[ "$variable" =~ \$\{\{property\([\"\'](.*)[\"\']\) ]]; then
    var_name="${BASH_REMATCH[1]}"
    is_kotlin_property=true
  else
    echo "$variable"  # Não é uma variável no formato esperado
    return 1
  fi
  
  log_debug "Tentando resolver variável: $var_name para o projeto no diretório $project_dir"
  
  # Se for uma variável do tipo property() do Kotlin DSL, buscar diretamente no gradle.properties
  if [ "$is_kotlin_property" = true ] && [ -f "$project_dir/gradle.properties" ]; then
    local prop_value=$(grep -E "^${var_name}\\s*=" "$project_dir/gradle.properties" | cut -d'=' -f2- | tr -d ' ' 2>/dev/null)
    if [ -n "$prop_value" ]; then
      log_debug "Variável Kotlin DSL $var_name resolvida diretamente do gradle.properties: $prop_value"
      echo "$prop_value"
      return 0
    fi
  fi
  
  # 1. Tentar resolver usando o contexto do projeto
  if [ -n "$project_context" ]; then
    # Verificar se o contexto contém a variável diretamente
    local direct_match=$(echo "$project_context" | jq -r ".$var_name // empty" 2>/dev/null)
    if [ -n "$direct_match" ]; then
      log_debug "Variável $var_name resolvida pelo contexto do projeto: $direct_match"
      echo "$direct_match"
      return 0
    fi
  fi
  
  # 2. Tentar encontrar em gradle.properties
  if [ -f "$project_dir/gradle.properties" ]; then
    local gradle_value=$(grep -E "^$var_name\s*=" "$project_dir/gradle.properties" | cut -d'=' -f2- | tr -d ' ' 2>/dev/null)
    if [ -n "$gradle_value" ]; then
      log_debug "Variável $var_name resolvida pelo gradle.properties: $gradle_value"
      echo "$gradle_value"
      return 0
    fi
  fi
  
  # 3. Tentar encontrar em build.gradle
  if [ -f "$project_dir/build.gradle" ]; then
    # Buscar em ext block
    local ext_match=$(grep -oP "ext\s*\{[^}]*$var_name\s*=\s*['\"]\\K[^'\"]*" "$project_dir/build.gradle" 2>/dev/null)
    if [ -n "$ext_match" ]; then
      log_debug "Variável $var_name resolvida pelo ext block do build.gradle: $ext_match"
      echo "$ext_match"
      return 0
    fi
    
    # Buscar em definições def
    local def_match=$(grep -E "def\s+$var_name\s*=\s*['\"]([^'\"]+)['\"]" "$project_dir/build.gradle" | sed -E "s/.*['\"]([^'\"]+)['\"].*/\\1/" 2>/dev/null)
    if [ -n "$def_match" ]; then
      log_debug "Variável $var_name resolvida por definição def no build.gradle: $def_match"
      echo "$def_match"
      return 0
    fi
    
    # Buscar por atribuição direta
    local direct_assign=$(grep -E "$var_name\s*=\s*['\"]([^'\"]+)['\"]" "$project_dir/build.gradle" | sed -E "s/.*['\"]([^'\"]+)['\"].*/\\1/" 2>/dev/null)
    if [ -n "$direct_assign" ]; then
      log_debug "Variável $var_name resolvida por atribuição direta no build.gradle: $direct_assign"
      echo "$direct_assign"
      return 0
    fi
  fi
  
  # 4. Verificar variáveis especiais do projeto
  case "$var_name" in
    kotlinVersion)
      # Tentar usar a versão do Kotlin do projeto
      if [ -n "$project_context" ]; then
        local kotlin_version=$(echo "$project_context" | jq -r '.kotlinVersion // empty' 2>/dev/null)
        if [ -n "$kotlin_version" ]; then
          log_debug "Variável $var_name resolvida usando kotlinVersion do projeto: $kotlin_version"
          echo "$kotlin_version"
          return 0
        fi
      fi
      ;;
    springBootVersion)
      # Tentar usar a versão do Spring Boot do projeto
      if [ -n "$project_context" ]; then
        local spring_version=$(echo "$project_context" | jq -r '.springBootVersion // empty' 2>/dev/null)
        if [ -n "$spring_version" ]; then
          log_debug "Variável $var_name resolvida usando springBootVersion do projeto: $spring_version"
          echo "$spring_version"
          return 0
        fi
      fi
      ;;
    oracleDriverVersion)
      # Valores comuns para Oracle Driver
      log_debug "Resolvendo variável oracleDriverVersion com valor padrão"
      echo "19.8.0.0"
      return 0
      ;;
    jjwtVersion)
      # Valores comuns para JJWT
      log_debug "Resolvendo variável jjwtVersion com valor padrão"
      echo "0.11.5"
      return 0
      ;;
    swaggerVersion)
      # Valores comuns para Swagger/SpringFox
      log_debug "Resolvendo variável swaggerVersion com valor padrão"
      echo "2.10.0"
      return 0
      ;;
  esac
  
  # 5. Tentar encontrar em convenções comuns de nomenclatura
  if [[ "$var_name" =~ (.+)Version$ ]]; then
    local base_name="${BASH_REMATCH[1]}"
    
    # Converter para kebab-case e verificar em gradle.properties
    local kebab_name=$(echo "$base_name" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1-\2/g' | tr '[:upper:]' '[:lower:]')
    if [ -f "$project_dir/gradle.properties" ]; then
      local kebab_value=$(grep -E "^${kebab_name}\.version\s*=" "$project_dir/gradle.properties" | cut -d'=' -f2- | tr -d ' ' 2>/dev/null)
      if [ -n "$kebab_value" ]; then
        log_debug "Variável $var_name resolvida usando convenção kebab-case: $kebab_value"
        echo "$kebab_value"
        return 0
      fi
    fi
  fi
  
  log_warn "Não foi possível resolver a variável $var_name"
  echo "\${$var_name}" # Manter a referência para processamento no frontend
  return 1
}

# Extrair dependências de um projeto
extract_dependencies() {
  local project_dir="$1"
  local project_context="$2"
  local dependencies_json="[]"
  
  # Procurar arquivos de construção
  local build_files=(
    "$project_dir/build.gradle"
    "$project_dir/build.gradle.kts"
    "$project_dir/pom.xml"
  )
  
  # Arrays para coletar todas as dependências
  local all_deps=()
  
  # Criar um contexto de projeto para resolver variáveis
  if [ -z "$project_context" ]; then
    project_context="{}"
  fi
  
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
          done < <(parse_gradle_dependencies "$build_file" "$version_vars" "$project_dir" "$project_context")
          
          # Version catalogs
          if [ -d "$project_dir/gradle" ]; then
            local catalog_files=($(find "$project_dir/gradle" -name "*.toml" -o -name "*.properties" 2>/dev/null))
            for catalog_file in "${catalog_files[@]}"; do
              while read -r dep; do
                if [ -n "$dep" ]; then
                  all_deps+=("$dep")
                fi
              done < <(parse_gradle_catalog "$catalog_file" "$project_dir" "$project_context")
            done
          fi
          ;;
          
        xml)
          # Dependências Maven
          while read -r dep; do
            if [ -n "$dep" ]; then
              all_deps+=("$dep")
            fi
          done < <(parse_maven_dependencies "$build_file" "$project_dir" "$project_context")
          ;;
      esac
    fi
  done
  
  # Construir o JSON de saída
  if [ ${#all_deps[@]} -gt 0 ]; then
    dependencies_json="["
    local first=true
    
    for dep in "${all_deps[@]}"; do
      # Verificar se é uma string não vazia
      if [ -z "$dep" ]; then
        continue
      fi
      
      # Limpar possíveis caracteres de quebra de linha que podem corromper o JSON
      dep=$(echo "$dep" | tr -d '\r' | tr -d '\n')
      
      # Filtrar entradas inválidas - garantir que não há mensagens de log misturadas
      if [[ "$dep" == "{"* && "$dep" == *"}" ]]; then
        # Verificar se a entrada parece ser um objeto JSON de dependência válido
        if [[ "$dep" == *"\"group\""* && "$dep" == *"\"name\""* && "$dep" == *"\"version\""* ]]; then
          # Verificar se contém variáveis não resolvidas e resolvê-las
          if [[ "$dep" == *"\$"* ]]; then
            # Extrair a versão do objeto JSON de forma mais robusta
            local version=$(echo "$dep" | grep -oP '"version":\s*"\K[^"]+' || echo "")
            if [ -n "$version" ] && ([[ "$version" == \$* ]] || [[ "$version" == *\$\{*\}* ]]); then
              # Resolver a variável
              local resolved_version=$(resolve_version_variable "$version" "$project_dir" "$project_context")
              if [ -n "$resolved_version" ] && [ "$resolved_version" != "$version" ]; then
                # Substituir a versão no objeto JSON de forma mais segura
                dep=$(echo "$dep" | sed "s/\"version\":\s*\"$version\"/\"version\":\"$resolved_version\"/")
                echo "Resolvida variável em dependência: $version -> $resolved_version" >> "$LOG_FILE" 2>&1
              fi
            fi
          fi
          
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
        # Corrigir JSON quebrado - tentar recuperar informações de diferentes formatos
        if [[ "$dep" =~ \"group\":\"([^\"]+)\".*\"name\":\"([^\"]+)\".*\"version\":\"([^\"]+) ]]; then
          local fixed_group="${BASH_REMATCH[1]}"
          local fixed_name="${BASH_REMATCH[2]}"
          local fixed_version="${BASH_REMATCH[3]}"
          local fixed_config="implementation"
          
          if [[ "$dep" =~ \"configuration\":\"([^\"]+) ]]; then
            fixed_config="${BASH_REMATCH[1]}"
          fi
          
          # Criar objeto JSON corrigido
          local fixed_dep="{\"group\":\"$fixed_group\",\"name\":\"$fixed_name\",\"version\":\"$fixed_version\",\"configuration\":\"$fixed_config\"}"
          echo "Corrigido objeto JSON quebrado: $dep -> $fixed_dep" >> "$LOG_FILE" 2>&1
          
          if ! $first; then
            dependencies_json="$dependencies_json,"
          else
            first=false
          fi
          dependencies_json="$dependencies_json$fixed_dep"
        # Verificar se é uma versão isolada (pode ser de uma tentativa de resolução anterior)
        elif [[ "$dep" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-zA-Z0-9.]+)?$ ]]; then
          # Ignorar versões isoladas, já devem ter sido incluídas em outro objeto
          echo "Ignorando versão isolada: $dep" >> "$LOG_FILE" 2>&1
        # Verificar se é um fragmento de JSON válido
        elif [[ "$dep" =~ \"(group|name|version|configuration)\":\"([^\"]+)\" ]]; then
          echo "Fragmento JSON detectado e ignorado: $dep" >> "$LOG_FILE" 2>&1
        else
          # Registrar entrada inválida no log
          echo "Ignorando entrada inválida que não é um objeto JSON: $dep" >> "$LOG_FILE" 2>&1
        fi
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
  local project_dir="$3"
  local project_context="$4"
  
  # Verificar se é um arquivo Kotlin DSL
  local is_kotlin_dsl=false
  if [[ "$build_file" == *".kts" ]]; then
    is_kotlin_dsl=true
    parse_kotlin_dsl_dependencies "$build_file" "$version_vars" "$project_dir" "$project_context"
    return
  fi
  
  grep -E "(implementation|api|compile|runtime|testImplementation|testCompile)" "$build_file" | while read -r line; do
    # Remover comentários
    line=$(echo "$line" | sed 's/\/\/.*$//g')
    
    # Formato padrão: implementation 'org.springframework:spring-core:5.2.0'
    if [[ "$line" =~ (implementation|api|compile|runtime|testImplementation|testCompile)[[:space:]]*[\(]?[[:space:]]*[\'\"]([^:\'\"]+):([^:\'\"]+):([^\'\"]+) ]]; then
      local config="${BASH_REMATCH[1]}"
      local group="${BASH_REMATCH[2]}"
      local name="${BASH_REMATCH[3]}"
      local version="${BASH_REMATCH[4]}"
      
      # Resolver a variável de versão se necessário
      if [[ "$version" == \$* ]]; then
        local resolved_version=$(resolve_version_variable "$version" "$project_dir" "$project_context")
        if [ -n "$resolved_version" ]; then
          version="$resolved_version"
        fi
      # Verificar se a versão é uma variável e substituí-la se necessário
      elif [[ "$version" =~ \$\{([a-zA-Z0-9_]+)\} ]]; then
        local var_name="${BASH_REMATCH[1]}"
        local var_value=$(echo "$version_vars" | grep -oP "\"$var_name\":\"\K[^\"]+")
        if [ -n "$var_value" ]; then
          version="$var_value"
        else
          # Tentar resolver usando a função resolve_version_variable
          local resolved_version=$(resolve_version_variable "$version" "$project_dir" "$project_context")
          if [ -n "$resolved_version" ] && [ "$resolved_version" != "\${$var_name}" ]; then
            version="$resolved_version"
          fi
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
        elif [[ "$version" == \$* ]] || [[ "$version" =~ \$\{.*\} ]]; then
          # Tentar resolver a variável de versão
          local resolved_version=$(resolve_version_variable "$version" "$project_dir" "$project_context")
          if [ -n "$resolved_version" ] && [ "$resolved_version" != "$version" ]; then
            version="$resolved_version"
          fi
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
          else
            local resolved_version=$(resolve_version_variable "$var_version" "$project_dir" "$project_context")
            if [ -n "$resolved_version" ] && [ "$resolved_version" != "$var_version" ]; then
              version="$resolved_version"
            fi
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

# Analisar dependências do Kotlin DSL (build.gradle.kts)

# Analisar catálogos de versão do Gradle
parse_gradle_catalog() {
  local catalog_file="$1"
  local project_dir="$2"
  local project_context="$3"
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
          elif [[ "$version" == \$* ]] || [[ "$version" =~ \$\{.*\} ]]; then
            # Tentar resolver como variável
            local resolved_version=$(resolve_version_variable "$version" "$project_dir" "$project_context")
            if [ -n "$resolved_version" ] && [ "$resolved_version" != "$version" ]; then
              version="$resolved_version"
            fi
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
  local project_dir="$2"
  local project_context="$3"
  local in_dependencies=0
  local current_group=""
  local current_artifact=""
  local current_version=""
  local current_scope="compile"
  
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
          else
            # Tentar resolver usando a função resolve_version_variable
            local resolved_version=$(resolve_version_variable "$current_version" "$project_dir" "$project_context")
            if [ -n "$resolved_version" ] && [ "$resolved_version" != "\${$prop_name}" ]; then
              current_version="$resolved_version"
            fi
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

# Extrair todas as propriedades do gradle.properties
extract_gradle_properties() {
  local project_dir="$1"
  local properties_file="$project_dir/gradle.properties"
  local properties="{}"
  
  if [ -f "$properties_file" ]; then
    echo "Lendo propriedades de $properties_file" >> "$LOG_FILE" 2>&1
    
    while IFS= read -r line; do
      # Ignorar linhas vazias e comentários
      if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
        continue
      fi
      
      # Extrair pares chave=valor
      if [[ "$line" =~ ^([a-zA-Z0-9_.]+)[[:space:]]*=[[:space:]]*(.*) ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        
        # Remover espaços em branco e comentários
        value=$(echo "$value" | sed 's/#.*$//' | tr -d ' ')
        
        # Adicionar à string de propriedades (simples)
        properties="$properties\"$key\":\"$value\","
        echo "Extraída propriedade: $key = $value" >> "$LOG_FILE" 2>&1
      fi
    done < "$properties_file"
    
    # Remover a última vírgula e fechar o objeto JSON
    properties="${properties%,}"
    properties="{$properties}"
  fi
  
  echo "$properties"
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
# Analisar dependências do Kotlin DSL (build.gradle.kts)
parse_kotlin_dsl_dependencies() {
  local build_file="$1"
  local version_vars="$2"
  local project_dir="$3"
  local project_context="$4"
  
  # Primeiro extrair variáveis específicas do Kotlin DSL e do gradle.properties
  local kotlin_dsl_vars="{}"
  local gradle_properties=$(extract_gradle_properties "$project_dir")
  
  # Criar um array associativo para as propriedades gradle
  declare -A props
  
  # Carregar propriedades do gradle.properties
  if [ -f "$project_dir/gradle.properties" ]; then
    while IFS='=' read -r key value; do
      # Ignorar linhas vazias ou comentários
      [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
      
      # Remover espaços em branco
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)
      
      # Armazenar no array
      props["$key"]="$value"
      log_debug "Propriedade gradle carregada: $key = $value"
    done < "$project_dir/gradle.properties"
  fi
  
  # Procurar por padrões como val kotlinVersion = "1.7.10"
  while IFS= read -r line; do
    if [[ "$line" =~ (val|const|var)[[:space:]]+([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      local var_name="${BASH_REMATCH[2]}"
      local var_value="${BASH_REMATCH[3]}"
      
      # Adicionar ao objeto JSON
      kotlin_dsl_vars=$(echo "$kotlin_dsl_vars" | jq --arg name "$var_name" --arg value "$var_value" '. + {($name): $value}' 2>/dev/null || echo "$kotlin_dsl_vars")
      
      # Adicionar também ao array props para uso posterior
      props["$var_name"]="$var_value"
    fi
  done < "$build_file"
  
  log_debug "Variáveis extraídas do Kotlin DSL: $kotlin_dsl_vars"
  log_debug "Propriedades extraídas do gradle.properties: $gradle_properties"
  
  # Em arquivos Kotlin DSL, dependências podem usar property()
  grep -E "(implementation|api|compile|runtime|testImplementation|testCompile)" "$build_file" | while read -r line; do
    # Remover comentários
    line=$(echo "$line" | sed 's/\/\/.*$//g')
    
    # Formato padrão Kotlin DSL: implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:$kotlinVersion")
    if [[ "$line" =~ (implementation|api|compileOnly|runtimeOnly|testImplementation|testCompile)[[:space:]]*[\(][\"\']([^:\"\']+):([^:\"\']+):([^\)\"]*)[\"\']? ]]; then
      local config="${BASH_REMATCH[1]}"
      local group="${BASH_REMATCH[2]}"
      local name="${BASH_REMATCH[3]}"
      local raw_version="${BASH_REMATCH[4]}"
      local version="$raw_version"
      
      # Limpar versão removendo aspas extras e curly braces
      version=$(echo "$version" | tr -d '"' | tr -d "'" | sed 's/}$//' | sed 's/)$//')
      
      # Detectar diferentes formatos de referência a propriedades/variáveis no Kotlin DSL
      
      # Formato property("name")
      if echo "$raw_version" | grep -q "property("; then
        # Extrair o nome da propriedade
        local prop_name=$(echo "$raw_version" | grep -oP 'property\(\s*["\x27]\K[^"\x27]+')
        if [ -n "$prop_name" ]; then
          # Verificar no array de propriedades
          if [ -n "${props[$prop_name]}" ]; then
            version="${props[$prop_name]}"
            log_debug "Propriedade property() $prop_name resolvida: $version"
          # Buscar em gradle.properties como fallback
          elif [ -f "$project_dir/gradle.properties" ]; then
            local prop_value=$(grep -E "^${prop_name}\\s*=" "$project_dir/gradle.properties" | cut -d'=' -f2- | tr -d ' ' 2>/dev/null)
            if [ -n "$prop_value" ]; then
              version="$prop_value"
              log_debug "Propriedade property() $prop_name do gradle.properties: $version"
            fi
          fi
        fi
      # Formato libs.xxx.get() do Gradle Version Catalog 
      elif [[ "$raw_version" =~ libs\.([a-zA-Z0-9_.]+)\.get\(\) ]]; then
        local lib_name="${BASH_REMATCH[1]}"
        
        # Procurar em arquivos TOML de version catalog
        if [ -d "$project_dir/gradle" ]; then
          local toml_files=($(find "$project_dir/gradle" -name "*.toml" 2>/dev/null))
          for toml_file in "${toml_files[@]}"; do
            local version_value=$(grep -A50 "^\[versions\]" "$toml_file" | grep -m1 "$lib_name" | grep -oP '=\s*"\K[^"]+')
            if [ -n "$version_value" ]; then
              version="$version_value"
              break
            fi
          done
        fi
      # Se for uma variável direta do Kotlin ${varName} ou $varName
      elif [[ "$version" == \$* ]]; then
        # Extrair nome da variável
        local var_name=""
        if [[ "$version" =~ \$\{([a-zA-Z0-9_]+)\} ]]; then
          var_name="${BASH_REMATCH[1]}"
        elif [[ "$version" =~ \$([a-zA-Z0-9_]+) ]]; then
          var_name="${BASH_REMATCH[1]}"
        fi
        
        if [ -n "$var_name" ]; then
          log_debug "Tentando resolver variável Kotlin DSL: $var_name de versão $version"
          
          # Verificar no array de propriedades primeiro
          if [ -n "${props[$var_name]}" ]; then
            version="${props[$var_name]}"
            log_debug "Variável $var_name resolvida do array de propriedades: $version"
          elif [ -f "$project_dir/gradle.properties" ]; then
            # Buscar diretamente do gradle.properties como fallback
            local prop_value=$(grep -E "^${var_name}\\s*=" "$project_dir/gradle.properties" | cut -d'=' -f2- | tr -d ' ' 2>/dev/null)
            if [ -n "$prop_value" ]; then
              version="$prop_value"
              log_debug "Variável $var_name resolvida do gradle.properties: $version"
            fi
          fi
        fi
      fi
      
      # Se ainda não resolvemos a versão e ela parece ser uma variável
      if [[ "$version" == \$* ]]; then
        log_debug "Ainda precisa resolver variável: $version"
        # Extrair nome da variável para log
        local var_display=""
        if [[ "$version" =~ \$\{([a-zA-Z0-9_]+)\} ]]; then
          var_display="${BASH_REMATCH[1]}"
        elif [[ "$version" =~ \$([a-zA-Z0-9_]+) ]]; then
          var_display="${BASH_REMATCH[1]}"
        fi
        
        # Tentativa final usando o array de propriedades
        if [ -n "$var_display" ] && [ -n "${props[$var_display]}" ]; then
          version="${props[$var_display]}"
          log_debug "Variável $var_display resolvida na tentativa final: $version"
        else
          log_debug "Não foi possível resolver a variável $var_display"
        fi
      fi
      
      # Registrar a dependência encontrada e sua configuração
      log_debug "Dependência: $config - $group:$name:$version"
      
      echo "{\"group\":\"$group\",\"name\":\"$name\",\"version\":\"$version\",\"configuration\":\"$config\"}"
    fi
  done
}
