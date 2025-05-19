#!/bin/bash

# JoneDep - Script principal simplificado
# Autor: Thales Nunes
# Data: 19/05/2025
# Versão: 2.0

# Definir diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir mensagens (simplificado)
log() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

error() {
  echo -e "${RED}[ERRO]${NC} $1"
}

success() {
  echo -e "${GREEN}[SUCESSO]${NC} $1"
}

warning() {
  echo -e "${YELLOW}[AVISO]${NC} $1"
}

# Função para exibir ajuda
show_help() {
  echo "JoneDep - Gerenciador de Dependências de Microsserviços"
  echo ""
  echo "Uso: $0 [opção]"
  echo ""
  echo "Opções:"
  echo "  extract     Extrair dependências dos repositórios"
  echo "  view        Abrir a interface de visualização"
  echo "  verify      Verificar funcionalidades do sistema"
  echo "  help        Mostrar esta ajuda"
  echo ""
  echo "Se nenhuma opção for especificada, o script executará a extração"
  echo "de dependências seguida da abertura da interface de visualização."
  echo ""
  echo "Exemplos:"
  echo "  $0         # Extrai dependências e abre a visualização"
  echo "  $0 extract # Apenas extrai dependências dos repositórios"
  echo "  $0 view    # Apenas abre a interface web para visualizar"
}

# Função para extrair dependências
extract_dependencies() {
  log "Iniciando extração de dependências..."
  
  # Verificar se o script main.sh existe
  if [ ! -f "./scripts/main.sh" ]; then
    error "Script de extração não encontrado: ./scripts/main.sh"
    exit 1
  fi
  
  # Executar o script de extração
  bash ./scripts/main.sh
  
  # Verificar resultado
  if [ $? -eq 0 ]; then
    success "Extração de dependências concluída com sucesso!"
  else
    error "Falha na extração de dependências. Verifique os logs em data/jone-dep.log"
  fi
}

# Função para abrir interface de visualização
open_viewer() {
  log "Iniciando servidor para interface de visualização..."
  
  # Verificar se o arquivo index.html existe
  if [ ! -f "./index.html" ]; then
    error "Interface de visualização não encontrada: ./index.html"
    exit 1
  fi
  
  # Verificar se o arquivo de dependências existe
  if [ ! -f "./data/dependencies.json" ]; then
    warning "Arquivo de dependências não encontrado: ./data/dependencies.json"
    warning "Execute '$0 extract' primeiro para gerar os dados."
  fi
  
  # Verificar se Python está instalado
  if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    error "Python não encontrado. Instale o Python para iniciar o servidor."
    exit 1
  fi
  
  # Definir a porta
  PORT=9786
  
  # Verificar se a porta está em uso
  if command -v lsof &> /dev/null; then
    if lsof -Pi :$PORT -sTCP:LISTEN -t &> /dev/null; then
      warning "A porta $PORT já está em uso. Tentando usar outra porta..."
      PORT=9787
      if lsof -Pi :$PORT -sTCP:LISTEN -t &> /dev/null; then
        error "As portas 9786 e 9787 estão em uso. Por favor, libere uma dessas portas e tente novamente."
        exit 1
      fi
    fi
  fi
  
  # Iniciar o servidor HTTP com Python
  log "Iniciando servidor HTTP na porta $PORT..."
  log "Para encerrar o servidor, pressione Ctrl+C"
  log "A interface estará disponível em http://localhost:$PORT"
  
  # Abrir o navegador automaticamente após um pequeno atraso para dar tempo de iniciar o servidor
  (sleep 2 && (xdg-open "http://localhost:$PORT" || open "http://localhost:$PORT" || start "http://localhost:$PORT")) &
  
  # Iniciar o servidor Python
  if command -v python3 &> /dev/null; then
    python3 -m http.server $PORT
  elif command -v python &> /dev/null; then
    # Verificar a versão do Python
    PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1)
    if [ "$PYTHON_VERSION" = "3" ]; then
      python -m http.server $PORT
    else
      python -m SimpleHTTPServer $PORT
    fi
  else
    error "Não foi possível iniciar o servidor HTTP."
    log "Por favor, execute manualmente: python3 -m http.server 9786"
    log "E depois acesse: http://localhost:9786 no seu navegador"
  fi
}

# Função para verificar o sistema
verify_system() {
  log "Verificando sistema JoneDep..."
  
  # Verificar se o script verify.sh existe
  if [ ! -f "./scripts/verify.sh" ]; then
    error "Script de verificação não encontrado: ./scripts/verify.sh"
    exit 1
  fi
  
  # Executar o script de verificação
  bash ./scripts/verify.sh
}

# Processar argumentos
case "$1" in
  extract)
    extract_dependencies
    ;;
  view)
    open_viewer
    ;;
  verify)
    verify_system
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    # Caso nenhum argumento seja fornecido, executa extração e visualização em sequência
    log "Nenhum comando especificado. Executando extração e visualização de dependências..."
    extract_dependencies
    if [ $? -eq 0 ]; then
      open_viewer
    else
      error "A extração de dependências falhou. Visualização cancelada."
      exit 1
    fi
    ;;
esac
