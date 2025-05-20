#!/bin/bash

# JoneDep - Extrator de versões de tecnologias
# Autor: Thales Nunes
# Data: 18/05/2025
# Versão: 1.1

# Importar módulos comuns
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Definir LOG_FILE se não estiver definido
if [ -z "$LOG_FILE" ]; then
  LOG_FILE="/tmp/jone_dep_extraction.log"
fi

# Função para normalizar versões do Java
normalize_java_version() {
  local version="$1"
  # Se a versão começa com 1. e tem outro número depois, usar apenas o segundo número
  if [[ "$version" =~ ^1\.([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "$version"
  fi
}

# Extrair versão do Java
extract_java_version() {
  local project_dir="$1"
  local java_version=""
  
  debug_log "Extraindo Java version do projeto $(basename "$project_dir")"
  
  # Verificar diretamente por padrões específicos que sabemos existir
  # Verificar primeiro o padrão [compileKotlin, compileTestKotlin]*.kotlinOptions { jvmTarget = "1.8" }
  if [ -f "$project_dir/build.gradle" ] && grep -q "\[compileKotlin" "$project_dir/build.gradle"; then
    local version_str=$(grep -A 5 "\[compileKotlin" "$project_dir/build.gradle" | grep -oP "jvmTarget\s*=\s*[\"']\K[0-9.]+")
    if [ -n "$version_str" ]; then
      java_version="$version_str"
      debug_log "Encontrado padrão [compileKotlin] diretamente, versão: $java_version"
      echo "$java_version"
      return 0
    fi
  fi
  
  # Buscar em arquivos Gradle
  local gradle_files=(
    "$project_dir/build.gradle"
    "$project_dir/build.gradle.kts"
    "$project_dir/gradle.properties"
  )
  
  # Procurar em build.gradle e build.gradle.kts
  for gradle_file in "${gradle_files[@]}"; do
    if [ -f "$gradle_file" ]; then
      debug_log "Processando arquivo $gradle_file"
      
      # Para arquivos Kotlin DSL (.kts): Verificar padrão configure<JavaPluginExtension>
      if [[ "$gradle_file" == *".kts" ]] && grep -q "configure<JavaPluginExtension>" "$gradle_file"; then
        debug_log "Encontrado formato Kotlin DSL configure<JavaPluginExtension> em $gradle_file"
        
        # Extrair o bloco JavaPluginExtension completo
        local configure_block=$(sed -n '/configure<JavaPluginExtension>/,/}/p' "$gradle_file")
        
        # Verificar se o bloco contém sourceCompatibility com JavaVersion
        if echo "$configure_block" | grep -q "sourceCompatibility.*=.*JavaVersion\.VERSION_[0-9]\+"; then
          debug_log "Encontrado JavaVersion.VERSION_XX no bloco configure<JavaPluginExtension>"
          local version_num=$(echo "$configure_block" | grep -oP "VERSION_\K[0-9]+" | head -1)
          if [ -n "$version_num" ]; then
            java_version="$version_num"
            debug_log "Extraído número da versão do bloco configure<JavaPluginExtension>: $java_version"
            # Debug - registrar o valor extraído
            debug_log "Extraído Java versão $java_version do bloco configure<JavaPluginExtension> em $gradle_file"
          fi
        fi
        
        # Se encontrou versão, continue para o próximo passo
        if [ -n "$java_version" ]; then
          break  # Sair do loop, versão encontrada
        fi
      fi
      
      # Verificar formato específico kotlin DSL: java.sourceCompatibility = JavaVersion.VERSION_XX
      if grep -q "java\.sourceCompatibility.*JavaVersion" "$gradle_file"; then
        debug_log "Encontrado formato kotlin DSL java.sourceCompatibility em $gradle_file"
        
        # Extrair a versão do JavaVersion enum (simplificado)
        if grep -q "VERSION_[0-9]" "$gradle_file"; then
          local java_enum=$(grep -oP "VERSION_\K[0-9]+" "$gradle_file" | head -1)
          java_version="$java_enum"
          debug_log "Extraído número da versão do java.sourceCompatibility: $java_version"
        elif grep -q "VERSION_1_[0-9]" "$gradle_file"; then
          local java_enum=$(grep -oP "VERSION_1_\K[0-9]+" "$gradle_file" | head -1)
          java_version="1.$java_enum"
          debug_log "Extraído número da versão 1.x do java.sourceCompatibility: $java_version"
        fi
        
        # Se encontrou versão, continue para o próximo passo
        if [ -n "$java_version" ]; then
          break  # Sair do loop, versão encontrada
        fi
      fi
      
      # Procurar padrões tradicionais de definição de versão Java em Gradle
      # Buscar declaração de compatibilidade Java
      
      # Primeiro verificar o formato 1.x (mais específico) para evitar extração incorreta
      if grep -q "sourceCompatibility\s*=\s*1\.[0-9]\+" "$gradle_file"; then
        java_version=$(grep -oP "sourceCompatibility\s*=\s*1\.\K[0-9]+" "$gradle_file" | sed -E 's/([0-9]+).*/1.\1/g' | head -1)
        debug_log "Encontrado sourceCompatibility 1.x em $gradle_file: $java_version"
        debug_log "Extraído Java versão $java_version de sourceCompatibility 1.x em $gradle_file"
      # Depois verificar o padrão simples sourceCompatibility = 17 diretamente
      elif grep -q "sourceCompatibility\s*=\s*[0-9]\+" "$gradle_file"; then
        # Extrair número diretamente usando grep -oP
        java_version=$(grep -oP "sourceCompatibility\s*=\s*\K[0-9]+" "$gradle_file" | head -1)
        debug_log "Encontrado sourceCompatibility número direto em $gradle_file: $java_version"
        # Debug
        debug_log "Extraído Java versão $java_version de sourceCompatibility direto em $gradle_file"
      # CORRIGIDO: Verificar blocos java { sourceCompatibility = JavaVersion.VERSION_XX }
      elif grep -q "java\s*{" "$gradle_file"; then
        debug_log "Encontrado bloco java { } em $gradle_file"
        
        # Verificar diretamente no arquivo para o padrão JavaVersion.VERSION_XX
        # Essa abordagem evita problemas com a extração do bloco java
        if grep -q "sourceCompatibility.*JavaVersion\.VERSION_[0-9]\+" "$gradle_file"; then
          debug_log "Encontrado JavaVersion.VERSION_XX no arquivo"
          
          # Usar grep -o para extrair apenas a parte relevante e garantir precisão
          local version_str=$(grep -o "JavaVersion\.VERSION_[0-9]\+" "$gradle_file" | head -1)
          local version_num=$(echo "$version_str" | grep -oP "VERSION_\K[0-9]+" | head -1)
          
          # Debug - imprimir extração detalhada
          debug_log "String completa: $version_str, Número extraído: $version_num"
          
          if [ -n "$version_num" ]; then
            java_version="$version_num"
            debug_log "Extraído número da versão do bloco java: $java_version"
            # Debug adicional
            debug_log "Extraído Java versão $java_version de $gradle_file"
          else
            debug_log "FALHA: Não foi possível extrair número da versão do $version_str"
          fi
        else
          # Extrair bloco java completo usando sed como fallback
          debug_log "Tentando extrair do bloco java usando sed"
          local java_block=$(sed -n '/java\s*{/,/}/p' "$gradle_file")
          
          # Verificar se o bloco contém sourceCompatibility com JavaVersion
          if echo "$java_block" | grep -q "sourceCompatibility.*JavaVersion\.VERSION_[0-9]\+"; then
            debug_log "Encontrado JavaVersion.VERSION_XX no bloco java"
            local version_num=$(echo "$java_block" | grep -oP "VERSION_\K[0-9]+" | head -1)
            if [ -n "$version_num" ]; then
              java_version="$version_num"
              debug_log "Extraído número da versão do bloco java: $java_version"
            fi
          fi
        fi
      elif grep -q "java\s*{" "$gradle_file" && grep -q "toolchain\s*{" "$gradle_file"; then
        # Buscar em blocos java { toolchain { languageVersion.set(JavaLanguageVersion.of(XX)) } }
        if grep -q "languageVersion.set" "$gradle_file"; then
          java_version=$(grep -oP "languageVersion\.set\(JavaLanguageVersion\.of\(\K[0-9]+" "$gradle_file" | head -1)
        fi
      # Verificar padrão Kotlin DSL para KotlinCompile com jvmTarget
      elif [[ "$gradle_file" == *".kts" ]] && grep -q "tasks.withType<KotlinCompile>" "$gradle_file"; then
        debug_log "Encontrado padrão tasks.withType<KotlinCompile> em $gradle_file"
        # Extrair bloco KotlinCompile completo
        local kotlin_compile_block=$(sed -n '/tasks.withType<KotlinCompile>/,/}/p' "$gradle_file")
        
        # Verificar se o bloco contém jvmTarget com versão
        if echo "$kotlin_compile_block" | grep -q "jvmTarget\s*=\s*[\"'][0-9]\+[\"']"; then
          local version_num=$(echo "$kotlin_compile_block" | grep -oP "jvmTarget\s*=\s*[\"']\K[0-9]+" | head -1)
          if [ -n "$version_num" ]; then
            java_version="$version_num"
            debug_log "Extraído número da versão do jvmTarget em tasks.withType<KotlinCompile>: $java_version"
            debug_log "Extraído Java versão $java_version do jvmTarget em $gradle_file"
          fi
        fi
      # Verificar padrão Groovy para compileKotlin kotlinOptions com jvmTarget
      elif grep -q "compileKotlin" "$gradle_file" && grep -q "kotlinOptions" "$gradle_file" && grep -q "jvmTarget" "$gradle_file"; then
        debug_log "Encontrado padrão com compileKotlin e kotlinOptions em $gradle_file"
        
        # Verificar especificamente pelo padrão [compileKotlin, compileTestKotlin]*.kotlinOptions
        if grep -q "\[compileKotlin" "$gradle_file"; then
          debug_log "Encontrado padrão [compileKotlin... no arquivo $gradle_file"
          
          # Extrair diretamente a versão do jvmTarget
          local version_str=$(grep -A 5 "\[compileKotlin" "$gradle_file" | grep -oP "jvmTarget\s*=\s*[\"']\K[0-9.]+")
          
          if [ -n "$version_str" ]; then
            java_version="$version_str"
            debug_log "Extraído número da versão do jvmTarget com [compileKotlin: $java_version"
            debug_log "Extraído Java versão $java_version do jvmTarget em $gradle_file"
          fi
        # Verificar outros padrões de compileKotlin
        else
          # Usar grep direto para tentar outros padrões
          local version_str=$(grep -A 5 "compileKotlin.*kotlinOptions" "$gradle_file" | grep -oP "jvmTarget\s*=\s*[\"']\K[0-9.]+" | head -1)
          
          if [ -n "$version_str" ]; then
            java_version="$version_str"
            debug_log "Extraído número da versão do jvmTarget de outro padrão compileKotlin: $java_version"
          fi
        fi
      elif grep -q "JavaVersion\\.[A-Z_0-9]+" "$gradle_file"; then
        local java_enum=$(grep -oP "JavaVersion\.\K[A-Z_0-9]+" "$gradle_file" | head -1)
        debug_log "Encontrado JavaVersion enum em $gradle_file: $java_enum"
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
              debug_log "Extraído número da versão do enum: $java_version"
            elif [[ "$java_enum" =~ VERSION_1_([0-9]+) ]]; then
              java_version="1.${BASH_REMATCH[1]}"
              debug_log "Extraído número da versão 1.x do enum: $java_version"
            else
              java_version=""
            fi
            ;;
        esac
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
    # Normalizar a versão do Java antes de retorná-la
    java_version=$(normalize_java_version "$java_version")
    debug_log "Versão Java final normalizada: $java_version para projeto $(basename "$project_dir")"
  else
    debug_log "Nenhuma versão Java encontrada para: $project_dir"
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
