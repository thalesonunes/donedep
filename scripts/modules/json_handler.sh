#!/bin/bash

# JoneDep - Manipulação de JSON
# Autor: Thales Nunes
# Data: 18/05/2025
# Versão: 1.0

# Importar módulos comuns
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Validar formato JSON
validate_json() {
  local json_file="$1"
  if [ ! -f "$json_file" ]; then
    error "Arquivo JSON não encontrado: $json_file"
    return 1
  fi
  
  # Verificar se o arquivo está vazio
  local filesize=$(wc -c < "$json_file")
  if [ "$filesize" -eq 0 ]; then
    warning "Arquivo JSON vazio: $json_file"
    return 1
  fi
  
  # Verificar por padrões de log que não deveriam estar no JSON
  if grep -q "INFO\|WARN\|ERROR\|DEBUG" "$json_file"; then
    warning "Detectadas mensagens de log no arquivo JSON: $json_file"
    echo "Encontrados padrões de log no JSON que precisam ser removidos" >> "$LOG_FILE" 2>&1
    return 1
  fi
  
  # Detectar se conteúdo é um array (começa com [) ou um objeto (começa com {)
  local first_char=$(head -c 1 "$json_file")
  local last_line=$(tail -n 1 "$json_file")
  
  # Verificar estrutura básica
  if [ "$first_char" != "[" ] && [ "$first_char" != "{" ]; then
    warning "Arquivo JSON não começa com [ ou {: $json_file"
    return 1
  fi
  
  # Verificar terminação adequada
  if [ "$first_char" = "[" ] && [[ "$last_line" != *"]"* ]]; then
    warning "Array JSON não termina com ]: $json_file"
    return 1
  fi
  
  if [ "$first_char" = "{" ] && [[ "$last_line" != *"}"* ]]; then
    warning "Objeto JSON não termina com }: $json_file"
    return 1
  fi
  
  # Usar jq para validação completa (se disponível)
  if command -v jq &> /dev/null; then
    if jq empty "$json_file" 2>/dev/null; then
      return 0
    else
      warning "Arquivo JSON inválido segundo jq: $json_file"
      return 1
    fi
  else
    # Validação adicional sem jq - procurar por padrões que indicam JSON malformado
    if grep -q "\]\[" "$json_file" || grep -q "\}\{" "$json_file"; then
      warning "Detectados problemas de formatação no JSON: $json_file"
      return 1
    fi
    
    return 0
  fi
}

# Reparar JSON inválido
repair_json() {
  local json_file="$1"
  local backup_file="${json_file}.bak"
  
  log "Tentando reparar arquivo JSON: $json_file"
  
  # Criar backup do arquivo original
  cp "$json_file" "$backup_file"
  
  # Verificar se está vazio ou totalmente inválido
  local file_size=$(wc -c < "$json_file")
  if [ "$file_size" -lt 5 ]; then
    echo "[]" > "$json_file"
    warning "Arquivo JSON estava vazio ou inválido. Criado um array vazio."
    return 0
  fi
  
  # Tentativa 1: Remover códigos de cores ANSI e mensagens de log
  sed -i 's/\x1b\[[0-9;]*m//g' "$json_file"
  sed -i 's/\[INFO[^"]*//g; s/\[WARN[^"]*//g; s/\[ERROR[^"]*//g' "$json_file"
  sed -i 's/INFO[^"]*"/""/g; s/WARN[^"]*"/""/g; s/ERROR[^"]*"/""/g; s/DEBUG[^"]*"/""/g' "$json_file"
  
  # Tentativa 2: Corrigir problemas específicos com as dependências
  sed -i 's/"dependencies": \[[^]]*INFO[^]]*\]/"dependencies": []/' "$json_file"
  
  # Tentativa 3: Remoção de vírgulas extras
  sed -i 's/,\s*\}/}/g; s/,\s*\]/]/g' "$json_file"
  
  # Tentativa 4: Adicionar aspas em chaves sem aspas
  sed -i 's/{\s*\([a-zA-Z0-9_]*\)\s*:/{"\\1":/g' "$json_file"
  
  # Tentativa 5: Corrigir problemas com escape de caracteres especiais
  # Não usamos isso diretamente, pois pode causar problemas
  # sed -i 's/\\/\\\\/g; s/"/\\"/g' "$json_file"
  
  # Tentativa 6: Certificar que o arquivo começa com [ e termina com ]
  local content=$(cat "$json_file")
  if [[ ! "$content" =~ ^\s*\[ ]]; then
    content="[ $content"
  fi
  if [[ ! "$content" =~ \]\s*$ ]]; then
    content="$content ]"
  fi
  echo "$content" > "$json_file"
  
  # Verificar se o reparo foi bem-sucedido
  if validate_json "$json_file"; then
    success "Arquivo JSON reparado com sucesso: $json_file"
    return 0
  else
    warning "Falha ao reparar JSON, restaurando backup: $json_file"
    cp "$backup_file" "$json_file"
    return 1
  fi
}

