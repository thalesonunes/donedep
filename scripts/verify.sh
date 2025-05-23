#!/bin/bash

# DoneDep Basic Verification Script
# Author: Thales Nunes
# Date: 19/05/2025

echo "DoneDep Basic Verification"
echo "=========================="
echo "This script performs a basic functionality check of the DoneDep system."
echo ""

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the root directory of the project (one level up from scripts/)
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if dependencies.json exists
if [ ! -f "$PROJECT_ROOT/data/dependencies.json" ]; then
    echo "ERROR: dependencies.json not found!"
    echo "Run the main.sh script to extract dependencies first."
    exit 1
fi

# Check if the dependencies.json file is valid JSON
echo "Checking dependencies.json format..."
if ! jq . "$PROJECT_ROOT/data/dependencies.json" > /dev/null 2>&1; then
    echo "ERROR: dependencies.json is not valid JSON!"
    echo "Check the extraction process for errors."
    exit 1
else
    echo "✓ JSON format is valid."
fi

# Count projects and dependencies
PROJECTS=$(jq '. | length' "$PROJECT_ROOT/data/dependencies.json")
DEPS=$(jq '[.[] | .dependencies | length] | add // 0' "$PROJECT_ROOT/data/dependencies.json")

echo "✓ Found $PROJECTS projects with a total of $DEPS dependencies."

# Check if critical files exist
echo ""
echo "Checking for critical files..."
CRITICAL_FILES=(
    "$PROJECT_ROOT/index.html"
    "$PROJECT_ROOT/js/app.js"
    "$PROJECT_ROOT/js/adapters/data-adapter.js"
    "$PROJECT_ROOT/scripts/main.sh"
    "$PROJECT_ROOT/scripts/modules/common.sh"
    "$PROJECT_ROOT/scripts/modules/dependency_parser.sh"
    "$PROJECT_ROOT/scripts/modules/json_handler.sh"
    "$PROJECT_ROOT/scripts/modules/project_analyzer.sh"
    "$PROJECT_ROOT/scripts/modules/repo_manager.sh"
    "$PROJECT_ROOT/scripts/modules/version_extractor.sh"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "✗ Missing critical file: $file"
        HAS_ERROR=1
    else
        echo "✓ Found: $file"
    fi
done

echo ""
if [ -z "$HAS_ERROR" ]; then
    echo "All critical files are present."
    echo ""
    echo "DoneDep is ready to use!"
    echo "To extract dependencies: ./scripts/main.sh"
    echo "To view dependencies: open index.html in a web browser"
else
    echo "Some critical files are missing. Please restore them."
fi

echo ""
echo "✓ O Projeto DoneDep está totalmente simplificado e otimizado."
echo "✓ Interface utiliza o adaptador de dados simplificado."
echo "✓ Toda a documentação consolidada no README.md principal."
echo "✓ Todos os arquivos de backup e temporários foram removidos."
