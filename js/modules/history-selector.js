/**
 * DoneDep - Seletor de Histórico de Dependências
 * 
 * Este módulo adiciona um seletor para escolher entre diferentes arquivos de dependências
 * com timestamp, permitindo ao usuário visualizar dados históricos.
 */

(function() {
  // Variáveis para elementos do DOM
  let fileSelector;
  let filesData = [];
  let initialized = false;
  
  // Função para inicializar o componente
  function initHistorySelector() {
    // Evitar múltiplas inicializações
    if (initialized) {
      console.log("Seletor de histórico já inicializado.");
      return;
    }

    console.log("Inicializando seletor de histórico...");
    // Verificar se o histórico está habilitado nas configurações
    if (!window.Config.DEPENDENCIES_HISTORY_ENABLED) {
      console.log("Histórico de dependências desabilitado nas configurações.");
      return;
    }
    
    // Criar elemento de seleção
    createSelectorElement();
    
    // Carregar a lista de arquivos disponíveis
    loadFilesList();
    initialized = true;
    console.log("Seletor de histórico inicializado com sucesso.");
  }
  
  // Criar o elemento de seleção no DOM
  function createSelectorElement() {
    console.log("Criando elemento seletor...");
    
    // Obter o container que já existe no HTML
    const selectorContainer = document.getElementById('history-selector-container');
    if (!selectorContainer) {
      console.error("Container para seletor de histórico não encontrado no HTML");
      return;
    }
    
    // Limpar conteúdo existente
    selectorContainer.innerHTML = '';
    
    // Criar select
    fileSelector = document.createElement('select');
    fileSelector.id = 'history-file-selector';
    fileSelector.className = 'history-file-selector';
    selectorContainer.appendChild(fileSelector);
    console.log("Elementos do seletor adicionados ao container");
    
    // Adicionar evento de mudança
    fileSelector.addEventListener('change', handleFileChange);
  }
  

  
  // Carregar a lista de arquivos disponíveis
  async function loadFilesList() {
    try {
      console.log("Carregando lista de arquivos de dependências...");
      filesData = await window.api.listDependencyFiles();
      console.log("Arquivos encontrados:", filesData);
      
      if (!fileSelector) {
        console.error("Seletor de arquivo não inicializado corretamente!");
        return;
      }
      
      // Limpar opções existentes
      fileSelector.innerHTML = '';
      
      // Adicionar opções para cada arquivo
      filesData.forEach(file => {
        const option = document.createElement('option');
        option.value = file.path;
        
        // Formatar o texto da opção para sempre mostrar o nome do arquivo
        let optionText = file.name;
        
        // Se for um arquivo com timestamp, formatar como YYYY-MM-DD HH:MM:SS
        if (file.name && file.name.match(/dependencies_(\d{8})_(\d{6})\.json/)) {
          const match = file.name.match(/dependencies_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})\.json/);
          if (match) {
            optionText = `${match[1]}-${match[2]}-${match[3]} ${match[4]}:${match[5]}:${match[6]}`;
          }
        }
        
        option.textContent = optionText;
        
        // Marcar o arquivo mais recente como selecionado
        const timestamp = file.name.match(/dependencies_(\d{8})_(\d{6})\.json/);
        if (timestamp) {
          option.dataset.timestamp = timestamp[1] + timestamp[2];
        }
        
        fileSelector.appendChild(option);
      });
      
      // Selecionar o arquivo mais recente
      if (fileSelector.options.length > 0) {
        const options = Array.from(fileSelector.options);
        const latestOption = options.reduce((latest, current) => {
          if (!latest.dataset.timestamp) return current;
          if (!current.dataset.timestamp) return latest;
          return current.dataset.timestamp > latest.dataset.timestamp ? current : latest;
        });
        latestOption.selected = true;
      }
    } catch (error) {
      console.error('Erro ao carregar lista de arquivos:', error);
      // Adicionar pelo menos uma opção para o arquivo padrão
      const defaultOption = document.createElement('option');
      defaultOption.value = window.Config.DEPENDENCIES_JSON_PATH;
      defaultOption.textContent = 'Arquivo de dependências atual';
      defaultOption.selected = true;
      fileSelector.appendChild(defaultOption);
    }
  }
  
  // Manipular mudança de arquivo selecionado
  function handleFileChange(event) {
    const selectedPath = event.target.value;
    
    // Mostrar mensagem de carregamento
    showLoadingMessage();
    
    // Carregar os dados do arquivo selecionado
    window.api.loadDependencies(selectedPath)
      .then(data => {
        // Recarregar a visualização com os novos dados
        if (typeof window.reloadVisualization === 'function') {
          window.reloadVisualization(data);
        } else {
          // Se a função específica não existir, tentar recarregar a página
          location.reload();
        }
        
        // Esconder mensagem de carregamento
        hideLoadingMessage();
      })
      .catch(error => {
        console.error('Erro ao carregar arquivo de dependências:', error);
        showErrorMessage('Erro ao carregar o arquivo selecionado.');
      });
  }
  
  // Mostrar mensagem de carregamento
  function showLoadingMessage() {
    // Verificar se já existe um elemento de mensagem
    let messageElement = document.getElementById('loading-message');
    if (!messageElement) {
      messageElement = document.createElement('div');
      messageElement.id = 'loading-message';
      messageElement.className = 'loading-message';
      messageElement.textContent = 'Carregando dados...';
      document.body.appendChild(messageElement);
    } else {
      messageElement.style.display = 'block';
    }
  }
  
  // Esconder mensagem de carregamento
  function hideLoadingMessage() {
    const messageElement = document.getElementById('loading-message');
    if (messageElement) {
      messageElement.style.display = 'none';
    }
  }
  
  // Mostrar mensagem de erro
  function showErrorMessage(message) {
    // Se tiver um sistema de notificação existente, usá-lo
    if (typeof window.showNotification === 'function') {
      window.showNotification({
        type: 'error',
        message: message,
        duration: 5000
      });
      return;
    }
    
    // Caso contrário, criar uma mensagem simples
    let errorMessage = document.getElementById('error-message');
    if (!errorMessage) {
      errorMessage = document.createElement('div');
      errorMessage.id = 'error-message';
      errorMessage.className = 'error-message';
      document.body.appendChild(errorMessage);
    }
    
    errorMessage.textContent = message;
    errorMessage.style.display = 'block';
    
    // Esconder após 5 segundos
    setTimeout(() => {
      errorMessage.style.display = 'none';
    }, 5000);
  }
  
  // Exportar função para recarregar a visualização com novos dados
  function reloadVisualization(data) {
    // Esta função deve ser implementada pelo código principal
    // ou substituída por uma implementação específica
    console.log('Recarregando visualização com novos dados:', data.length, 'projetos');
    
    // Limpar a exibição atual
    const projectsContainer = document.getElementById('projects-container');
    if (projectsContainer) {
      projectsContainer.innerHTML = '';
    }
    
    // Reinicializar a exibição com os novos dados
    if (typeof window.initializeProjectsView === 'function') {
      window.initializeProjectsView(data);
    }
  }
  
  // Exportar funções para serem usadas por outros módulos
  window.historySelector = {
    init: initHistorySelector,
    reload: loadFilesList,
    reloadVisualization: reloadVisualization
  };
})();
