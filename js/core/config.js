/**
 * DoneDep - Configurações Globais
 * Arquivo centralizado de configurações e constantes utilizadas na aplicação
 */

// Configurações globais da aplicação
const Config = {
  // Caminhos de arquivos e versões
  DEPENDENCIES_JSON_PATH: 'data/dependencies_20250527_185016.json', // Arquivo mais recente de dependências
  DEPENDENCIES_HISTORY_PATTERN: 'data/dependencies_*.json', // Padrão para arquivos históricos
  DEPENDENCIES_HISTORY_ENABLED: true, // Habilitar funcionalidade de histórico
  APP_VERSION: '1.0.0',

  // Configurações de filtros
  FILTERS: {
    TYPES: {
      JAVA: 'java',
      KOTLIN: 'kotlin',
      GRADLE: 'gradle',
      SPRING_BOOT: 'spring_boot'
    },
    NONE_LABEL: 'Nenhum'  // Valor especial para representar ausência de Kotlin
  },

  // Configurações de UI e timeouts
  MODAL_TIMEOUT: {
    COPY: 2000,
    FILTER: 3000,
    ERROR: 3000
  },

  UI: {
    COPY_MODAL_TIMEOUT: 2000,      // ms
    WARNING_MODAL_TIMEOUT: 3000,    // ms
    SEARCH_DEBOUNCE_DELAY: 300     // ms
  },

  // Configurações de API
  API: {
    CACHE_TIMEOUT: 300000,         // 5 minutos
    RETRY_ATTEMPTS: 3,
    RETRY_DELAY: 1000
  },

  // Configurações de debug
  DEBUG: {
    ENABLE_LOGGING: true,
    LOG_LEVEL: 'info'
  },

  // Variáveis conhecidas (versões padrão)
  KNOWN_VARIABLES: {
    'kotlinVersion': '1.9.10',
    'springBootVersion': '2.6.15',
    'oracleDriverVersion': '19.8.0.0',
    'jjwtVersion': '0.11.5',
    'swaggerVersion': '2.10.0'
  }
};

// Exportar como objeto global para compatibilidade com código existente
window.CONFIG = Config;  // Para compatibilidade com código antigo
window.Config = Config;  // Nova nomenclatura padrão
