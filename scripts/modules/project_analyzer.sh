#!/bin/bash

# DoneDep - Analisador de projetos
# Autor: Thales Nunes
# Data: 19/05/2025
# Versão: 1.1
#
# NOTA: Este é o arquivo oficial e único para análise de projetos.
# Todas as versões alternativas foram consolidadas em backup/project_analyzer_versions/

# Importar módulos comuns
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/json_handler.sh"

# Configurar LOG_FILE - será sobrescrito pelo valor do script principal se existir
DATA_DIR="$(dirname "${BASH_SOURCE[0]}")/../../../data"
LOG_FILE="${LOG_FILE:-"$DATA_DIR/donedep.log"}"

# Extrair módulos do projeto
extract_project_modules() {
  local project_dir="$1"
  local modules_json="[]"
  local found_modules=false
  
  # Verificar se é um projeto multi-módulos Gradle
  if [ -f "$project_dir/settings.gradle" ] || [ -f "$project_dir/settings.gradle.kts" ]; then
    local settings_file=""
    if [ -f "$project_dir/settings.gradle" ]; then
      settings_file="$project_dir/settings.gradle"
    else
      settings_file="$project_dir/settings.gradle.kts"
    fi
    
    # Extrair módulos do settings.gradle(kts)
    if [ -f "$settings_file" ]; then
      # Usar grep para encontrar linhas incluindo módulos
      local module_lines
      module_lines=$(grep -E "include\(.*\)|include.*'" "$settings_file" 2>/dev/null || echo "")
      
      if [ -n "$module_lines" ]; then
        found_modules=true
        modules_json="["
        
        # Extrair caminhos dos módulos
        local module_paths
        module_paths=$(echo "$module_lines" | grep -oE ":[a-zA-Z0-9_\-]+" | tr -d ":" | tr "\n" " ")
        
        # Processar cada módulo
        for module in $module_paths; do
          # Verificar se o diretório do módulo existe
          if [ -d "$project_dir/$module" ]; then
            # Adicionar módulo ao JSON
            modules_json="${modules_json}\"$module\","
          fi
        done
        
        # Remover a última vírgula se houver módulos encontrados
        if [ "$modules_json" != "[" ]; then
          modules_json="${modules_json%,}"
        fi
        
        modules_json="$modules_json]"
      fi
    fi
  fi
  
  # Se não encontrou módulos, retornar array vazio
  if [ "$found_modules" = false ]; then
    modules_json="[]"
  fi
  
  echo "$modules_json"
}