# Escapar valores JSON
escape_json_value() {
  local value="$1"
  
  # Remover códigos de cores ANSI
  value=$(echo "$value" | sed 's/\x1b\[[0-9;]*m//g')
  
  # Remover caracteres de nova linha e retorno antes de escapar
  value=$(echo "$value" | tr -d '\n\r')
  
  # Substituir caracteres não permitidos em nomes de projetos por traços
  value=$(echo "$value" | sed 's/[^a-zA-Z0-9\._\-]/-/g')
  
  # Substituir aspas, barras invertidas, etc.
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//	/\\t}"
  
  echo "$value"
}

# Gerar JSON para um projeto
generate_json() {
  local project_name="$1"
  local java_version="$2"
  local kotlin_version="$3"
  local gradle_version="$4"
  local spring_boot_version="$5"
  local dependencies="$6"
  local modules="$7"
  
  # Escapar aspas nos nomes
  local escaped_project_name=$(escape_json_value "$project_name")
  
  # Início do objeto JSON
  local json="{"
  json+="\"project\": \"$escaped_project_name\""
  
  # Adicionar versões se disponíveis
  if [ -n "$java_version" ]; then
    json+=", \"javaVersion\": \"$java_version\""
  fi
  
  if [ -n "$kotlin_version" ]; then
    json+=", \"kotlinVersion\": \"$kotlin_version\""
  fi
  
  if [ -n "$gradle_version" ]; then
    json+=", \"gradleVersion\": \"$gradle_version\""
  fi
  
  if [ -n "$spring_boot_version" ]; then
    json+=", \"springBootVersion\": \"$spring_boot_version\""
  fi
  
  # Adicionar dependências
  if [ -n "$dependencies" ]; then
    # Verificar se as dependências estão no formato de array
    if [[ "$dependencies" == \[* && "$dependencies" == *\] ]]; then
      # Limpar quaisquer mensagens de log ou textos que possam estar misturados
      # Esta regex procura por qualquer texto que comece com "INFO", "WARN", "ERROR", etc.
      clean_deps=$(echo "$dependencies" | sed 's/\[INFO[^"]*//g; s/\[WARN[^"]*//g; s/\[ERROR[^"]*//g; s/INFO[^"]*"/""/g; s/WARN[^"]*"/""/g; s/ERROR[^"]*"/""/g; s/DEBUG[^"]*"/""/g')
      
      # Remove quaisquer códigos de formatação ANSI
      clean_deps=$(echo "$clean_deps" | sed 's/\x1b\[[0-9;]*m//g')
      
      # Verificação adicional para garantir que ainda temos um array válido
      if [[ "$clean_deps" == \[* && "$clean_deps" == *\] ]]; then
        json+=", \"dependencies\": $clean_deps"
      else
        # Último recurso: se o array foi corrompido, usar array vazio
        json+=", \"dependencies\": []"
        echo "Aviso: Array de dependências foi corrompido ou não está no formato válido" >> "$LOG_FILE" 2>&1
      fi
    else
      # Limpar e formatar como array
      # Remover caracteres potencialmente problemáticos e mensagens de log
      dependencies=$(echo "$dependencies" | sed 's/\x1b\[[0-9;]*m//g; s/\[INFO[^"]*//g; s/\[WARN[^"]*//g; s/\[ERROR[^"]*//g; s/INFO[^"]*"/""/g; s/WARN[^"]*"/""/g; s/ERROR[^"]*"/""/g; s/DEBUG[^"]*"/""/g')
      
      # Se não começar com [ ou não terminar com ], adicionar
      if [[ "$dependencies" != \[* ]]; then
        dependencies="[$dependencies"
      fi
      if [[ "$dependencies" != *\] ]]; then
        dependencies="$dependencies]"
      fi
      
      json+=", \"dependencies\": $dependencies"
    fi
  else
    json+=", \"dependencies\": []"
  fi
  
  # Adicionar módulos
  if [ -n "$modules" ]; then
    # Verificar se os módulos estão no formato de array
    if [[ "$modules" == \[* && "$modules" == *\] ]]; then
      json+=", \"modules\": $modules"
    else
      # Se não for um array válido, usar array vazio
      json+=", \"modules\": []"
    fi
  else
    json+=", \"modules\": []"
  fi
  
  # Encerramento do objeto JSON
  json+="}"
  
  echo "$json"
}

