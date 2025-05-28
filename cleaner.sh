#!/bin/bash

# DoneDep Cleaner Script
# Remove todas as dependências extraídas e arquivos relacionados

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir banner
show_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                               DoneDep Cleaner                                 ║"
    echo "║                    Remove todas as dependências extraídas                     ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Função para confirmar ação
confirm_action() {
    echo -e "${YELLOW}⚠️  Esta ação irá remover TODOS os dados de dependências extraídas!${NC}"
    echo -e "${YELLOW}   Os seguintes arquivos e dados serão removidos:${NC}"
    echo -e "${YELLOW}   • data/dependencies.json${NC}"
    echo -e "${YELLOW}   • data/dependency-files-list.json${NC}"
    echo -e "${YELLOW}   • data/dependencies_*.json (arquivos de histórico)${NC}"
    echo -e "${YELLOW}   • data/donedep.log${NC}"
    echo ""
    read -p "Deseja continuar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Operação cancelada pelo usuário${NC}"
        exit 1
    fi
}

# Função para remover arquivo se existir
remove_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        rm -f "$file"
        echo -e "${GREEN}✅ Removido: $file${NC}"
    else
        echo -e "${YELLOW}⚠️  Arquivo não encontrado: $file${NC}"
    fi
}

# Função para remover arquivos com padrão
remove_pattern() {
    local pattern="$1"
    local description="$2"
    local search_dir="${3:-.}"  # Usa diretório atual como padrão se não especificado
    local count=$(find "$search_dir" -name "$pattern" -type f 2>/dev/null | wc -l)
    
    if [[ $count -gt 0 ]]; then
        find "$search_dir" -name "$pattern" -type f -delete
        echo -e "${GREEN}✅ Removidos $count arquivo(s): $description${NC}"
    else
        echo -e "${YELLOW}⚠️  Nenhum arquivo encontrado: $description${NC}"
    fi
}

# Função principal de limpeza
clean_dependencies() {
    echo -e "${BLUE}🧹 Iniciando limpeza das dependências...${NC}"
    echo ""
    
    # Navegar para o diretório do projeto
    cd "$(dirname "$0")"
    
    # Remover arquivos principais
    echo -e "${BLUE}📄 Removendo arquivos principais...${NC}"
    remove_file "data/dependencies.json"
    remove_file "data/dependency-files-list.json"
    remove_file "data/donedep.log"
    
    echo ""
    
    # Remover arquivos de histórico
    echo -e "${BLUE}📅 Removendo arquivos de histórico...${NC}"
    remove_pattern "dependencies_*.json" "arquivos de histórico de dependências" "data"
    
    echo ""
    
    # Verificar se o diretório data ainda tem conteúdo (exceto repo_cache)
    local remaining_files=$(find data/ -type f ! -path "data/repo_cache/*" 2>/dev/null | wc -l)
    
    if [[ $remaining_files -eq 0 ]]; then
        echo -e "${GREEN}✨ Limpeza concluída! Todos os dados de dependências foram removidos.${NC}"
    else
        echo -e "${YELLOW}ℹ️  Limpeza concluída. Alguns arquivos ainda permanecem no diretório data/.${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📊 Status final:${NC}"
    echo -e "${BLUE}   • Cache de repositórios: ${GREEN}mantido${NC}"
    echo -e "${BLUE}   • Dados de dependências: ${RED}removidos${NC}"
    echo -e "${BLUE}   • Logs: ${RED}removidos${NC}"
    echo ""
    echo -e "${GREEN}🎉 Para extrair novas dependências, execute: ${YELLOW}./run.sh${NC}"
}

# Função para mostrar ajuda
show_help() {
    echo "DoneDep Cleaner - Remove todas as dependências extraídas"
    echo ""
    echo "Uso:"
    echo "  ./cleaner.sh [OPÇÃO]"
    echo ""
    echo "Opções:"
    echo "  -h, --help     Mostra esta ajuda"
    echo "  -f, --force    Remove arquivos sem confirmação"
    echo "  -v, --version  Mostra a versão"
    echo ""
    echo "Exemplos:"
    echo "  ./cleaner.sh           # Limpeza interativa com confirmação"
    echo "  ./cleaner.sh --force   # Limpeza automática sem confirmação"
}

# Função para mostrar versão
show_version() {
    echo "DoneDep Cleaner v1.0.0"
}

# Processamento de argumentos
FORCE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE_MODE=true
            shift
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opção desconhecida: $1${NC}"
            echo -e "${YELLOW}Use --help para ver as opções disponíveis${NC}"
            exit 1
            ;;
    esac
done

# Execução principal
show_banner

if [[ "$FORCE_MODE" == false ]]; then
    confirm_action
fi

clean_dependencies

echo -e "${GREEN}✨ Operação concluída com sucesso!${NC}"
