#!/bin/bash

# DoneDep - Script principal para extração de dependências
# Autor: Thales Nunes
# Data: 19/05/2025
# Versão: 2.1

# Definir diretório do script para importação correta dos módulos
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

# Importar módulos
source "$MODULES_DIR/common.sh"
source "$MODULES_DIR/repo_manager.sh"
source "$MODULES_DIR/version_extractor.sh"
source "$MODULES_DIR/dependency_parser.sh"
source "$MODULES_DIR/json_handler.sh"
source "$MODULES_DIR/project_analyzer.sh"

# Diretório para dados
DATA_DIR="$SCRIPT_DIR/../data"
# Criar nome de arquivo com timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
JSON_FILE="$DATA_DIR/dependencies_${TIMESTAMP}.json"
JSON_SYMLINK="$DATA_DIR/dependencies.json"
LOG_FILE="$DATA_DIR/donedep.log"
REPO_CACHE_DIR="$DATA_DIR/repo_cache"
DEPENDENCY_LIST_FILE="$DATA_DIR/dependency-files-list.json"

# Função para atualizar o symlink para o arquivo mais recente
update_symlink() {
  local latest_file
  latest_file=$(ls -t "$DATA_DIR"/dependencies_*.json 2>/dev/null | head -n1)

  if [ -n "$latest_file" ]; then
    log "Atualizando symlink para o arquivo mais recente: $(basename "$latest_file")" | tee -a "$LOG_FILE"
    ln -sf "$latest_file" "$JSON_SYMLINK"
  else
    warning "Nenhum arquivo de dependências encontrado para atualizar o symlink" | tee -a "$LOG_FILE"
  fi
}

# Variáveis globais
REPO_URLS=()

# Função para configurar log
setup_logging() {
  # Limpar o arquivo de log anterior
  echo "$(date "+%Y-%m-%d %H:%M:%S") - DoneDep v2.1 - Iniciando processamento" > "$LOG_FILE"
  log_to_file "Configuração de log concluída"
  mkdir -p "$(dirname "$LOG_FILE")"
  
  # Iniciar arquivo de log
  echo "$(date) - DoneDep v2.1 - Iniciando processamento" > "$LOG_FILE"
  
  # Função de log customizada para escrever no arquivo sem exibir na saída
  file_log() {
    echo "$(date +"%H:%M:%S") - $1" >> "$LOG_FILE"
  }
  
  file_log "Configuração de log concluída"
}

# Função para gerar o arquivo de lista de dependências
generate_dependency_list() {
  log "Gerando arquivo de lista de dependências..." | tee -a "$LOG_FILE"
  
  # Início do JSON
  echo "[" > "$DEPENDENCY_LIST_FILE"
  
  # Listar todos os arquivos de dependências em ordem reversa (mais recente primeiro)
  is_first=true
  for file in $(ls -t "$DATA_DIR"/dependencies_*.json 2>/dev/null); do
    filename=$(basename "$file")
    
    # Extrair timestamp do nome do arquivo
    if [[ $filename =~ dependencies_([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})\.json ]]; then
      year="${BASH_REMATCH[1]}"
      month="${BASH_REMATCH[2]}"
      day="${BASH_REMATCH[3]}"
      hour="${BASH_REMATCH[4]}"
      minute="${BASH_REMATCH[5]}"
      second="${BASH_REMATCH[6]}"
      
      # Adicionar vírgula se não for o primeiro
      if ! $is_first; then
        echo "," >> "$DEPENDENCY_LIST_FILE"
      fi
      is_first=false
      
      # Adicionar entrada ao JSON
      cat >> "$DEPENDENCY_LIST_FILE" << EOF
  {
    "path": "data/$filename",
    "name": "$filename",
    "date": "$year-$month-$day $hour:$minute:$second"
  }
EOF
    fi
  done
  
  # Finalizar JSON
  echo "" >> "$DEPENDENCY_LIST_FILE"
  echo "]" >> "$DEPENDENCY_LIST_FILE"
  
  log "Lista de dependências gerada em: $DEPENDENCY_LIST_FILE" | tee -a "$LOG_FILE"
}

