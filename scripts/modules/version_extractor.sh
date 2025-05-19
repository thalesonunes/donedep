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
      # Verificar formato específico kotlin DSL: java.sourceCompatibility = JavaVersion.VERSION_XX
      if grep -q "java\.sourceCompatibility.*JavaVersion" "$gradle_file"; then
        echo "Encontrado formato kotlin DSL java.sourceCompatibility em $gradle_file" >> "$LOG_FILE" 2>&1
        
        # Extrair a versão do JavaVersion enum (simplificado)
        if grep -q "VERSION_[0-9]" "$gradle_file"; then
          local java_enum=$(grep -oP "VERSION_\K[0-9]+" "$gradle_file" | head -1)
          java_version="$java_enum"
          echo "Extraído número da versão do java.sourceCompatibility: $java_version" >> "$LOG_FILE" 2>&1
        elif grep -q "VERSION_1_[0-9]" "$gradle_file"; then
          local java_enum=$(grep -oP "VERSION_1_\K[0-9]+" "$gradle_file" | head -1)
          java_version="1.$java_enum"
          echo "Extraído número da versão 1.x do java.sourceCompatibility: $java_version" >> "$LOG_FILE" 2>&1
        fi
        
        # Se encontrou versão, continue para o próximo passo
        if [ -n "$java_version" ]; then
          break  # Sair do loop, versão encontrada
        fi
      fi
      
      # Procurar padrões tradicionais de definição de versão Java em Gradle
      # Buscar declaração de compatibilidade Java, usando cat para evitar problemas com grep
      if cat "$gradle_file" | grep -q "sourceCompatibility.*1\."; then
        java_version=$(cat "$gradle_file" | grep "sourceCompatibility.*1\." | sed -E 's/.*sourceCompatibility.*=.*1\.([0-9]+).*/1.\1/g' | head -1)
        echo "Encontrado sourceCompatibility 1.x em $gradle_file: $java_version" >> "$LOG_FILE" 2>&1
      elif cat "$gradle_file" | grep -q "sourceCompatibility.*[0-9]"; then 
        java_version=$(cat "$gradle_file" | grep "sourceCompatibility.*[0-9]" | sed -E 's/.*sourceCompatibility.*=.*([0-9]+).*/\1/g' | head -1)
        echo "Encontrado sourceCompatibility número em $gradle_file: $java_version" >> "$LOG_FILE" 2>&1
      elif grep -q "JavaVersion\\.[A-Z_0-9]+" "$gradle_file"; then
        local java_enum=$(grep -oP "JavaVersion\.\K[A-Z_0-9]+" "$gradle_file" | head -1)
        echo "Encontrado JavaVersion enum em $gradle_file: $java_enum" >> "$LOG_FILE" 2>&1
        # Converter enum para número
        case "$java_enum" in
          VERSION_1_8) java_version="1.8" ;;
          VERSION_11) java_version="11" ;;
          VERSION_17) java_version="17" ;;
          VERSION_21) java_version="21" ;;
          VERSION_1_6) java_version="1.6" ;;
          VERSION_1_7) java_version="1.7" ;;
          VERSION_1_9) java_version="1.9" ;;
          VERSION_1_10) java_version="1.10" ;;
          VERSION_12) java_version="12" ;;
          VERSION_13) java_version="13" ;;
          VERSION_14) java_version="14" ;;
          VERSION_15) java_version="15" ;;
          VERSION_16) java_version="16" ;;
          VERSION_18) java_version="18" ;;
          VERSION_19) java_version="19" ;;
          VERSION_20) java_version="20" ;;
          *) 
            # Se não encontrou nas conversões, tentar extrair o número diretamente
            if [[ "$java_enum" =~ VERSION_([0-9]+) ]]; then
              java_version="${BASH_REMATCH[1]}"
              echo "Extraído número da versão do enum: $java_version" >> "$LOG_FILE" 2>&1
            elif [[ "$java_enum" =~ VERSION_1_([0-9]+) ]]; then
              java_version="1.${BASH_REMATCH[1]}"
              echo "Extraído número da versão 1.x do enum: $java_version" >> "$LOG_FILE" 2>&1
            else
              java_version=""
            fi
            ;;
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

  # Depurar - registrar versão final encontrada
  if [ -n "$java_version" ]; then
    echo "Versão Java final extraída: $java_version" >> "$LOG_FILE" 2>&1
  else
    echo "Nenhuma versão Java encontrada para: $project_dir" >> "$LOG_FILE" 2>&1
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
