#!/bin/bash

# Script para extrair dependências de projetos Java/Kotlin com Gradle
# Autor: Thales Nunes 
# Data: 16/05/2025

# Configurações
OUTPUT_FILE="data/dependencies.json"
TEMP_DIR=$(mktemp -d)
REPOS_DIR="$TEMP_DIR/repos"
mkdir -p "$REPOS_DIR"
mkdir -p "data"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir mensagens
log() {
  echo -e "${BLUE}[INFO]${NC} $1" >&2
}

error() {
  echo -e "${RED}[ERRO]${NC} $1" >&2
}

success() {
  echo -e "${GREEN}[SUCESSO]${NC} $1" >&2
}

warning() {
  echo -e "${YELLOW}[AVISO]${NC} $1" >&2
}

# Função para limpar ao sair
cleanup() {
  log "Limpando arquivos temporários..."
  rm -rf "$TEMP_DIR"
}

# Registrar função de limpeza para ser executada ao sair
trap cleanup EXIT

# Verificar dependências
check_dependencies() {
  log "Verificando dependências necessárias..."
  
  if ! command -v git &> /dev/null; then
    error "Git não encontrado. Por favor, instale o Git."
    exit 1
  fi
  
  if ! command -v grep &> /dev/null || ! command -v sed &> /dev/null; then
    error "Ferramentas de processamento de texto (grep/sed) não encontradas."
    exit 1
  fi
  
  if ! command -v jq &> /dev/null; then
    warning "jq não encontrado. O JSON de saída não será formatado."
  fi
  
  success "Todas as dependências necessárias estão instaladas."
}

# Clonar repositório
clone_repo() {
  local repo_url="$1"
  local repo_name=$(basename "$repo_url" .git)
  local target_dir="$REPOS_DIR/$repo_name"
  
  log "Clonando repositório: $repo_url"
  
  if git clone --depth 1 "$repo_url" "$target_dir" 2>/dev/null; then
    success "Repositório clonado com sucesso: $repo_name"
    echo "$target_dir"
  else
    error "Falha ao clonar repositório: $repo_url"
    return 1
  fi
}

# Extrair versão do Java
extract_java_version() {
  local project_dir="$1"
  
  log "Extraindo versão do Java para: $(basename "$project_dir")"
  
  # Tentar encontrar em gradle.properties
  if [ -f "$project_dir/gradle.properties" ]; then
    local java_version=$(grep -E "java(Version|\.version)" "$project_dir/gradle.properties" | sed -E 's/.*=\s*([0-9]+).*/\1/g')
    if [ -n "$java_version" ]; then
      echo "$java_version"
      return 0
    fi
  fi
  
  # Tentar encontrar em build.gradle ou build.gradle.kts
  for build_file in "$project_dir/build.gradle" "$project_dir/build.gradle.kts"; do
    if [ -f "$build_file" ]; then
      # Procurar por sourceCompatibility = JavaVersion.VERSION_XX
      local java_version=$(grep -E "sourceCompatibility\s*=\s*JavaVersion\.VERSION_([0-9]+)" "$build_file" | sed -E 's/.*VERSION_([0-9]+).*/\1/g')
      if [ -n "$java_version" ]; then
        echo "$java_version"
        return 0
      fi
      
      # Procurar por java { version = 'XX' }
      java_version=$(grep -E "java\s+{[^}]*version\s*=\s*['\"]([0-9]+)['\"]" "$build_file" | sed -E "s/.*version\s*=\s*['\"]([0-9]+)['\"].*/\1/g")
      if [ -n "$java_version" ]; then
        echo "$java_version"
        return 0
      fi
      
      # Procurar por JavaLanguageVersion.of(XX)
      java_version=$(grep -E "JavaLanguageVersion\.of\(([0-9]+)\)" "$build_file" | sed -E 's/.*of\(([0-9]+)\).*/\1/g')
      if [ -n "$java_version" ]; then
        echo "$java_version"
        return 0
      fi
    fi
  done
  
  # Não definir valor padrão, permitindo que o campo apareça como null no JSON
  # Isso é melhor que assumir uma versão específica que pode não ser compatível
  log "Não foi possível detectar a versão do Java para: $(basename "$project_dir"). Será marcado como não disponível."
  echo ""
}

