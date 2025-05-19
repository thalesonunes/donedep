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
  log "Abrindo interface de visualização..."
  
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
  
  # Abrir no navegador padrão
  if command -v xdg-open &> /dev/null; then
    xdg-open "./index.html"
  elif command -v open &> /dev/null; then
    open "./index.html"
  elif command -v start &> /dev/null; then
    start "./index.html"
  else
    error "Não foi possível abrir o navegador automaticamente."
    log "Por favor, abra manualmente o arquivo: $SCRIPT_DIR/index.html"
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
