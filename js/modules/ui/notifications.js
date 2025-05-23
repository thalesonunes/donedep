/**
 * DoneDep - Sistema de Notificações
 * Gerencia notificações e feedbacks para o usuário
 */

// Usando objetos expostos globalmente

// Tipos de notificação
const NotificationType = {
    SUCCESS: 'success',
    INFO: 'info',
    WARNING: 'warning',
    ERROR: 'error'
};

// Configurações padrão de duração por tipo
const DEFAULT_DURATIONS = {
    [NotificationType.SUCCESS]: 2000,
    [NotificationType.INFO]: 3000,
    [NotificationType.WARNING]: 4000,
    [NotificationType.ERROR]: 5000
};

// Fila de notificações
let notificationQueue = [];
let isProcessingQueue = false;

/**
 * Cria um elemento de notificação
 * @param {Object} options - Opções da notificação
 * @param {string} options.message - Mensagem da notificação
 * @param {NotificationType} options.type - Tipo da notificação
 * @param {string} [options.id] - ID opcional da notificação
 * @returns {HTMLElement} - Elemento da notificação
 */
function createNotificationElement({ message, type, id }) {
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    if (id) notification.id = id;
    
    notification.innerHTML = `
        <div class="notification-content">
            <span class="notification-message">${message}</span>
            <button class="notification-close" aria-label="Fechar">×</button>
        </div>
        <div class="notification-progress"></div>
    `;
    
    return notification;
}

/**
 * Mostra uma notificação
 * @param {Object} options - Opções da notificação
 * @param {string} options.message - Mensagem da notificação
 * @param {NotificationType} [options.type=INFO] - Tipo da notificação
 * @param {number} [options.duration] - Duração em ms (opcional)
 * @param {string} [options.id] - ID opcional da notificação
 * @returns {string} - ID da notificação
 */
function showNotification({ 
    message, 
    type = NotificationType.INFO, 
    duration,
    id = `notification-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`
}) {
    // Usar duração padrão se não especificada
    const actualDuration = duration || DEFAULT_DURATIONS[type];
    
    // Adicionar à fila
    notificationQueue.push({
        message,
        type,
        duration: actualDuration,
        id
    });
    
    // Iniciar processamento da fila se não estiver em andamento
    if (!isProcessingQueue) {
        processNotificationQueue();
    }
    
    return id;
}

/**
 * Processa a fila de notificações
 */
async function processNotificationQueue() {
    if (isProcessingQueue || notificationQueue.length === 0) return;
    
    isProcessingQueue = true;
    
    try {
        // Pegar a próxima notificação
        const notification = notificationQueue.shift();
        
        // Criar container se não existir
        let container = document.getElementById('notification-container');
        if (!container) {
            container = document.createElement('div');
            container.id = 'notification-container';
            document.body.appendChild(container);
        }
        
        // Criar e mostrar a notificação
        const element = createNotificationElement(notification);
        container.appendChild(element);
        
        // Forçar reflow para iniciar animação
        void element.offsetWidth;
        element.classList.add('show');
        
        // Configurar progresso
        const progress = element.querySelector('.notification-progress');
        if (progress) {
            progress.style.animation = `notification-progress ${notification.duration}ms linear`;
        }
        
        // Configurar botão de fechar
        const closeButton = element.querySelector('.notification-close');
        if (closeButton) {
            closeButton.addEventListener('click', () => {
                hideNotification(notification.id);
            });
        }
        
        // Remover após a duração
        await new Promise(resolve => setTimeout(resolve, notification.duration));
        await hideNotification(notification.id);
        
    } finally {
        isProcessingQueue = false;
        
        // Se ainda houver notificações na fila, continuar processando
        if (notificationQueue.length > 0) {
            processNotificationQueue();
        }
    }
}

/**
 * Esconde uma notificação específica
 * @param {string} id - ID da notificação
 * @returns {Promise<void>}
 */
async function hideNotification(id) {
    const element = document.getElementById(id);
    if (!element) return;
    
    element.classList.remove('show');
    element.classList.add('hide');
    
    // Aguardar animação de saída
    await new Promise(resolve => setTimeout(resolve, 300));
    
    element.remove();
}

/**
 * Remove todas as notificações ativas
 */
function clearAllNotifications() {
    const container = document.getElementById('notification-container');
    if (container) {
        container.innerHTML = '';
    }
    notificationQueue = [];
    isProcessingQueue = false;
}

/**
 * Mostra uma notificação de sucesso
 * @param {string} message - Mensagem de sucesso
 * @param {number} [duration] - Duração opcional
 * @returns {string} - ID da notificação
 */
function showSuccess(message, duration) {
    return showNotification({
        message,
        type: NotificationType.SUCCESS,
        duration
    });
}

/**
 * Mostra uma notificação de informação
 * @param {string} message - Mensagem informativa
 * @param {number} [duration] - Duração opcional
 * @returns {string} - ID da notificação
 */
function showInfo(message, duration) {
    return showNotification({
        message,
        type: NotificationType.INFO,
        duration
    });
}

/**
 * Mostra uma notificação de aviso
 * @param {string} message - Mensagem de aviso
 * @param {number} [duration] - Duração opcional
 * @returns {string} - ID da notificação
 */
function showWarning(message, duration) {
    return showNotification({
        message,
        type: NotificationType.WARNING,
        duration
    });
}

/**
 * Mostra uma notificação de erro
 * @param {string} message - Mensagem de erro
 * @param {number} [duration] - Duração opcional
 * @returns {string} - ID da notificação
 */
function showError(message, duration) {
    return showNotification({
        message,
        type: NotificationType.ERROR,
        duration
    });
}

// Exportar para compatibilidade com código existente
window.notifications = {
    showNotification,
    hideNotification,
    clearAllNotifications,
    showSuccess,
    showInfo,
    showWarning,
    showError,
    NotificationType
};

// Expor funções globalmente
window.NotificationType = NotificationType;
window.showNotification = showNotification;
window.hideNotification = hideNotification;
window.clearAllNotifications = clearAllNotifications;
window.showSuccess = showSuccess;
window.showInfo = showInfo;
window.showWarning = showWarning;
window.showError = showError;