# Extrair versão do Kotlin
extract_kotlin_version() {
  local project_dir="$1"
  
  log "Extraindo versão do Kotlin para: $(basename "$project_dir")"
  
  # Tentar encontrar em gradle.properties
  if [ -f "$project_dir/gradle.properties" ]; then
    local kotlin_version=$(grep -E "kotlin(Version|\.version)" "$project_dir/gradle.properties" | sed -E 's/.*=\s*([0-9]+\.[0-9]+\.[0-9]+).*/\1/g')
    if [ -n "$kotlin_version" ]; then
      echo "$kotlin_version"
      return 0
    fi
  fi
  
  # Tentar encontrar em build.gradle ou build.gradle.kts
  for build_file in "$project_dir/build.gradle" "$project_dir/build.gradle.kts"; do
    if [ -f "$build_file" ]; then
      # Procurar por kotlin { version = 'X.Y.Z' }
      local kotlin_version=$(grep -E "kotlin\s+{[^}]*version\s*=\s*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"]" "$build_file" | sed -E "s/.*version\s*=\s*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"].*/\1/g")
      if [ -n "$kotlin_version" ]; then
        echo "$kotlin_version"
        return 0
      fi
      
      # Procurar por kotlin plugin version 'X.Y.Z'
      kotlin_version=$(grep -E "kotlin[\"']?\s+version\s+['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"]" "$build_file" | sed -E "s/.*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"].*/\1/g")
      if [ -n "$kotlin_version" ]; then
        echo "$kotlin_version"
        return 0
      fi
      
      # Procurar por ext.kotlin_version = 'X.Y.Z'
      kotlin_version=$(grep -E "ext\.kotlin_version\s*=\s*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"]" "$build_file" | sed -E "s/.*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"].*/\1/g")
      if [ -n "$kotlin_version" ]; then
        echo "$kotlin_version"
        return 0
      fi
    fi
  done
  
  # Não definir valor padrão, permitindo que o campo apareça como null no JSON
  log "Não foi possível detectar a versão do Kotlin para: $(basename "$project_dir"). Será marcado como não disponível."
  echo ""
}

# Extrair versão do Gradle
extract_gradle_version() {
  local project_dir="$1"
  
  log "Extraindo versão do Gradle para: $(basename "$project_dir")"
  
  # Verificar arquivo gradle/wrapper/gradle-wrapper.properties
  if [ -f "$project_dir/gradle/wrapper/gradle-wrapper.properties" ]; then
    local gradle_version=$(grep "distributionUrl" "$project_dir/gradle/wrapper/gradle-wrapper.properties" | sed -E 's/.*gradle-([0-9]+\.[0-9]+(\.[0-9]+)?)-bin.*/\1/g')
    if [ -n "$gradle_version" ]; then
      echo "$gradle_version"
      return 0
    fi
  fi
  
  # Não definir valor padrão, permitindo que o campo apareça como null no JSON
  log "Não foi possível detectar a versão do Gradle para: $(basename "$project_dir"). Será marcado como não disponível."
  echo ""
}

