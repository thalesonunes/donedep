/**
 * DoneDep - Seletor de Histórico de Dependências
 * 
 * Este módulo adiciona um seletor que permite escolher entre diferentes arquivos de dependências
 * com timestamp, permitindo ao usuário visualizar dados históricos.
 */

(function() {
  // Variáveis para elementos do DOM
  let fileSelector;
  let filesData = [];
  let initialized = false;
  
  // Função para inicializar o componente
  async function initHistorySelector() {
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
    
    // Carregar a lista de arquivos disponíveis e aguardar finalização
    await loadFilesList();
    initialized = true;
    console.log("Seletor de histórico inicializado com sucesso.");
  }
  
  // Criar o elemento de seleção no DOM
  function createSelectorElement() {
    console.log("🔧 Criando elemento seletor...");
    
    // Obter o container que já existe no HTML
    const selectorContainer = document.getElementById('history-selector-container');
    if (!selectorContainer) {
      console.error("❌ Container para seletor de histórico não encontrado no HTML");
      return;
    }
    
    console.log("✅ Container encontrado:", selectorContainer);
    
    // Limpar conteúdo existente
    selectorContainer.innerHTML = '';
    
    // Criar select
    fileSelector = document.createElement('select');
    fileSelector.id = 'history-file-selector';
    fileSelector.className = 'history-file-selector';
    
    // Adicionar uma opção inicial para verificar se está funcionando
    const initialOption = document.createElement('option');
    initialOption.value = '';
    initialOption.textContent = 'Carregando opções...';
    initialOption.disabled = true;
    initialOption.selected = true;
    fileSelector.appendChild(initialOption);
    
    // Adicionar listener para mudança que mostra quantas opções existem
    fileSelector.addEventListener('focus', () => {
      console.log(`🔍 Selector focused - current options: ${fileSelector.options.length}`);
      Array.from(fileSelector.options).forEach((option, i) => {
        console.log(`  ${i}: ${option.textContent} (${option.value})`);
      });
    });
    
    selectorContainer.appendChild(fileSelector);
    console.log("✅ Elementos do seletor adicionados ao container");
    console.log("🔍 fileSelector criado:", fileSelector);
    
    // Adicionar evento de mudança
    fileSelector.addEventListener('change', handleFileChange);
  }
  

   // Carregar a lista de arquivos disponíveis
  async function loadFilesList(currentFile = null) {
    console.log("🔄 [loadFilesList] INÍCIO - Carregando lista de arquivos de dependências...");
    
    try {
      console.log("📍 [loadFilesList] Verificando dependências...");
      console.log("📍 fileSelector existe?", !!fileSelector);
      console.log("📍 window.api existe?", !!window.api);
      console.log("📍 window.api.listDependencyFiles existe?", !!window.api?.listDependencyFiles);
      
      if (!window.api) {
        throw new Error("window.api não está disponível");
      }
      
      if (!window.api.listDependencyFiles) {
        throw new Error("window.api.listDependencyFiles não está disponível");
      }
      
      console.log("🔍 [loadFilesList] Chamando window.api.listDependencyFiles()...");
      filesData = await window.api.listDependencyFiles();
      console.log("📂 [loadFilesList] Resposta da API recebida:", filesData);
      console.log("📊 [loadFilesList] Tipo de resposta:", typeof filesData);
      console.log("📊 [loadFilesList] É array?", Array.isArray(filesData));
      console.log("📊 [loadFilesList] Número de arquivos:", filesData?.length || 0);
      
      if (!fileSelector) {
        throw new Error("Seletor de arquivo não inicializado corretamente!");
      }
      
      console.log("🔍 [loadFilesList] fileSelector encontrado:", fileSelector.id);
      console.log("🔍 [loadFilesList] Opções atuais no selector:", fileSelector.options.length);
      
      // Limpar opções existentes (incluindo a opção inicial "Carregando...")
      console.log("🧹 [loadFilesList] Limpando opções existentes...");
      fileSelector.innerHTML = '';
      console.log("🧹 [loadFilesList] Opções limpas. Opções restantes:", fileSelector.options.length);
      
      if (!Array.isArray(filesData)) {
        throw new Error(`filesData não é um array! Tipo: ${typeof filesData}, Valor: ${JSON.stringify(filesData)}`);
      }
      
      if (filesData.length === 0) {
        console.warn("⚠️ [loadFilesList] Nenhum arquivo encontrado pela API");
        // Adicionar opção padrão
        const defaultOption = document.createElement('option');
        defaultOption.value = window.Config.DEPENDENCIES_JSON_PATH;
        defaultOption.textContent = 'Arquivo padrão (nenhum histórico encontrado)';
        defaultOption.selected = true;
        fileSelector.appendChild(defaultOption);
        console.log("📝 [loadFilesList] Opção padrão adicionada");
        return;
      }
      
      // Adicionar opções para cada arquivo
      console.log("➕ [loadFilesList] Adicionando opções ao selector...");
      filesData.forEach((file, index) => {
        console.log(`  📄 Processando arquivo ${index + 1}:`, file);
        console.log(`  📄 file.path: '${file.path}', file.name: '${file.name}', file.originalName: '${file.originalName}', file.date: '${file.date}'`);
        
        const option = document.createElement('option');
        option.value = file.path;
        // Usar o nome amigável se disponível, senão usar o nome original
        option.textContent = file.name || file.originalName || file.date || 'Arquivo sem nome';
        
        console.log(`  🏷️ Opção criada - value: '${option.value}', text: '${option.textContent}'`);
        
        // Marcar o arquivo mais recente como selecionado
        const timestamp = file.name?.match(/dependencies_(\d{8})_(\d{6})\.json/);
        if (timestamp) {
          option.dataset.timestamp = timestamp[1] + timestamp[2];
          console.log(`  🕒 Timestamp extraído: ${option.dataset.timestamp}`);
        }
        
        console.log(`  🔧 Adicionando opção ao fileSelector...`);
        console.log(`  🔧 fileSelector antes da adição:`, fileSelector);
        console.log(`  🔧 fileSelector.options.length antes: ${fileSelector.options.length}`);
        
        fileSelector.appendChild(option);
        
        console.log(`  🔧 fileSelector.options.length depois: ${fileSelector.options.length}`);
        console.log(`  ✅ Opção adicionada: ${option.textContent} (${option.value})`);
      });
      
      console.log(`🎯 Total de opções adicionadas: ${fileSelector.options.length}`);
      console.log("📋 Opções finais no selector:", Array.from(fileSelector.options).map(o => `${o.textContent} (${o.value})`));
      
      // Update the selector text to show it's loaded
      if (fileSelector.options.length > 0) {
        // Remove the "Carregando..." option if it still exists
        const loadingOption = Array.from(fileSelector.options).find(opt => opt.textContent.includes('Carregando'));
        if (loadingOption) {
          loadingOption.remove();
          console.log("🧹 Removida opção 'Carregando...'");
        }
        
        console.log(`✅ [loadFilesList] Dropdown populado com ${fileSelector.options.length} opções`);
      }
      console.log("🎯 [loadFilesList] SUCESSO - Lista de arquivos carregada!");
      
      // Se foi passado um arquivo atual, sincronizar com ele
      if (currentFile) {
        console.log(`🔗 [loadFilesList] Sincronizando com arquivo: ${currentFile}`);
        syncWithCurrentFile(currentFile);
      } else {
        // Selecionar o arquivo mais recente apenas se não há arquivo específico
        if (fileSelector.options.length > 0) {
          const options = Array.from(fileSelector.options);
          const latestOption = options.reduce((latest, current) => {
            if (!latest.dataset.timestamp) return current;
            if (!current.dataset.timestamp) return latest;
            return current.dataset.timestamp > latest.dataset.timestamp ? current : latest;
          });
          latestOption.selected = true;
          console.log(`📅 [loadFilesList] Arquivo mais recente selecionado: ${latestOption.textContent}`);
        }
      }
      
    } catch (error) {
      console.error('💥 [loadFilesList] ERRO ao carregar lista de arquivos:', error);
      console.error('💥 [loadFilesList] Stack trace:', error.stack);
      console.error('💥 [loadFilesList] Error details:', {
        message: error.message,
        name: error.name,
        apiAvailable: !!window.api,
        listFunctionAvailable: !!window.api?.listDependencyFiles,
        selectorExists: !!fileSelector
      });
      
      // Verificar se o selector ainda existe antes de tentar adicionar opção padrão
      if (fileSelector) {
        console.log('🔧 [loadFilesList] Adicionando opção padrão devido ao erro...');
        // Limpar primeiro para evitar duplicatas
        fileSelector.innerHTML = '';
        
        const defaultOption = document.createElement('option');
        defaultOption.value = window.Config.DEPENDENCIES_JSON_PATH;
        defaultOption.textContent = 'Arquivo padrão (erro ao carregar histórico)';
        defaultOption.selected = true;
        fileSelector.appendChild(defaultOption);
        console.log('🔧 [loadFilesList] Opção padrão adicionada após erro');
      } else {
        console.error('💥 [loadFilesList] fileSelector não existe, não é possível adicionar opção padrão');
      }
    }
    
    console.log("🏁 [loadFilesList] FIM DA FUNÇÃO");
  }
  
  // Manipular mudança de arquivo selecionado
  function handleFileChange(event) {
    const selectedPath = event.target.value;
    
    console.log(`Arquivo selecionado alterado para: ${selectedPath} em ${Date.now()}`);
    
    // Atualizar o arquivo atual globalmente
    window._currentFilePath = selectedPath;
    
    // Mostrar mensagem de carregamento
    showLoadingMessage();
    
    // Carregar os dados do arquivo selecionado
    // Adicionar parâmetro aleatório para evitar qualquer tipo de cache
    const cacheBuster = `?v=${Date.now()}&nocache=${Math.random()}`;
    const urlWithCache = selectedPath.includes('?') 
      ? `${selectedPath}&nocache=${Math.random()}` 
      : `${selectedPath}${cacheBuster}`;
      
    console.log(`Carregando dependências de ${urlWithCache}`);
    
    window.api.loadDependencies(urlWithCache)
      .then(data => {
        console.log('Arquivo carregado com sucesso, atualizando visualização...');
        console.log(`Dados carregados: ${data.length} projetos`);
        
        // Fazer uma checagem prévia completa dos dados
        const validProjects = data.filter(p => p && typeof p === 'object');
        
        // Contar dependências totais e por projeto
        const projectDepsCount = {};
        let totalDeps = 0;
        
        validProjects.forEach(p => {
          const projectName = p.project || 'unknown';
          const depsCount = Array.isArray(p.dependencies) ? p.dependencies.filter(d => d && typeof d === 'object').length : 0;
          projectDepsCount[projectName] = depsCount;
          totalDeps += depsCount;
        });
        
        console.log(`Validação pré-visualização: ${validProjects.length} projetos válidos, ${totalDeps} dependências`);
        console.log('Contagem de dependências por projeto:', projectDepsCount);
        
        // Clonagem profunda dos dados para garantir que não há referências compartilhadas
        const clonedData = JSON.parse(JSON.stringify(data));
        
        // Recarregar a visualização com os novos dados
        if (typeof window.reloadVisualization === 'function') {
          window.reloadVisualization(clonedData);
          console.log('Visualização atualizada com sucesso');
        } else {
          console.warn('Função reloadVisualization não encontrada, recarregando página...');
          // Se a função específica não existir, tentar recarregar a página
          location.reload();
        }
        
        // Esconder mensagem de carregamento
        hideLoadingMessage();
      })
      .catch(error => {
        console.error('Erro ao carregar arquivo de dependências:', error);
        showErrorMessage('Erro ao carregar o arquivo selecionado.');
        hideLoadingMessage();
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
  
  // Função para sincronizar a seleção com o arquivo atualmente carregado
  function syncWithCurrentFile(currentFilePath) {
    if (!fileSelector || !currentFilePath) {
      console.log("Não é possível sincronizar: selector ou caminho do arquivo não disponível");
      return;
    }
    
    console.log(`Sincronizando seletor com arquivo atual: ${currentFilePath}`);
    
    // Encontrar a opção correspondente no selector
    const options = Array.from(fileSelector.options);
    let foundOption = null;
    
    // Primeiro, tentar encontrar uma correspondência exata
    foundOption = options.find(option => option.value === currentFilePath);
    
    // Se não encontrou exata, verificar se é um symlink ou alias
    if (!foundOption) {
      // Se o arquivo atual é dependencies.json, procurar por dependencies_small.json
      if (currentFilePath.includes('dependencies.json') && !currentFilePath.includes('_')) {
        foundOption = options.find(option => option.value.includes('dependencies_small.json'));
        console.log("Arquivo padrão detectado, buscando por dependencies_small.json");
      }
    }
    
    // Se ainda não encontrou, tentar buscar por nome base
    if (!foundOption) {
      const baseName = currentFilePath.split('/').pop();
      foundOption = options.find(option => option.value.includes(baseName));
    }
    
    if (foundOption) {
      foundOption.selected = true;
      console.log(`✅ Seleção sincronizada com: ${foundOption.textContent} (${foundOption.value})`);
    } else {
      console.warn(`❌ Não foi possível encontrar opção correspondente para: ${currentFilePath}`);
      console.log("📋 Opções disponíveis:", options.map(o => `${o.textContent} (${o.value})`));
    }
  }

  // Exportar funções para serem usadas por outros módulos
  window.historySelector = {
    init: initHistorySelector,
    reload: loadFilesList,
    reloadVisualization: reloadVisualization,
    syncWithCurrentFile: syncWithCurrentFile
  };
})();
