#!/bin/bash

# JoneDep - Extrator de versões de tecnologias
# Autor: Thales Nunes
# Data: 18/05/2025
# Versão: 1.0

# Importar módulos comuns
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Extrair versão do Java
extract_java_version() {
  local project_dir="$1"
  local java_version=""
  
  # Buscar em arquivos Gradle
  local gradle_files=(
    "$project_dir/build.gradle"
    "$project_dir/build.gradle.kts"
    "$project_dir/gradle.properties"
  )
  
  # Procurar em build.gradle e build.gradle.kts
  for gradle_file in "${gradle_files[@]}"; do
    if [ -f "$gradle_file" ]; then
      # Procurar padrões de definição de versão Java em Gradle
      if grep -q "sourceCompatibility\s*=\s*['\"]\?1\.[0-9]" "$gradle_file"; then
        java_version=$(grep -oP "sourceCompatibility\s*=\s*['\"]\?\K1\.[0-9]+" "$gradle_file" | head -1)
      elif grep -q "sourceCompatibility\s*=\s*['\"]\?[0-9]" "$gradle_file"; then
        java_version=$(grep -oP "sourceCompatibility\s*=\s*['\"]\?\K[0-9]+" "$gradle_file" | head -1)
      elif grep -q "JavaVersion\.[A-Z_0-9]+" "$gradle_file"; then
        local java_enum=$(grep -oP "JavaVersion\.\K[A-Z_0-9]+" "$gradle_file" | head -1)
        # Converter enum para número
        case "$java_enum" in
          VERSION_1_8) java_version="1.8" ;;
          VERSION_11) java_version="11" ;;
          VERSION_17) java_version="17" ;;
          VERSION_21) java_version="21" ;;
          *) java_version="" ;;
        esac
      elif grep -q "java\s*{" "$gradle_file" && grep -q "toolchain\s*{" "$gradle_file"; then
        # Buscar em blocos java { toolchain { languageVersion.set(JavaLanguageVersion.of(XX)) } }
        if grep -q "languageVersion.set" "$gradle_file"; then
          java_version=$(grep -oP "languageVersion\.set\(JavaLanguageVersion\.of\(\K[0-9]+" "$gradle_file" | head -1)
        fi
      fi
      
      # Se encontrou uma versão, sair do loop
      if [ -n "$java_version" ]; then
        break
      fi
    fi
  done
  
  # Se ainda não encontrou, procurar em pom.xml
  if [ -z "$java_version" ] && [ -f "$project_dir/pom.xml" ]; then
    if grep -q "<java.version>" "$project_dir/pom.xml"; then
      java_version=$(grep -oP "<java.version>\K[^<]+" "$project_dir/pom.xml" | head -1)
    elif grep -q "<maven.compiler.source>" "$project_dir/pom.xml"; then
      java_version=$(grep -oP "<maven.compiler.source>\K[^<]+" "$project_dir/pom.xml" | head -1)
    fi
  fi
  
  # Se não encontrou em nenhum arquivo, verificar a existência de JAVA_HOME nas configurações do projeto
  if [ -z "$java_version" ] && [ -d "$project_dir/.idea" ]; then
    # Tenta buscar em arquivos de configuração do IntelliJ IDEA
    local idea_files=($(find "$project_dir/.idea" -name "*.xml"))
    for idea_file in "${idea_files[@]}"; do
      if grep -q "jdk.home" "$idea_file" || grep -q "languageLevel" "$idea_file"; then
        if grep -qo "jdk-[0-9]\+" "$idea_file"; then
          java_version=$(grep -o "jdk-[0-9]\+" "$idea_file" | sed 's/jdk-//' | sort | head -1)
          break
        elif grep -qo "jdk1\.[0-9]\+" "$idea_file"; then
          java_version=$(grep -o "jdk1\.[0-9]\+" "$idea_file" | sed 's/jdk//' | sort | head -1)
          break
        elif grep -qo "JavaSDK-[0-9]\+" "$idea_file"; then
          java_version=$(grep -o "JavaSDK-[0-9]\+" "$idea_file" | sed 's/JavaSDK-//' | sort | head -1)
          break
        fi
      fi
    done
  fi

  echo "$java_version"
}

