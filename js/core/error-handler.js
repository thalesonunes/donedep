/**
 * JoneDep - Tratamento de Erros
 * Sistema centralizado para manipulação de erros na aplicação
 */

// Níveis de erro
const ErrorLevel = {
  DEBUG: 'debug',
  INFO: 'info',
  WARNING: 'warning',
  ERROR: 'error',
  CRITICAL: 'critical'
};

// Tipos de erro
const ErrorType = {
  DATA_LOAD: 'data_load',        // Erro ao carregar dados
  PARSE: 'parse',                // Erro ao analisar dados
  FILTER: 'filter',              // Erro ao aplicar filtros
  RENDER: 'render',              // Erro ao renderizar componentes
  RUNTIME: 'runtime',            // Erro de tempo de execução
  VALIDATION: 'validation',      // Erro de validação de dados
  USER_ACTION: 'user_action',    // Erro em ação do usuário
  UI: 'ui',                      // Erro de interface
  NETWORK: 'network'             // Erro de rede
};

// Histórico de erros para logging
let errorHistory = [];

/**
 * Registra um erro no sistema
 * @param {Object} options - Opções do erro
 * @param {string} options.message - Mensagem de erro
 * @param {ErrorType} options.type - Tipo de erro
 * @param {ErrorLevel} options.level - Nível de erro
 * @param {Error} [options.originalError] - Objeto Error original (opcional)
 * @param {Object} [options.context] - Dados de contexto adicionais (opcional)
 * @returns {string} ID do erro registrado
 */
function logError({ message, type, level, originalError, context = {} }) {
  // Gerar ID único para o erro
  const errorId = `err_${Date.now()}_${Math.random().toString(36).substr(2, 5)}`;
  
  const errorInfo = {
    id: errorId,
    message,
    type,
    level,
    timestamp: new Date().toISOString(),
    context: { ...context }
  };
  
  if (originalError) {
    errorInfo.originalError = {
      message: originalError.message,
      stack: originalError.stack
    };
  }
  
  // Registrar erro no console
  const consoleMethod = level === ErrorLevel.INFO 
    ? console.info 
    : level === ErrorLevel.WARNING 
      ? console.warn 
      : console.error;
  
  consoleMethod(`[${type}]`, message, errorInfo);
  
  // Adicionar ao histórico
  errorHistory.push(errorInfo);
  
  // Limitar tamanho do histórico
  if (errorHistory.length > 100) {
    errorHistory.shift();
  }
  
  return errorId;
}

/**
 * Exibe um erro para o usuário
 * @param {string} message - Mensagem a ser exibida
 * @param {string} [suggestion] - Sugestão para resolver o problema (opcional)
 * @param {string} [container] - ID do elemento onde mostrar o erro (opcional)
 */
function showErrorToUser(message, suggestion, container = 'dependencies-grid') {
  const containerElement = document.getElementById(container);
  if (!containerElement) return;
  
  const errorHtml = `
    <div class="error-container">
      <div class="error-title">Erro</div>
      <div class="error-message">${message}</div>
      ${suggestion ? `<div class="error-suggestion">${suggestion}</div>` : ''}
      <div class="error-action">
        <button class="retry-button" onclick="location.reload()">Tentar Novamente</button>
      </div>
    </div>
  `;
  
  containerElement.innerHTML = errorHtml;
}

/**
 * Mostra uma notificação de erro em um modal
 * @param {string} message - Mensagem de erro
 * @param {ErrorLevel} level - Nível de erro
 */
function showErrorModal(message, level = ErrorLevel.ERROR) {
  // Selecionar o modal apropriado com base no nível de erro
  const modalId = level === ErrorLevel.WARNING ? 'warning-modal' : 'error-modal';
  const modal = document.getElementById(modalId) || document.getElementById('incompatible-modal');
  
  if (!modal) {
    console.error('Modal de erro não encontrado:', modalId);
    return;
  }
  
  // Atualizar conteúdo do modal
  const titleElement = modal.querySelector('[id$=-modal-title]');
  const contentElement = modal.querySelector('[id$=-modal-content]') || modal;
  
  if (titleElement) {
    titleElement.textContent = level === ErrorLevel.WARNING ? 'Aviso' : 'Erro';
  }
  
  // Buscar elemento de mensagem no modal ou criar um
  let messageElement = modal.querySelector('[id$=-modal-text]');
  if (!messageElement) {
    messageElement = document.createElement('div');
    messageElement.className = 'modal-message';
    contentElement.appendChild(messageElement);
  }
  
  messageElement.textContent = message;
  
  // Mostrar o modal
  modal.classList.remove('show');
  void modal.offsetWidth; // Forçar reflow para reiniciar a animação
  modal.classList.add('show');
  
  // Esconder o modal após timeout
  const timeout = level === ErrorLevel.WARNING 
    ? window.Config.MODAL_TIMEOUT.FILTER 
    : window.Config.MODAL_TIMEOUT.FILTER * 1.5;
  
  setTimeout(() => {
    modal.classList.remove('show');
  }, timeout);
}

/**
 * Limpa o histórico de erros
 */
function clearErrorHistory() {
  errorHistory = [];
}

/**
 * Obtém o histórico de erros
 * @returns {Array} Histórico de erros registrados
 */
function getErrorHistory() {
  return [...errorHistory];
}

/**
 * Trata e exibe erro na interface
 * @param {Error} error - Erro a ser tratado
 * @param {string} title - Título do erro
 * @param {string} suggestion - Sugestão de resolução
 */
function handleError(error, title, suggestion = null) {
  // Registrar erro
  const errorId = logError({
    message: error.message,
    type: error.type || ErrorType.RUNTIME,
    level: ErrorLevel.ERROR,
    originalError: error
  });

  // Exibir mensagem detalhada na interface
  showErrorToUser(error.message, suggestion);
}

// Manipulador global de erros não capturados
window.addEventListener('error', function(event) {
  logError({
    message: `Erro não capturado: ${event.message || 'Erro desconhecido'}`,
    type: ErrorType.RUNTIME,
    level: ErrorLevel.ERROR,
    originalError: event.error,
    context: {
      location: event.filename,
      lineNumber: event.lineno,
      colNumber: event.colno
    }
  });
  
  // Não exibir erros técnicos ao usuário em ambiente de produção
  if (window.location.hostname === 'localhost') {
    showErrorModal(`Erro não capturado: ${event.message || 'Erro desconhecido'}`);
  } else {
    showErrorModal('Ocorreu um erro inesperado na aplicação.');
  }
});

// Manipulador global de rejeições de promessas não capturadas
window.addEventListener('unhandledrejection', function(event) {
  logError({
    message: `Promessa rejeitada não capturada: ${event.reason || 'Razão desconhecida'}`,
    type: ErrorType.RUNTIME,
    level: ErrorLevel.ERROR,
    originalError: event.reason instanceof Error ? event.reason : new Error(String(event.reason)),
    context: {
      promise: event.promise
    }
  });
});

// Exportar para compatibilidade com código existente
window.ErrorLevel = ErrorLevel;
window.ErrorType = ErrorType;
window.errorHandler = {
  logError,
  showErrorToUser,
  showErrorModal,
  handleError,
  clearErrorHistory,
  getErrorHistory,
  ErrorLevel,
  ErrorType
};