# Extrair versão do Spring Boot
extract_spring_boot_version() {
  local project_dir="$1"
  
  log "Extraindo versão do Spring Boot para: $(basename "$project_dir")"
  
  # Tentar encontrar em gradle.properties
  if [ -f "$project_dir/gradle.properties" ]; then
    local spring_boot_version=$(grep -E "spring-boot(Version|\.version)" "$project_dir/gradle.properties" | sed -E 's/.*=\s*([0-9]+\.[0-9]+\.[0-9]+).*/\1/g')
    if [ -n "$spring_boot_version" ]; then
      echo "$spring_boot_version"
      return 0
    fi
  fi
  
  # Tentar encontrar em build.gradle ou build.gradle.kts
  for build_file in "$project_dir/build.gradle" "$project_dir/build.gradle.kts"; do
    if [ -f "$build_file" ]; then
      # Procurar por spring-boot version 'X.Y.Z'
      local spring_boot_version=$(grep -E "spring-boot[\"']?\s+version\s+['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"]" "$build_file" | sed -E "s/.*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"].*/\1/g")
      if [ -n "$spring_boot_version" ]; then
        echo "$spring_boot_version"
        return 0
      fi
      
      # Procurar por org.springframework.boot version 'X.Y.Z'
      spring_boot_version=$(grep -E "org\.springframework\.boot[\"']?\s+version\s+['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"]" "$build_file" | sed -E "s/.*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"].*/\1/g")
      if [ -n "$spring_boot_version" ]; then
        echo "$spring_boot_version"
        return 0
      fi
      
      # Procurar por springBootVersion = 'X.Y.Z'
      spring_boot_version=$(grep -E "springBootVersion\s*=\s*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"]" "$build_file" | sed -E "s/.*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"].*/\1/g")
      if [ -n "$spring_boot_version" ]; then
        echo "$spring_boot_version"
        return 0
      fi
    fi
  done
  
  # Procurar no pom.xml para projetos que usam Maven
  if [ -f "$project_dir/pom.xml" ]; then
    local spring_boot_version=$(grep -E "<spring-boot\.version>([0-9]+\.[0-9]+\.[0-9]+)" "$project_dir/pom.xml" | sed -E "s/.*<spring-boot\.version>([0-9]+\.[0-9]+\.[0-9]+).*/\1/g")
    if [ -n "$spring_boot_version" ]; then
      echo "$spring_boot_version"
      return 0
    fi
    
    # Tentar parent version em projetos Spring Boot Maven
    spring_boot_version=$(grep -E "<parent>.*<artifactId>spring-boot-starter-parent<\/artifactId>.*<version>([0-9]+\.[0-9]+\.[0-9]+)" -A 3 "$project_dir/pom.xml" | grep -E "<version>([0-9]+\.[0-9]+\.[0-9]+)" | sed -E "s/.*<version>([0-9]+\.[0-9]+\.[0-9]+).*/\1/g")
    if [ -n "$spring_boot_version" ]; then
      echo "$spring_boot_version"
      return 0
    fi
  fi
  
  # Não definir valor padrão, permitindo que o campo apareça como null no JSON
  log "Não foi possível detectar a versão do Spring Boot para: $(basename "$project_dir"). Será marcado como não disponível."
  echo ""
}

