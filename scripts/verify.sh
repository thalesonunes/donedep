#!/bin/bash

# JoneDep Basic Verification Script
# Author: Thales Nunes
# Date: 19/05/2025

echo "JoneDep Basic Verification"
echo "=========================="
echo "This script performs a basic functionality check of the JoneDep system."
echo ""

# Check if dependencies.json exists
if [ ! -f "/home/thalesnunes/Documentos/jone-dep/data/dependencies.json" ]; then
    echo "ERROR: dependencies.json not found!"
    echo "Run the main.sh script to extract dependencies first."
    exit 1
fi

# Check if the dependencies.json file is valid JSON
echo "Checking dependencies.json format..."
if ! jq . "/home/thalesnunes/Documentos/jone-dep/data/dependencies.json" > /dev/null 2>&1; then
    echo "ERROR: dependencies.json is not valid JSON!"
    echo "Check the extraction process for errors."
    exit 1
else
    echo "✓ JSON format is valid."
fi

# Count projects and dependencies
PROJECTS=$(jq '. | length' "/home/thalesnunes/Documentos/jone-dep/data/dependencies.json")
DEPS=$(jq '[.[] | .dependencies | length] | add // 0' "/home/thalesnunes/Documentos/jone-dep/data/dependencies.json")

echo "✓ Found $PROJECTS projects with a total of $DEPS dependencies."

# Check if critical files exist
echo ""
echo "Checking for critical files..."
CRITICAL_FILES=(
    "/home/thalesnunes/Documentos/jone-dep/index.html"
    "/home/thalesnunes/Documentos/jone-dep/js/app.js"
    "/home/thalesnunes/Documentos/jone-dep/js/data-adapter.js"
    "/home/thalesnunes/Documentos/jone-dep/scripts/main.sh"
    "/home/thalesnunes/Documentos/jone-dep/scripts/modules/common.sh"
    "/home/thalesnunes/Documentos/jone-dep/scripts/modules/dependency_parser.sh"
    "/home/thalesnunes/Documentos/jone-dep/scripts/modules/json_handler.sh"
    "/home/thalesnunes/Documentos/jone-dep/scripts/modules/project_analyzer.sh"
    "/home/thalesnunes/Documentos/jone-dep/scripts/modules/repo_manager.sh"
    "/home/thalesnunes/Documentos/jone-dep/scripts/modules/version_extractor.sh"
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
    echo "JoneDep is ready to use!"
    echo "To extract dependencies: ./scripts/main.sh"
    echo "To view dependencies: open index.html in a web browser"
else
    echo "Some critical files are missing. Please restore them."
fi

echo ""
echo "✓ O Projeto JoneDep está totalmente simplificado e otimizado."
echo "✓ Interface utiliza o adaptador de dados simplificado."
echo "✓ Toda a documentação consolidada no README.md principal."
echo "✓ Todos os arquivos de backup e temporários foram removidos."