# Analisar um projeto Java/Kotlin e extrair informações
analyze_project() {
  local project_dir="$1"
  local is_module="${2:-false}"
  
  # Se o diretório não existir, retornar objeto vazio
  if [ ! -d "$project_dir" ]; then
    echo "{}"
    return 1
  fi
  
  # Verificar se é um projeto Java/Kotlin
  if ! is_valid_project "$project_dir"; then
    debug_log "Diretório não parece ser um projeto Java/Kotlin válido: $project_dir"
    echo "{}"
    return 1
  fi
  
  # Extrair nome do projeto
  local project_name="$(basename "$project_dir")"
  debug_log "Analisando projeto: $project_name ($project_dir)"
  
  # Extrair versões das tecnologias
  local java_version=$(extract_java_version "$project_dir" 2>/dev/null)
  # Normalizar a versão do Java antes de salvar no JSON
  if [ -n "$java_version" ]; then
    java_version=$(normalize_java_version "$java_version")
    debug_log "Versão Java normalizada para $java_version em $project_name"
  fi
  
  local kotlin_version=$(extract_kotlin_version "$project_dir" 2>/dev/null)
  local gradle_version=$(extract_gradle_version "$project_dir" 2>/dev/null)
  local spring_boot_version=$(extract_spring_boot_version "$project_dir" 2>/dev/null)
  
  # Criar contexto do projeto como JSON para resolver variáveis
  local project_context="{}"
  if [ -n "$java_version" ] || [ -n "$kotlin_version" ] || [ -n "$gradle_version" ] || [ -n "$spring_boot_version" ]; then
    project_context="{"
    [ -n "$java_version" ] && project_context="$project_context\"javaVersion\":\"$java_version\","
    [ -n "$kotlin_version" ] && project_context="$project_context\"kotlinVersion\":\"$kotlin_version\","
    [ -n "$gradle_version" ] && project_context="$project_context\"gradleVersion\":\"$gradle_version\","
    [ -n "$spring_boot_version" ] && project_context="$project_context\"springBootVersion\":\"$spring_boot_version\""
    project_context="${project_context%,}" # remover última vírgula se existir
    project_context="$project_context}"
  fi
  
  # Extrair dependências - redirecionando todo output para o log
  local dependencies_json=$(extract_dependencies "$project_dir" "$project_context" 2>/dev/null)
  
  # Garantir que dependencies_json é um array JSON válido
  if [[ ! "$dependencies_json" == \[*\] ]]; then
    debug_log "Formato inválido de array dependencies_json: $dependencies_json"
    dependencies_json="[]"
  fi
  
  # Remover possíveis mensagens de log no array de dependências
  dependencies_json=$(echo "$dependencies_json" | sed 's/\[INFO\][^"]*//g; s/\[WARN\][^"]*//g; s/\[ERROR\][^"]*//g; s/INFO[^"]*"/""/g; s/WARN[^"]*"/""/g; s/ERROR[^"]*"/""/g; s/DEBUG[^"]*"/""/g')
  
  # Extrair módulos apenas se não for um módulo em si
  local modules_json=""
  if [ "$is_module" = false ]; then
    modules_json=$(extract_project_modules "$project_dir" 2>/dev/null)
    
    # Processar cada módulo se necessário
    if [ "$modules_json" != "[]" ]; then
      debug_log "Processando módulos do projeto $project_name"
      
      # Iniciar array de projetos de módulos
      local modules_projects="[]"
      
      # Processar cada módulo
      for module in $(echo "$modules_json" | jq -r '.[]' 2>/dev/null || echo ""); do
        if [ -n "$module" ]; then
          local module_path="$project_dir/$module"
          if [ -d "$module_path" ]; then
            local module_json=$(analyze_project "$module_path" true 2>/dev/null)
            
            # Se o módulo retornou um objeto não vazio, adicionar à lista
            if [ "$module_json" != "{}" ]; then
              modules_projects=$(echo "$modules_projects" | jq ". + [$module_json]" 2>/dev/null || echo "[]")
            fi
          fi
        fi
      done
      
      # Se há projetos de módulos, combinar com o projeto principal
      if [ "$modules_projects" != "[]" ]; then
        debug_log "Módulos encontrados e analisados: $modules_projects"
      fi
    fi
  fi
  
  # Construir objeto JSON com as informações do projeto
  local project_json="{"
  project_json="$project_json\"project\":\"$project_name\""
  
  # Adicionar versões se disponíveis
  if [ -n "$java_version" ]; then
    project_json="$project_json,\"javaVersion\":\"$java_version\""
    # Adicionar ao log para depuração
    debug_log "Adicionada javaVersion=$java_version para projeto $project_name"
  fi
  
  if [ -n "$kotlin_version" ]; then
    project_json="$project_json,\"kotlinVersion\":\"$kotlin_version\""
  fi
  
  if [ -n "$gradle_version" ]; then
    project_json="$project_json,\"gradleVersion\":\"$gradle_version\""
  fi
  
  if [ -n "$spring_boot_version" ]; then
    project_json="$project_json,\"springBootVersion\":\"$spring_boot_version\""
  fi
  
  # Adicionar dependências
  project_json="$project_json,\"dependencies\":$dependencies_json"
  
  # Fechar o objeto
  project_json="$project_json}"
  
  # Verificar se o JSON é válido
  if ! echo "$project_json" | jq . >/dev/null 2>&1; then
    error_log "Falha ao gerar JSON para o projeto $project_name"
    echo "{}"
    return 1
  fi
  
  # Retornar o JSON do projeto
  echo "$project_json"
}

# Verificar se o diretório contém um projeto Java/Kotlin válido
is_valid_project() {
  local dir="$1"
  
  # Verificar se existe pelo menos um arquivo de build
  if [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ] || [ -f "$dir/pom.xml" ]; then
    return 0
  fi
  
  # Verificar se existe código fonte Java ou Kotlin
  if [ -d "$dir/src/main/java" ] || [ -d "$dir/src/main/kotlin" ]; then
    return 0
  fi
  
  return 1
}

# Inicialização de módulo
init_project_analyzer() {
  debug_log "Módulo project_analyzer inicializado"
  mkdir -p "$DATA_DIR"
}