# Extrair variáveis de versão
extract_version_variables() {
  local project_dir="$1"
  local variables=()
  
  log "Extraindo variáveis de versão para: $(basename "$project_dir")"
  
  # Verificar em gradle.properties
  if [ -f "$project_dir/gradle.properties" ]; then
    log "Analisando variáveis em gradle.properties"
    while IFS= read -r line; do
      # Ignorar linhas de comentário e vazias
      if [[ ! "$line" =~ ^[[:space:]]*# && -n "$line" ]]; then
        # Extrair variáveis no formato chave=valor
        if [[ "$line" =~ ^([^=]+)=(.+)$ ]]; then
          local key="${BASH_REMATCH[1]}"
          local value="${BASH_REMATCH[2]}"
          # Remover espaços em branco
          key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
          value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
          # Adicionar par chave-valor ao resultado
          variables+=("{\"name\":\"$key\",\"value\":\"$value\"}")
        fi
      fi
    done < "$project_dir/gradle.properties"
  fi
  
  # Verificar variáveis em build.gradle ou build.gradle.kts
  for build_file in "$project_dir/build.gradle" "$project_dir/build.gradle.kts"; do
    if [ -f "$build_file" ]; then
      log "Analisando variáveis em $build_file"
      
      # Extrair definições de variáveis no formato "ext.varName = 'value'" ou "val varName = 'value'"
      while IFS= read -r line; do
        # Remover espaços em branco
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        # Padrão ext.varName = 'value' ou ext['varName'] = 'value'
        if [[ "$line" =~ ^ext\.([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*[\'\"](.*)[\'|\"] ]]; then
          local key="${BASH_REMATCH[1]}"
          local value="${BASH_REMATCH[2]}"
          variables+=("{\"name\":\"$key\",\"value\":\"$value\"}")
        elif [[ "$line" =~ ^ext\[[\'|\"]([a-zA-Z0-9_]+)[\'|\"]\][[:space:]]*=[[:space:]]*[\'\"](.*)[\'|\"] ]]; then
          local key="${BASH_REMATCH[1]}"
          local value="${BASH_REMATCH[2]}"
          variables+=("{\"name\":\"$key\",\"value\":\"$value\"}")
        # Padrão val/var/const varName = 'value' (Kotlin)
        elif [[ "$line" =~ ^(val|var|const)[[:space:]]+([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*[\'\"](.*)[\'|\"] ]]; then
          local key="${BASH_REMATCH[2]}"
          local value="${BASH_REMATCH[3]}"
          variables+=("{\"name\":\"$key\",\"value\":\"$value\"}")
        fi
      done < <(grep -E "^[[:space:]]*(ext\.|val |var |const )" "$build_file")
      
      # Extrair variáveis em blocos extra ou plugins
      # Este é um padrão comum em arquivos build.gradle
      local in_extra_block=0
      local current_block=""
      while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*extra[[:space:]]*\{ ]]; then
          in_extra_block=1
          current_block="extra"
          continue
        elif [[ "$line" =~ ^[[:space:]]*\} ]]; then
          if [ $in_extra_block -eq 1 ]; then
            in_extra_block=0
            current_block=""
          fi
          continue
        fi
        
        if [ $in_extra_block -eq 1 ]; then
          # Extrair variáveis dentro do bloco extra
          if [[ "$line" =~ [[:space:]]*([a-zA-Z0-9_.]+)[[:space:]]*=[[:space:]]*[\'\"](.*)[\'|\"] ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            variables+=("{\"name\":\"$key\",\"value\":\"$value\"}")
          fi
        fi
      done < "$build_file"
    fi
  done
  
  # Retornar array de variáveis como JSON
  if [ ${#variables[@]} -eq 0 ]; then
    echo "[]"
  else
    local vars_json=$(printf '%s,' "${variables[@]}" | sed 's/,$//')
    echo "[$vars_json]"
  fi
}

# Extrair dependências
extract_dependencies() {
  local project_dir="$1"
  local dependencies=()
  local version_variables=$(extract_version_variables "$project_dir")

  log "Extraindo dependências para: $(basename "$project_dir")"

  # Processar build.gradle ou build.gradle.kts
  for build_file in "$project_dir/build.gradle" "$project_dir/build.gradle.kts"; do
    if [ -f "$build_file" ]; then
      log "Processando arquivo: $build_file"
      
      # Processar linhas que provavelmente contêm declarações de dependência
      while IFS= read -r line; do
        # Normalizar espaços e remover espaços extras
        line=$(echo "$line" | sed -E 's/^\s+//g; s/\s+$//g')
        
        # Extrair tipo de configuração (ex: implementation, api)
        local configuration=$(echo "$line" | sed -E 's/^\s*([a-zA-Z]+).*/\1/')
        
        # Extrair string G:N:V (ex: "grupo:nome:versão" ou 'grupo:nome:versão')
        # Captura diferentes formatos de declaração de dependências
        if echo "$line" | grep -qE "['\"]([^:]+:[^:]+:[^'\"]+)['\"]"; then
          # Formato padrão "group:name:version"
          local gnv_string=$(echo "$line" | grep -Eo "['\"]([^:]+:[^:]+:[^'\"]+)['\"]" | sed -E "s/['\"]//g")
          
          if [ -n "$gnv_string" ]; then
            local group=$(echo "$gnv_string" | cut -d: -f1)
            local name=$(echo "$gnv_string" | cut -d: -f2)
            # Versão é tudo após o segundo dois-pontos
            local version=$(echo "$gnv_string" | cut -d: -f3-)
            
            if [ -n "$group" ] && [ -n "$name" ] && [ -n "$version" ]; then
              # Verificar se a versão contém uma variável ${varName}
              local original_version=""
              local resolved_version="$version"
              local has_variable=0
              
              if [[ "$version" =~ \$\{([a-zA-Z0-9_.]+)\} ]]; then
                has_variable=1
                original_version="$version"
                local var_name="${BASH_REMATCH[1]}"
                # Tentar resolver a variável usando o JSON de variáveis extraídas
                if [ -n "$version_variables" ] && [ "$version_variables" != "[]" ]; then
                  # Extrair valor da variável usando jq se disponível, ou grep+sed se não
                  if command -v jq &> /dev/null; then
                    local var_value=$(echo "$version_variables" | jq -r ".[] | select(.name==\"$var_name\") | .value" 2>/dev/null)
                    if [ -n "$var_value" ] && [ "$var_value" != "null" ]; then
                      resolved_version="$var_value"
                    fi
                  else
                    # Fallback para grep+sed se jq não estiver disponível
                    local var_pattern="\"name\":\"$var_name\",\"value\":\"([^\"]+)\""
                    if [[ "$version_variables" =~ $var_pattern ]]; then
                      resolved_version="${BASH_REMATCH[1]}"
                    fi
                  fi
                fi
              fi
              
              # Escapar a linha original para JSON e criar versão resolvida
              local escaped_line=$(echo "$line" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
              local resolved_declaration=$(echo "$line" | sed -e "s/\${$var_name}/$resolved_version/g" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
              
              # Criar objeto JSON da dependência (formato simplificado e padronizado)
              # Sempre usar o mesmo formato independentemente de ter variável ou não
              # Usar a declaration resolvida quando houver variável
              if [ $has_variable -eq 1 ]; then
                local dep="{\"group\":\"$group\",\"name\":\"$name\",\"version\":\"$resolved_version\",\"configuration\":\"$configuration\",\"declaration\":\"$resolved_declaration\"}"
              else
                local dep="{\"group\":\"$group\",\"name\":\"$name\",\"version\":\"$resolved_version\",\"configuration\":\"$configuration\",\"declaration\":\"$escaped_line\"}"
              fi
              dependencies+=("$dep")
            fi
          fi
        elif echo "$line" | grep -qE "group:.*name:.*version:"; then
          # Formato com group: name: version:
          local group=$(echo "$line" | grep -Eo "group:\s*['\"]([^'\"]+)['\"]" | sed -E "s/group:\s*['\"]([^'\"]+)['\"].*/\1/g")
          local name=$(echo "$line" | grep -Eo "name:\s*['\"]([^'\"]+)['\"]" | sed -E "s/name:\s*['\"]([^'\"]+)['\"].*/\1/g")
          local version=$(echo "$line" | grep -Eo "version:\s*['\"]([^'\"]+)['\"]" | sed -E "s/version:\s*['\"]([^'\"]+)['\"].*/\1/g")
          
          if [ -n "$group" ] && [ -n "$name" ] && [ -n "$version" ]; then
            # Verificar se a versão contém uma variável ${varName}
            local original_version=""
            local resolved_version="$version"
            local has_variable=0
            
            if [[ "$version" =~ \$\{([a-zA-Z0-9_.]+)\} ]]; then
              has_variable=1
              original_version="$version"
              local var_name="${BASH_REMATCH[1]}"
              # Tentar resolver a variável usando o JSON de variáveis extraídas
              if [ -n "$version_variables" ] && [ "$version_variables" != "[]" ]; then
                # Extrair valor da variável usando jq se disponível, ou grep+sed se não
                if command -v jq &> /dev/null; then
                  local var_value=$(echo "$version_variables" | jq -r ".[] | select(.name==\"$var_name\") | .value" 2>/dev/null)
                  if [ -n "$var_value" ] && [ "$var_value" != "null" ]; then
                    resolved_version="$var_value"
                  fi
                else
                  # Fallback para grep+sed se jq não estiver disponível
                  local var_pattern="\"name\":\"$var_name\",\"value\":\"([^\"]+)\""
                  if [[ "$version_variables" =~ $var_pattern ]]; then
                    resolved_version="${BASH_REMATCH[1]}"
                  fi
                fi
              fi
            fi
            
            # Escapar a linha original para JSON
            local escaped_line=$(echo "$line" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
            local resolved_declaration=$(echo "$line" | sed -e "s/\${$var_name}/$resolved_version/g" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
            
            # Criar objeto JSON da dependência (formato simplificado)
            local dep
            if [ $has_variable -eq 1 ]; then
              # Se usou variável, incluir originalVersion
              dep="{\"group\":\"$group\",\"name\":\"$name\",\"version\":\"$resolved_version\",\"originalVersion\":\"$original_version\",\"hasVariable\":$has_variable,\"configuration\":\"$configuration\",\"declaration\":\"$escaped_line\",\"resolvedDeclaration\":\"$resolved_declaration\"}"
            else
              # Caso contrário, formato mais simples
              dep="{\"group\":\"$group\",\"name\":\"$name\",\"version\":\"$resolved_version\",\"hasVariable\":$has_variable,\"configuration\":\"$configuration\",\"declaration\":\"$escaped_line\"}"
            fi
            dependencies+=("$dep")
          fi
        fi
      done < <(grep -E "^\s*(implementation|api|compileOnly|runtimeOnly|testImplementation|compile|testCompile|annotationProcessor|kapt|classpath)\s*[\(\"'[:space:]]" "$build_file" | sed -E 's/^\s+//g; s/\s+$//g')
    fi
  done
  
  # Processar pom.xml para projetos Maven
  if [ -f "$project_dir/pom.xml" ] && [ ${#dependencies[@]} -eq 0 ]; then
    log "Processando arquivo pom.xml"
    
    # Usar grep para extrair seções de dependência
    while IFS= read -r dep_section; do
      # Extrair informações da dependência
      local group=$(echo "$dep_section" | grep -E "<groupId>" | sed -E 's/.*<groupId>([^<]+)<\/groupId>.*/\1/g')
      local name=$(echo "$dep_section" | grep -E "<artifactId>" | sed -E 's/.*<artifactId>([^<]+)<\/artifactId>.*/\1/g')
      local version=$(echo "$dep_section" | grep -E "<version>" | sed -E 's/.*<version>([^<]+)<\/version>.*/\1/g')
      local scope=$(echo "$dep_section" | grep -E "<scope>" | sed -E 's/.*<scope>([^<]+)<\/scope>.*/\1/g')
      
      # Se não houver scope definido, assumir compile (padrão Maven)
      if [ -z "$scope" ]; then
        scope="compile"
      fi
      
      # Mapear scope Maven para configuração Gradle
      local configuration
      case "$scope" in
        compile) configuration="implementation" ;;
        runtime) configuration="runtimeOnly" ;;
        provided) configuration="compileOnly" ;;
        test) configuration="testImplementation" ;;
        *) configuration="$scope" ;;
      esac
      
      if [ -n "$group" ] && [ -n "$name" ]; then
        # Se versão estiver vazia, usar "managed" (gerenciada pelo parent)
        if [ -z "$version" ]; then
          version="managed"
        fi
        
        # Verificar se a versão contém uma variável ${varName}
        local original_version=""
        local resolved_version="$version"
        local has_variable=0
        
        if [[ "$version" =~ \$\{([a-zA-Z0-9_.]+)\} ]]; then
          has_variable=1
          original_version="$version"
          local var_name="${BASH_REMATCH[1]}"
          # Tentar resolver a variável usando o JSON de variáveis extraídas
          if [ -n "$version_variables" ] && [ "$version_variables" != "[]" ]; then
            # Extrair valor da variável usando jq se disponível, ou grep+sed se não
            if command -v jq &> /dev/null; then
              local var_value=$(echo "$version_variables" | jq -r ".[] | select(.name==\"$var_name\") | .value" 2>/dev/null)
              if [ -n "$var_value" ] && [ "$var_value" != "null" ]; then
                resolved_version="$var_value"
              fi
            else
              # Fallback para grep+sed se jq não estiver disponível
              local var_pattern="\"name\":\"$var_name\",\"value\":\"([^\"]+)\""
              if [[ "$version_variables" =~ $var_pattern ]]; then
                resolved_version="${BASH_REMATCH[1]}"
              fi
            fi
          fi
        fi
        
        # Declaração simulada em formato Gradle
        local declaration="$configuration(\"$group:$name:$version\")"
        local resolved_declaration="$configuration(\"$group:$name:$resolved_version\")"
        
        # Criar objeto JSON da dependência (formato simplificado e padronizado)
        # Sempre usar o mesmo formato independentemente de ter variável ou não
        # Usar a declaration resolvida quando houver variável
        if [ $has_variable -eq 1 ]; then
          local dep="{\"group\":\"$group\",\"name\":\"$name\",\"version\":\"$resolved_version\",\"configuration\":\"$configuration\",\"declaration\":\"$resolved_declaration\"}"
        else
          local dep="{\"group\":\"$group\",\"name\":\"$name\",\"version\":\"$resolved_version\",\"configuration\":\"$configuration\",\"declaration\":\"$declaration\"}"
        fi
        dependencies+=("$dep")
      fi
    done < <(grep -A 10 -E "<dependency>" "$project_dir/pom.xml" | tr '\n' ' ' | sed -E 's/<dependency>/\n<dependency>/g' | grep -E "<dependency>")
  fi

  # Retornar array de dependências como JSON
  if [ ${#dependencies[@]} -eq 0 ]; then
    echo "[]"
  else
    local deps_json=$(printf '%s,' "${dependencies[@]}" | sed 's/,$//')
    echo "[$deps_json]"
  fi
}

# Gerar JSON final
generate_json() {
  local project_dir="$1"
  local project_name=$(basename "$project_dir")
  local java_version=$(extract_java_version "$project_dir" 2>/dev/null)
  local kotlin_version=$(extract_kotlin_version "$project_dir" 2>/dev/null)
  local gradle_version=$(extract_gradle_version "$project_dir" 2>/dev/null)
  local spring_boot_version=$(extract_spring_boot_version "$project_dir" 2>/dev/null)
  
  # Extract version variables internally for dependency resolution
  local version_variables=$(extract_version_variables "$project_dir" 2>/dev/null)
  
  # Extract and process dependencies using the variables
  local dependencies=$(extract_dependencies "$project_dir" 2>/dev/null)

  # Tratar valores vazios, convertendo-os para null no JSON
  local java_json=$([ -n "$java_version" ] && echo "\"$java_version\"" || echo "null")
  local kotlin_json=$([ -n "$kotlin_version" ] && echo "\"$kotlin_version\"" || echo "null")
  local gradle_json=$([ -n "$gradle_version" ] && echo "\"$gradle_version\"" || echo "null")
  local spring_boot_json=$([ -n "$spring_boot_version" ] && echo "\"$spring_boot_version\"" || echo "null")

  # Generate simplified JSON structure without variables section
  local project_json="{\"project\":\"$project_name\",\"requirements\":{\"java\":$java_json,\"kotlin\":$kotlin_json,\"gradle\":$gradle_json,\"spring_boot\":$spring_boot_json},\"dependencies\":$dependencies}"
  
  echo "$project_json"
}

# Função principal
main() {
  check_dependencies

  # Permitir passar um arquivo .txt com URLs de repositórios
  if [ $# -eq 1 ] && [[ "$1" == *.txt ]]; then
    if [ ! -f "$1" ]; then
      error "Arquivo de URLs não encontrado: $1"
      exit 1
    fi
    log "Lendo URLs de repositórios do arquivo: $1"
    # Usar mapfile/readarray para ler o arquivo em um array
    mapfile -t repo_urls < "$1"
    # Filtrar linhas vazias e comentários
    repo_urls_filtered=()
    for url in "${repo_urls[@]}"; do
      # Ignorar linhas vazias ou que começam com #
      if [[ -n "$url" && ! "$url" =~ ^[[:space:]]*# ]]; then
        # Remover espaços em branco no início e fim
        url=$(echo "$url" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        repo_urls_filtered+=("$url")
      fi
    done
    set -- "${repo_urls_filtered[@]}"
  fi

  # Verificar se foram fornecidos repositórios
  if [ $# -eq 0 ]; then
    # Se não foram fornecidos repositórios, gerar dados de exemplo
    log "Nenhum repositório fornecido. Gerando dados de exemplo..."
    
    # Criar JSON de exemplo
    cat > "$OUTPUT_FILE" << EOF
{
  "project": "payment-service",
  "requirements": {
    "java": "17",
    "kotlin": "1.9.0",
    "gradle": "8.2",
    "spring_boot": "3.1.2"
  },
  "dependencies": [
    {
      "group": "org.springframework.boot",
      "name": "spring-boot-starter-web",
      "version": "3.1.2",
      "configuration": "implementation",
      "declaration": "implementation(\"org.springframework.boot:spring-boot-starter-web:3.1.2\")"
    },
    {
      "group": "com.fasterxml.jackson.core",
      "name": "jackson-databind",
      "version": "2.15.1",
      "configuration": "implementation",
      "declaration": "implementation(\"com.fasterxml.jackson.core:jackson-databind:2.15.1\")"
    },
    {
      "group": "org.mapstruct",
      "name": "mapstruct",
      "version": "1.5.5.Final",
      "configuration": "implementation",
      "declaration": "implementation(\"org.mapstruct:mapstruct:1.5.5.Final\")"
    },
    {
      "group": "org.junit.jupiter",
      "name": "junit-jupiter-api",
      "version": "5.9.2",
      "configuration": "testImplementation",
      "declaration": "testImplementation(\"org.junit.jupiter:junit-jupiter-api:5.9.2\")"
    },
    {
      "group": "org.mockito",
      "name": "mockito-core",
      "version": "5.3.1",
      "configuration": "testImplementation",
      "declaration": "testImplementation(\"org.mockito:mockito-core:5.3.1\")"
    }
  ]
}
EOF
  else
    # Processar repositórios fornecidos
    local projects_json=()
    
    for repo_url in "$@"; do
      # Ignorar linhas que começam com # ou estão vazias
      if [[ -z "$repo_url" || "$repo_url" =~ ^# ]]; then
        continue
      fi
      
      log "Processando repositório: $repo_url"
      local repo_dir=$(clone_repo "$repo_url")
      
      if [ $? -eq 0 ] && [ -n "$repo_dir" ]; then
        log "Gerando JSON para: $(basename "$repo_dir")"
        # Correção aqui: removidos os parênteses extras que causavam o erro
        local project_json=$(generate_json "$repo_dir")
        
        if [ -n "$project_json" ]; then
          projects_json+=("$project_json")
          success "JSON gerado com sucesso para: $(basename "$repo_dir")"
        else
          warning "Falha ao gerar JSON para: $(basename "$repo_dir")"
        fi
      fi
    done
    
    # Gerar JSON final
    if [ ${#projects_json[@]} -eq 1 ]; then
      # Se houver apenas um projeto, usar formato simples
      echo "${projects_json[0]}" > "$OUTPUT_FILE"
    else
      # Se houver múltiplos projetos, usar array
      local json=$(printf '%s,' "${projects_json[@]}" | sed 's/,$//')
      echo "[$json]" > "$OUTPUT_FILE"
    fi
  fi
  
  # Formatar JSON se jq estiver disponível
  if command -v jq &> /dev/null; then
    log "Formatando arquivo JSON com jq..."
    jq . "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
  fi
  
  success "Arquivo JSON gerado com sucesso: $OUTPUT_FILE"
  log "Coloque este arquivo no mesmo diretório que o index.html para visualizar as dependências."
}

# Executar função principal com todos os argumentos
main "$@"