# Finalizar saída JSON
finalize_json_output() {
  local json_array="$1"
  local output_file="$2"
  local pretty_print="$3"
  
  # Garantir que terminamos com um array válido
  if [ -z "$json_array" ] || [ "$json_array" == "[]" ]; then
    echo "[]" > "$output_file"
    warning "Nenhuma dependência encontrada."
    return 1
  fi
  
  # Salvar resultado em arquivo
  echo "$json_array" > "$output_file"
  
  # Validar o JSON final
  if ! validate_json "$output_file"; then
    error "Erro na saída JSON. Tentando reparar..."
    if repair_json "$output_file"; then
      success "JSON reparado com sucesso!"
    else
      error "Não foi possível reparar o JSON. Verifique manualmente."
      return 1
    fi
  fi
  
  # Criar versão formatada se necessário
  if [ "$pretty_print" = true ] && command -v jq &> /dev/null; then
    local formatted_file="${output_file%.json}.min"
    jq -c '.' "$output_file" > "$formatted_file"
    success "Arquivo JSON minificado criado: $formatted_file"
  fi
  
  success "Processo finalizado. JSON salvo em: $output_file"
  return 0
}

# Verificar se uma string é um JSON válido
is_valid_json() {
  local json_string="$1"
  
  # Verificar se está vazio
  if [ -z "$json_string" ]; then
    return 1
  fi
  
  # Verificar se começa e termina corretamente
  local first_char="${json_string:0:1}"
  local last_char="${json_string: -1}"
  
  if [ "$first_char" != "{" ] && [ "$first_char" != "[" ]; then
    return 1
  fi
  
  if [ "$first_char" = "{" ] && [ "$last_char" != "}" ]; then
    return 1
  fi
  
  if [ "$first_char" = "[" ] && [ "$last_char" != "]" ]; then
    return 1
  fi
  
  # Verificar por padrões de log que não deveriam estar no JSON
  if echo "$json_string" | grep -q "INFO\|WARN\|ERROR\|DEBUG"; then
    return 1
  fi
  
  # Usar jq se disponível para validação completa
  if command -v jq &> /dev/null; then
    if echo "$json_string" | jq empty 2>/dev/null; then
      return 0
    else
      return 1
    fi
  fi
  
  # Validação básica bem-sucedida se jq não estiver disponível
  return 0
}