# Extrair versão do Kotlin
extract_kotlin_version() {
  local project_dir="$1"
  local kotlin_version=""
  
  # Procurar em arquivos Gradle
  local gradle_files=(
    "$project_dir/build.gradle"
    "$project_dir/build.gradle.kts"
    "$project_dir/gradle.properties"
  )
  
  for gradle_file in "${gradle_files[@]}"; do
    if [ -f "$gradle_file" ]; then
      # Procurar padrões comuns de definição da versão Kotlin
      if grep -q "kotlin[A-Za-z]*Version" "$gradle_file"; then
        kotlin_version=$(grep -oP "kotlin[A-Za-z]*Version\s*=\s*['\"]\K[0-9]+\.[0-9]+(\.[0-9]+)?" "$gradle_file" | head -1)
      elif grep -q "id[[:space:]]*('|\")kotlin" "$gradle_file" || grep -q "id[[:space:]]*('|\")org.jetbrains.kotlin" "$gradle_file"; then
        # Procurar em plugins { id("org.jetbrains.kotlin...") version "X.Y.Z" }
        kotlin_version=$(grep -oP "id(\s*\(\s*|\s+)['\"](kotlin|org\.jetbrains\.kotlin)[^'\"]*['\"][^'\"]*['\"](\s*\))?\s+version\s+['\"]\K[0-9]+\.[0-9]+(\.[0-9]+)?" "$gradle_file" | head -1)
      elif grep -q "kotlin[[:space:]]*{" "$gradle_file"; then
        # Procurar em bloco kotlin { version = "X.Y.Z" }
        if grep -q "version\s*=" "$gradle_file"; then
          kotlin_version=$(grep -oP "version\s*=\s*['\"]\K[0-9]+\.[0-9]+(\.[0-9]+)?" "$gradle_file" | head -1)
        fi
      fi
      
      # Se encontrou uma versão, sair do loop
      if [ -n "$kotlin_version" ]; then
        break
      fi
    fi
  done
  
  # Se ainda não encontrou, procurar em pom.xml
  if [ -z "$kotlin_version" ] && [ -f "$project_dir/pom.xml" ]; then
    if grep -q "<kotlin.version>" "$project_dir/pom.xml"; then
      kotlin_version=$(grep -oP "<kotlin.version>\K[^<]+" "$project_dir/pom.xml" | head -1)
    fi
  fi
  
  echo "$kotlin_version"
}

# Extrair versão do Gradle
extract_gradle_version() {
  local project_dir="$1"
  local gradle_version=""
  
  # Procurar no wrapper properties
  if [ -f "$project_dir/gradle/wrapper/gradle-wrapper.properties" ]; then
    # Extrair versão do URL de distribuição
    if grep -q "distributionUrl" "$project_dir/gradle/wrapper/gradle-wrapper.properties"; then
      gradle_version=$(grep -oP "gradle-\K[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-z0-9]+)?" "$project_dir/gradle/wrapper/gradle-wrapper.properties" | head -1)
    fi
  fi
  
  echo "$gradle_version"
}

# Extrair versão do Spring Boot
extract_spring_boot_version() {
  local project_dir="$1"
  local spring_boot_version=""
  
  # Procurar em arquivos Gradle
  local gradle_files=(
    "$project_dir/build.gradle"
    "$project_dir/build.gradle.kts"
    "$project_dir/gradle.properties"
  )
  
  for gradle_file in "${gradle_files[@]}"; do
    if [ -f "$gradle_file" ]; then
      # Procurar padrões comuns de definição da versão Spring Boot
      if grep -q "spring-boot" "$gradle_file" && grep -q "version" "$gradle_file"; then
        if grep -q "springBootVersion" "$gradle_file"; then
          spring_boot_version=$(grep -oP "springBootVersion\s*=\s*['\"]\K[0-9]+\.[0-9]+\.[0-9]+(\.[A-Z0-9_-]+)?" "$gradle_file" | head -1)
        elif grep -q "id[[:space:]]*('|\")org.springframework.boot" "$gradle_file" || grep -q "id[[:space:]]*('|\")spring-boot" "$gradle_file"; then
          spring_boot_version=$(grep -oP "id(\s*\(\s*|\s+)['\"]org\.springframework\.boot[^'\"]*['\"][^'\"]*['\"](\s*\))?\s+version\s+['\"]\K[0-9]+\.[0-9]+\.[0-9]+(\.[A-Z0-9_-]+)?" "$gradle_file" | head -1)
        elif grep -q "spring-boot-starter" "$gradle_file"; then
          spring_boot_version=$(grep -oP "['\"]org\.springframework\.boot:spring-boot-starter[^'\"]*['\"](,\s*)['\"]?\K[0-9]+\.[0-9]+\.[0-9]+(\.[A-Z0-9_-]+)?" "$gradle_file" | head -1)
        fi
      fi
      
      # Se encontrou uma versão, sair do loop
      if [ -n "$spring_boot_version" ]; then
        break
      fi
    fi
  done
  
  # Se ainda não encontrou, procurar em pom.xml
  if [ -z "$spring_boot_version" ] && [ -f "$project_dir/pom.xml" ]; then
    # Procurar pela versão do parent
    if grep -q "<parent>" "$project_dir/pom.xml" && grep -q "spring-boot-starter-parent" "$project_dir/pom.xml"; then
      spring_boot_version=$(grep -A10 -B2 "spring-boot-starter-parent" "$project_dir/pom.xml" | grep -oP "<version>\K[0-9]+\.[0-9]+\.[0-9]+(\.[A-Z0-9_-]+)?" | head -1)
    # Procurar pela versão da propriedade
    elif grep -q "<spring-boot.version>" "$project_dir/pom.xml" || grep -q "<spring.boot.version>" "$project_dir/pom.xml"; then
      spring_boot_version=$(grep -oP "<spring[.-]boot\.version>\K[^<]+" "$project_dir/pom.xml" | head -1)
    # Procurar pela versão de dependência
    elif grep -q "<artifactId>spring-boot" "$project_dir/pom.xml"; then
      spring_boot_version=$(grep -A3 -B1 "<artifactId>spring-boot" "$project_dir/pom.xml" | grep -oP "<version>\K[0-9]+\.[0-9]+\.[0-9]+(\.[A-Z0-9_-]+)?" | head -1)
    fi
  fi
  
  echo "$spring_boot_version"
}
