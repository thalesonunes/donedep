#!/bin/bash

# DoneDep - Funções comuns
# Autor: Thales Nunes
# Data: 18/05/2025
# Versão: 1.0

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para obter timestamp atual no formato padronizado
get_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# Funções de log aprimoradas com timestamp consistente
log() {
  local timestamp=$(get_timestamp)
  echo -e "${timestamp} ${BLUE}[INFO]${NC} $1"
}

error() {
  local timestamp=$(get_timestamp)
  echo -e "${timestamp} ${RED}[ERRO]${NC} $1"
}

success() {
  local timestamp=$(get_timestamp)
  echo -e "${timestamp} ${GREEN}[SUCESSO]${NC} $1"
}

warning() {
  local timestamp=$(get_timestamp)
  echo -e "${timestamp} ${YELLOW}[AVISO]${NC} $1"
}

# Função para registrar mensagens no arquivo de log
log_to_file() {
  local message="$1"
  local log_file="${LOG_FILE:-$(dirname "${BASH_SOURCE[0]}")/../../data/donedep.log}"
  local timestamp=$(get_timestamp)
  
  # Criar diretório de log se não existir
  mkdir -p "$(dirname "$log_file")"
  
  # Adicionar mensagem ao arquivo de log com timestamp
  echo "${timestamp} - $message" >> "$log_file"
}

# Função para verificar requisitos do sistema
check_dependencies() {
  log "Verificando dependências necessárias..."
  
  local deps=("git" "grep" "sed")
  local missing=0
  
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
      error "$dep não encontrado. Este é um requisito obrigatório."
      missing=1
    fi
  done
  
  # jq é opcional mas recomendado
  if ! command -v jq &> /dev/null; then
    warning "jq não encontrado. Recomendado para formatação JSON."
    warning "A saída JSON será gerada, mas pode não ser formatada adequadamente."
    warning "Instale jq para melhor formatação: sudo apt install jq"
  else
    log "jq encontrado: $(command -v jq)"
  fi
  
  if [ $missing -eq 1 ]; then
    return 1
  fi
  
  success "Todas as dependências necessárias estão instaladas."
  return 0
}

# Retorna o caminho absoluto
get_absolute_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    echo "$path"
  else
    echo "$(pwd)/$path"
  fi
}

# Descobre se a string está vazia ou é apenas espaços
is_empty_or_whitespace() {
  local str="$1"
  if [[ -z "${str// /}" ]]; then
    return 0  # Verdadeiro, está vazio ou só tem espaços
  else
    return 1  # Falso, contém caracteres não-espaço
  fi
}

# Função para logs de depuração
debug_log() {
  if [ "${DEBUG:-false}" = "true" ]; then
    echo -e "[DEBUG] $1" >&2
  fi
  # Always log to file if LOG_FILE is defined
  if [ -n "${LOG_FILE:-}" ]; then
    echo "$(date +"%H:%M:%S") [DEBUG] $1" >> "$LOG_FILE"
  fi
}

# Função para logs de erro
error_log() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
  if [ -n "${LOG_FILE:-}" ]; then
    echo "$(date +"%H:%M:%S") [ERROR] $1" >> "$LOG_FILE"
  fi
}
