#!/bin/bash

# Verificar versão do Java em um projeto Gradle
extract_java_version() {
  local project_dir="$1"
  local java_version=""
  
  # Buscar em diferentes arquivos Gradle
  local gradle_files=(
    "$project_dir/build.gradle"
    "$project_dir/build.gradle.kts"
    "$project_dir/gradle.properties"
  )
  
  for gradle_file in "${gradle_files[@]}"; do
    if [ -f "$gradle_file" ]; then
      echo "Processando arquivo: $gradle_file"
      
      # Verificar formato específico kotlin DSL: java.sourceCompatibility = JavaVersion.VERSION_XX
      if grep -q "java\.sourceCompatibility.*JavaVersion" "$gradle_file"; then
        echo "Encontrado formato kotlin DSL java.sourceCompatibility"
        
        # Extrair a versão do JavaVersion enum
        if grep -q "VERSION_[0-9]" "$gradle_file"; then
          local java_enum=$(grep -oP "VERSION_\K[0-9]+" "$gradle_file" | head -1)
          java_version="$java_enum"
          echo "Extraído número da versão: $java_version"
          break
        elif grep -q "VERSION_1_[0-9]" "$gradle_file"; then
          local java_enum=$(grep -oP "VERSION_1_\K[0-9]+" "$gradle_file" | head -1)
          java_version="1.$java_enum"
          echo "Extraído número da versão 1.x: $java_version"
          break
        fi
      fi
      
      # Procurar padrões tradicionais
      if grep -q "sourceCompatibility.*=.*1\.[0-9]" "$gradle_file"; then
        java_version=$(grep -oE "sourceCompatibility.*=.*1\.[0-9]+" "$gradle_file" | head -1 | grep -oE "1\.[0-9]+")
        echo "Encontrado sourceCompatibility 1.x: $java_version"
        break
      elif grep -q "sourceCompatibility.*=.*[0-9]" "$gradle_file"; then
        java_version=$(grep -oE "sourceCompatibility.*=.*[0-9]+" "$gradle_file" | head -1 | grep -oE "[0-9]+")
        echo "Encontrado sourceCompatibility número: $java_version"
        break
      fi
    fi
  done
  
  echo "$java_version"
}

# Executar a função com o caminho do projeto
extract_java_version "$1"
