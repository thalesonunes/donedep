/**
 * DoneDep - Sistema de Modais
 * Funções para gerenciar e exibir modais na aplicação
 */

// Usando Config global

/**
 * Mostra um modal customizado
 * @param {Object|string} options - Opções do modal ou ID do modal
 * @param {string} [options.modalId] - ID do elemento HTML do modal
 * @param {string} [options.message] - Mensagem a ser exibida
 * @param {number} [options.timeout=2000] - Tempo em ms até fechar o modal
 */
function showModal(options) {
  // Compatibilidade com chamadas antigas que passavam só o ID do modal
  let modalId, message, timeout;
  
  if (typeof options === 'string') {
    modalId = options;
    message = null;
    timeout = Config.MODAL_TIMEOUT.COPY;
  } else {
    // Formato atual com objeto de opções
    modalId = options.modalId;
    message = options.message;
    timeout = options.timeout || Config.MODAL_TIMEOUT.COPY;
  }
  
  const modal = document.getElementById(modalId);
  if (!modal) {
    console.error(`Modal não encontrado: ${modalId}`);
    return;
  }
  
  // Encontrar o elemento de texto do modal
  const textElement = modal.querySelector('[id$=-modal-text]');
  if (textElement && message) {
    textElement.textContent = message;
  }
  
  // Remover a classe show caso já esteja aplicada
  modal.classList.remove('show');
  
  // Forçar reflow para reiniciar a animação
  void modal.offsetWidth;
  
  modal.classList.add('show');
  
  // Esconder o modal após o timeout especificado
  setTimeout(() => {
    modal.classList.remove('show');
  }, timeout);
}

/**
 * Mostra o modal de cópia
 * @param {string} message - Mensagem a ser exibida
 */
function showCopyModal(message = 'Copiado com sucesso!') {
  showModal({
    modalId: 'copy-modal',
    message,
    timeout: Config.MODAL_TIMEOUT.COPY
  });
}

/**
 * Mostra o modal de filtros incompatíveis
 */
function showIncompatibleModal() {
  showModal({
    modalId: 'incompatible-modal',
    timeout: Config.MODAL_TIMEOUT.FILTER
  });
}

/**
 * Mostra o modal de filtro bloqueado
 */
function showFilterLockedModal() {
  const lockedModal = document.getElementById('locked-filter-modal');
  if (!lockedModal) {
    console.warn('Modal de filtro bloqueado não encontrado');
    return;
  }
  
  lockedModal.classList.remove('show');
  void lockedModal.offsetWidth;
  lockedModal.classList.add('show');
  
  setTimeout(() => {
    lockedModal.classList.remove('show');
  }, Config.MODAL_TIMEOUT.FILTER);
}

/**
 * Fecha o modal de filtro bloqueado
 */
function closeFilterLockedModal() {
  const modal = document.getElementById('filter-locked-modal');
  if (modal) {
    modal.classList.remove('show');
  }
}

// Event listener initialization
document.addEventListener('DOMContentLoaded', () => {
  const closeFilterLockedModalBtn = document.getElementById('close-filter-locked-modal');
  if (closeFilterLockedModalBtn) {
    closeFilterLockedModalBtn.addEventListener('click', () => closeFilterLockedModal());
  }
});

// Exportar para compatibilidade com código existente
window.modals = {
  showModal,
  showCopyModal,
  showIncompatibleModal,
  showFilterLockedModal,
  closeFilterLockedModal
};

// Expor funções globalmente para serem usadas por outros scripts
window.showModal = showModal;
window.showCopyModal = showCopyModal;
window.showIncompatibleModal = showIncompatibleModal;
window.showFilterLockedModal = showFilterLockedModal;
window.closeFilterLockedModal = closeFilterLockedModal;