# Função principal
main() {
  # Configurar logging
  setup_logging
  
  # Verificar dependências necessárias
  check_dependencies >> "$LOG_FILE" 2>&1

  # Tratar arquivo de entrada com URLs
  if [ $# -eq 1 ] && [[ -f "$1" ]]; then
    log "Lendo URLs de repositórios do arquivo: $1" | tee -a "$LOG_FILE"
    # Ler URLs do arquivo
    while IFS= read -r url || [ -n "$url" ]; do
      # Ignorar linhas vazias ou que começam com #
      if [[ -n "$url" && ! "$url" =~ ^[[:space:]]*# ]]; then
        # Remover espaços em branco no início e fim
        url=$(echo "$url" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        REPO_URLS+=("$url")
      fi
    done < "$1"
    
    # Verificar se há URLs válidas
    if [ ${#REPO_URLS[@]} -eq 0 ]; then
      warning "Nenhuma URL válida encontrada no arquivo: $1. Tentando processar repositórios em repo_cache..." | tee -a "$LOG_FILE"
      
      # Procurar por projetos em repo_cache
      if [ -d "$REPO_CACHE_DIR" ]; then
        for repo_dir in "$REPO_CACHE_DIR"/*; do
          if [ -d "$repo_dir" ] && [ "$(basename "$repo_dir")" != "." ] && [ "$(basename "$repo_dir")" != ".." ] && [ "$(basename "$repo_dir")" != "repo_cache.iml" ]; then
            REPO_URLS+=("$repo_dir")
          fi
        done
      fi
      
      # Verificar novamente se encontramos repositórios
      if [ ${#REPO_URLS[@]} -eq 0 ]; then
        error "Nenhum repositório encontrado em $REPO_CACHE_DIR" | tee -a "$LOG_FILE"
        exit 1
      else
        log "Encontrados ${#REPO_URLS[@]} repositórios em $REPO_CACHE_DIR" | tee -a "$LOG_FILE"
      fi
    fi
  elif [ $# -ge 1 ]; then
    # URLs passadas como argumentos
    REPO_URLS=("$@")
  else
    # Sem argumentos, tentar usar repo_cache
    if [ -d "$REPO_CACHE_DIR" ]; then
      log "Processando repositórios do diretório repo_cache..." | tee -a "$LOG_FILE"
      
      for repo_dir in "$REPO_CACHE_DIR"/*; do
        if [ -d "$repo_dir" ] && [ "$(basename "$repo_dir")" != "." ] && [ "$(basename "$repo_dir")" != ".." ] && [ "$(basename "$repo_dir")" != "repo_cache.iml" ]; then
          REPO_URLS+=("$repo_dir")
        fi
      done
      
      if [ ${#REPO_URLS[@]} -eq 0 ]; then
        error "Nenhum repositório encontrado em $REPO_CACHE_DIR" | tee -a "$LOG_FILE"
        error "Uso: $0 <url_repositorio> [url_repositorio2 ...] ou $0 <arquivo.txt>" | tee -a "$LOG_FILE"
        exit 1
      fi
    else
      error "Diretório repo_cache não encontrado. Forneça URLs de repositórios ou crie o diretório de cache" | tee -a "$LOG_FILE"
      error "Uso: $0 <url_repositorio> [url_repositorio2 ...] ou $0 <arquivo.txt>" | tee -a "$LOG_FILE"
      exit 1
    fi
  fi
  
  # Criar diretório de dados se não existir
  mkdir -p "$DATA_DIR"
  mkdir -p "$REPO_CACHE_DIR"
  
  # Criar um arquivo JSON vazio, mas válido inicialmente
  echo "[]" > "$JSON_FILE"
  
  # Array para armazenar os resultados em JSON
  local json_results="["
  local first=true
  
  # Processar cada repositório
  for repo_url in "${REPO_URLS[@]}"; do
    log "Processando repositório: $repo_url" | tee -a "$LOG_FILE"
    
    # Definir diretório do repositório
    repo_dir="$REPO_CACHE_DIR/$(get_repo_dirname "$repo_url")"
    
    # Clonar o repositório
    if ! clone_repo "$repo_url" "$repo_dir" >> "$LOG_FILE" 2>&1; then
      warning "Falha ao clonar repositório: $repo_url. Continuando com o próximo." | tee -a "$LOG_FILE"
      continue
    fi
    
    # Verificar se é um projeto válido
    if ! is_valid_project "$repo_dir" >> "$LOG_FILE" 2>&1; then
      warning "Repositório não parece ser um projeto Java/Kotlin válido: $repo_url" | tee -a "$LOG_FILE"
      cleanup "$repo_dir" >> "$LOG_FILE" 2>&1
      continue
    fi
    
    # Processar o projeto - Capturar a saída em uma variável
    # Redirecionamos apenas stderr para LOG_FILE para evitar contaminação do JSON
    local project_json=$(analyze_project "$repo_dir" 2>> "$LOG_FILE")
    
    # Sanitizar o projeto para remover quaisquer mensagens de log
    project_json=$(echo "$project_json" | sed 's/\[INFO[^"]*//g; s/\[WARN[^"]*//g; s/\[ERROR[^"]*//g; s/INFO[^"]*"/""/g; s/WARN[^"]*"/""/g; s/ERROR[^"]*"/""/g; s/DEBUG[^"]*"/""/g' | sed 's/\x1b\[[0-9;]*m//g')
    
    # Verificar se o projeto gerou JSON válido
    if is_valid_json "$project_json"; then      
      # Adicionar ao array de resultados
      if ! $first; then
        json_results+=","
      fi
      first=false
      json_results+="$project_json"
    else
      warning "Projeto $repo_dir não gerou JSON válido" | tee -a "$LOG_FILE"
      echo "Saída inválida: $project_json" >> "$LOG_FILE"
    fi
    
    # Limpar diretório do repositório apenas se foi clonado
    if [[ "$repo_url" == http* ]]; then
      cleanup "$repo_dir" >> "$LOG_FILE" 2>&1
    fi
  done
  
  # Finalizar o array JSON
  json_results+="]"
  
  # Salvar resultado bruto para debug
  echo "$json_results" > "${JSON_FILE}.raw"
  
  # Realizar limpeza mais profunda para garantir que não há logs misturados
  # Primeiro remova quaisquer mensagens de log
  cleaned_json=$(echo "$json_results" | sed 's/\[INFO[^"]*//g; s/\[WARN[^"]*//g; s/\[ERROR[^"]*//g')
  # Depois remova diretamente as strings "INFO", "WARN", "ERROR" que podem aparecer
  cleaned_json=$(echo "$cleaned_json" | sed 's/INFO[^"]*"/""/g; s/WARN[^"]*"/""/g; s/ERROR[^"]*"/""/g; s/DEBUG[^"]*"/""/g')
  # Remova códigos ANSI e caracteres de controle
  cleaned_json=$(echo "$cleaned_json" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\000-\037')
  
  # Salvar e formatar resultado
  echo "$cleaned_json" > "$JSON_FILE"
  
  # Criar/atualizar symlink para o arquivo mais recente
  if [ -L "$JSON_SYMLINK" ]; then
    # Se o symlink já existe, atualizá-lo
    ln -sf "$(basename "$JSON_FILE")" "$JSON_SYMLINK"
  else
    # Se o symlink não existe, criá-lo
    ln -sf "$(basename "$JSON_FILE")" "$JSON_SYMLINK"
  fi
  
  log "Criado arquivo de dependências com timestamp: $(basename "$JSON_FILE")" | tee -a "$LOG_FILE"
  log "Symlink atualizado para apontar para o arquivo mais recente: $JSON_SYMLINK" | tee -a "$LOG_FILE"
  
  # Validar o JSON final
  if ! validate_json "$JSON_FILE" >> "$LOG_FILE" 2>&1; then
    warning "JSON inválido detectado. Usando a versão bruta..." | tee -a "$LOG_FILE"
    
    # Verificar se o arquivo raw existe e é válido
    if [ -f "${JSON_FILE}.raw" ]; then
      cp "${JSON_FILE}.raw" "$JSON_FILE"
      if validate_json "$JSON_FILE" >> "$LOG_FILE" 2>&1; then
        success "JSON restaurado a partir do arquivo raw." | tee -a "$LOG_FILE"
        
        # Atualizar o symlink para apontar para o arquivo corrigido
        ln -sf "$(basename "$JSON_FILE")" "$JSON_SYMLINK"
      else
        error "Não foi possível recuperar um JSON válido. Criando um array vazio." | tee -a "$LOG_FILE"
        echo "[]" > "$JSON_FILE"  # Garantir que temos um JSON válido
        # Ainda assim, atualizar o symlink
        ln -sf "$(basename "$JSON_FILE")" "$JSON_SYMLINK"
        return 1
      fi
    else
      error "Arquivo raw não encontrado. Criando um array vazio." | tee -a "$LOG_FILE"
      echo "[]" > "$JSON_FILE"  # Garantir que temos um JSON válido
      return 1
    fi
  fi
  
  # Criar versão formatada se jq estiver disponível
  if command -v jq &> /dev/null; then
    jq '.' "$JSON_FILE" > "${JSON_FILE}.formatted"
    log "Versão formatada do JSON salva em: ${JSON_FILE}.formatted" >> "$LOG_FILE"
  fi
  
  # Limpeza de arquivos temporários
  log "Removendo arquivos temporários..." | tee -a "$LOG_FILE"
  if [ -f "${JSON_FILE}.raw" ]; then
    rm -f "${JSON_FILE}.raw"
    log "Arquivo ${JSON_FILE}.raw removido." >> "$LOG_FILE"
  fi
  
  if [ -f "${JSON_FILE}.formatted" ]; then
    rm -f "${JSON_FILE}.formatted"
    log "Arquivo ${JSON_FILE}.formatted removido." >> "$LOG_FILE"
  fi
  
  # Opcional: Remover arquivos antigos (mantendo apenas os 10 mais recentes)
  log "Verificando arquivos antigos para possível limpeza..." >> "$LOG_FILE"
  file_count=$(ls -1 "$DATA_DIR"/dependencies_*.json 2>/dev/null | wc -l)
  if [ "$file_count" -gt 10 ]; then
    log "Mantendo apenas os 10 arquivos JSON mais recentes..." | tee -a "$LOG_FILE"
    ls -t "$DATA_DIR"/dependencies_*.json | tail -n +11 | xargs rm -f
    removed_count=$((file_count - 10))
    log "$removed_count arquivos de dependências antigos foram removidos." | tee -a "$LOG_FILE"
  fi
  
  success "Análise concluída. Resultado salvo em: $JSON_FILE" | tee -a "$LOG_FILE"
  log "Log detalhado disponível em: $LOG_FILE"
  
  # A atualização do symlink e a limpeza dos arquivos antigos já foi feita acima
  # Gerar a lista de arquivos de dependências
  generate_dependency_list
  
  return 0
}

# Executar função principal
main "$@"
