#!/bin/bash

# DoneDep - Gerenciamento de repositórios
# Autor: Thales Nunes 
# Data: 18/05/2025
# Versão: 1.0

# Importar módulos comuns
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Limpeza de recursos
cleanup() {
  local repo_dir="$1"
  if [ -d "$repo_dir" ]; then
    log "Limpando diretório temporário: $repo_dir"
    rm -rf "$repo_dir"
  fi
}

# Clonar ou atualizar repositório
clone_repo() {
  local repo_url="$1"
  local target_dir="$2"
  
  # Verificar se já existe o diretório
  if [ -d "$target_dir/.git" ]; then
    log "Repositório já clonado. Atualizando..."
    (cd "$target_dir" && git pull --quiet)
    if [ $? -ne 0 ]; then
      warning "Falha ao atualizar repositório. Usando versão existente."
    fi
    return 0
  fi
  
  # Clonar o repositório
  log "Clonando repositório: $repo_url"
  git clone "$repo_url" "$target_dir"
  if [ $? -ne 0 ]; then
    error "Falha ao clonar repositório: $repo_url"
    return 1
  fi
  
  success "Repositório clonado com sucesso: $repo_url"
  return 0
}

# Processa uma URL de repositório e retorna um nome de diretório limpo
get_repo_dirname() {
  local repo_url="$1"
  local repo_name=""
  
  if [[ "$repo_url" == git@* ]]; then
    # É uma URL SSH (git@github.com:org/repo.git)
    repo_name=$(echo "$repo_url" | sed 's/.*:\(.*\)\.git/\1/' | sed 's/.*\///')
  else
    # É uma URL HTTPS ou caminho local
    repo_name=$(basename "$repo_url" .git)
  fi
  
  # Limpar caracteres problemáticos
  repo_name=$(echo "$repo_name" | tr -cd '[:alnum:]-_')
  
  echo "$repo_name"
}

# Verifica se o diretório contém um projeto Gradle ou Maven válido
is_valid_project() {
  local project_dir="$1"
  
  # Se for uma URL, primeiro clone o repositório
  if [[ "$project_dir" == git@* ]] || [[ "$project_dir" == http* ]]; then
    local repo_url="$project_dir"
    project_dir="$REPO_CACHE_DIR/$(get_repo_dirname "$repo_url")"
    
    if ! clone_repo "$repo_url" "$project_dir"; then
      return 1
    fi
  fi
  
  # Verificar se é um projeto Gradle
  if [ -f "$project_dir/build.gradle" ] || \
     [ -f "$project_dir/build.gradle.kts" ] || \
     [ -f "$project_dir/settings.gradle" ] || \
     [ -f "$project_dir/settings.gradle.kts" ]; then
    return 0
  fi
  
  # Verificar se é um projeto Maven
  if [ -f "$project_dir/pom.xml" ]; then
    return 0
  fi
  
  return 1
}
