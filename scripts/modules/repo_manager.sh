#!/bin/bash

# JoneDep - Gerenciamento de repositórios
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
  git clone --quiet "$repo_url" "$target_dir"
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
  
  # Extrair nome do repositório da URL
  local repo_name=$(basename "$repo_url" .git)
  
  # Limpar caracteres problemáticos
  repo_name=$(echo "$repo_name" | tr -cd '[:alnum:]-_')
  
  echo "$repo_name"
}

# Verifica se o diretório contém um projeto Gradle ou Maven válido
is_valid_project() {
  local project_dir="$1"
  
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
