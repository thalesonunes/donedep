#!/bin/bash

# DoneDep - Script de instalação
# Autor: Thales Nunes
# Data: 18/05/2025
# Versão: 1.0

# Definir diretório do script e diretório raiz do projeto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)" 
cd "$PROJECT_DIR"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir mensagens
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

# Verificar dependências do sistema
check_system_dependencies() {
  log "Verificando dependências do sistema..."
  
  # Lista de dependências necessárias
  dependencies=("git" "grep" "sed" "jq")
  missing=0
  
  for dep in "${dependencies[@]}"; do
    if ! command -v $dep &> /dev/null; then
      if [ "$dep" = "jq" ]; then
        warning "$dep não encontrado. Recomendado, mas não obrigatório."
      else
        error "$dep não encontrado. Este é um requisito obrigatório."
        missing=1
      fi
    else
      log "$dep encontrado: $(command -v $dep)"
    fi
  done
  
  if [ $missing -eq 1 ]; then
    error "Dependências obrigatórias estão faltando."
    log "Por favor, instale as ferramentas necessárias e execute este script novamente."
    
    if [ -f /etc/debian_version ]; then
      log "Você parece estar usando uma distribuição baseada em Debian/Ubuntu."
      log "Você pode instalar as dependências necessárias com:"
      echo -e "${YELLOW}sudo apt update && sudo apt install git grep sed jq${NC}"
    elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
      log "Você parece estar usando uma distribuição baseada em Red Hat/Fedora."
      log "Você pode instalar as dependências necessárias com:"
      echo -e "${YELLOW}sudo dnf install git grep sed jq${NC}"
    fi
    
    return 1
  fi
  
  success "Todas as dependências obrigatórias estão instaladas!"
  return 0
}

# Configurar estrutura de diretórios
setup_directories() {
  log "Configurando estrutura de diretórios..."
  
  # Criar diretórios necessários se não existirem
  mkdir -p "$PROJECT_DIR/data"
  mkdir -p "$PROJECT_DIR/data/repo_cache"
  
  # Verificar se os diretórios foram criados com sucesso
  if [ -d "$PROJECT_DIR/data" ] && [ -d "$PROJECT_DIR/data/repo_cache" ]; then
    success "Diretórios criados com sucesso!"
    return 0
  else
    error "Falha ao criar os diretórios necessários."
    return 1
  fi
}

# Configurar permissões para os scripts
setup_permissions() {
  log "Configurando permissões dos scripts..."
  
  # Configurar permissões para o script principal na raiz
  if [ -f "$PROJECT_DIR/run.sh" ]; then
    chmod +x "$PROJECT_DIR/run.sh"
    log "run.sh: permissão de execução concedida"
  else
    warning "run.sh não encontrado na raiz do projeto. Ignorando."
  fi
  
  # Configurar permissões para os scripts no diretório scripts/
  scripts=("main.sh" "modular_test.sh" "install.sh")
  
  for script in "${scripts[@]}"; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
      chmod +x "$SCRIPT_DIR/$script"
      log "$script: permissão de execução concedida"
    else
      warning "$script não encontrado. Ignorando."
    fi
  done
  
  success "Permissões configuradas com sucesso!"
  return 0
}

# Verificar arquivo de repositórios
check_repos_file() {
  log "Verificando arquivo de repositórios..."
  
  if [ ! -f "$PROJECT_DIR/repos.txt" ]; then
    warning "Arquivo repos.txt não encontrado."
    
    # Criar arquivo de exemplo se não existir
    log "Criando arquivo repos.txt de exemplo..."
    cat > "$PROJECT_DIR/repos.txt" << EOF
# Arquivo de repositórios para DoneDep
# Adicione as URLs dos repositórios Git que deseja analisar, um por linha
# Linhas começando com # são tratadas como comentários

# Exemplos:
# https://github.com/usuario/repositorio1.git
# https://github.com/usuario/repositorio2.git
EOF
    
    if [ -f "$PROJECT_DIR/repos.txt" ]; then
      success "Arquivo repos.txt de exemplo criado com sucesso!"
      log "Por favor, edite o arquivo repos.txt e adicione os repositórios que deseja analisar."
    else
      error "Falha ao criar o arquivo repos.txt de exemplo."
      return 1
    fi
  else
    log "Arquivo repos.txt encontrado."
    
    # Verificar se o arquivo contém repositórios (linhas não comentadas)
    repos_count=$(grep -v "^#" "$PROJECT_DIR/repos.txt" | grep -v "^$" | wc -l)
    
    if [ $repos_count -eq 0 ]; then
      warning "O arquivo repos.txt não contém repositórios válidos."
      log "Por favor, edite o arquivo repos.txt e adicione os repositórios que deseja analisar."
    else
      success "Arquivo repos.txt configurado com $repos_count repositório(s)!"
    fi
  fi
  
  return 0
}

# Verificar se é necessário executar a instalação completa
check_install_needed() {
  # Arquivo para controle de última execução
  local last_install_file="$PROJECT_DIR/.last_install"
  local current_time=$(date +%s)
  
  # Verificar se o arquivo existe e obter o timestamp da última execução
  if [ -f "$last_install_file" ]; then
    local last_install_time=$(cat "$last_install_file")
    local elapsed_time=$((current_time - last_install_time))
    
    # Se a última execução foi há menos de 1 hora, retorne sem fazer nada
    # 3600 segundos = 1 hora
    if [ $elapsed_time -lt 3600 ]; then
      log "Configuração já verificada recentemente. Pulando instalação."
      return 1
    fi
  fi
  
  # Atualizar o timestamp da última execução
  echo "$current_time" > "$last_install_file"
  return 0
}

# Função principal de instalação
install() {
  # Verificar se é necessário executar a instalação completa
  if ! check_install_needed; then
    return 0
  fi
  
  log "Iniciando instalação do DoneDep..."
  
  # Verificar dependências do sistema
  check_system_dependencies
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  # Configurar estrutura de diretórios
  setup_directories
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  # Configurar permissões dos scripts
  setup_permissions
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  # Verificar arquivo de repositórios
  check_repos_file
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  success "Instalação concluída com sucesso!"
  log "Para começar, execute: ./run.sh"
  return 0
}

# Executar instalação
install
