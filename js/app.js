// A aplicação agora usa objetos e funções expostos globalmente
// Todos os módulos necessários são carregados via tags script no HTML

// Initialize state
// Certifique-se de que _allProjects e _activeFilters são inicializados antes deste script, ou aqui.
if (typeof window._allProjects === 'undefined') {
  window._allProjects = [];
}
if (typeof window._activeFilters === 'undefined') {
  window._activeFilters = window.FilterModel.createEmptyFilters(); // Use a factory se disponível
}

// Variável para rastrear o arquivo atualmente carregado
window._currentFilePath = null;

let allDependencies = window._allProjects; // Referenciar o global
// REMOVED: const activeFilters = window._activeFilters; 
let searchTerm = '';

// Initialize DOM elements
const filtersContainer = document.getElementById('filters-container');
const searchInput = document.getElementById('search-input');
const copyGradleButton = document.getElementById('copy-gradle-button');
const copyMavenButton = document.getElementById('copy-maven-button');
const clearFiltersButton = document.getElementById('clear-filters-button');
const dependenciesGrid = document.getElementById('dependencies-grid');

// Initialize filters
function initializeFilters() {
  // window._allProjects já deve estar carregado e ser o mesmo que allDependencies
  console.log("Inicializando filtros com", window._allProjects?.length || 0, "projetos");
  
  // Verificar se temos dados válidos
  if (!window._allProjects || window._allProjects.length === 0) {
    console.warn("Não há projetos disponíveis para inicializar filtros");
    return;
  }
  
  window.FilterView.updateAllDropdowns();
  window.FilterUtils.debugFilterRelationships(allDependencies);
  
  if (!allDependencies.some(p => p.dependencies && p.dependencies.length > 0)) {
    console.warn("No projects have dependencies. Check extraction.");
  }
}

// Event listeners setup
function setupEventListeners() {
  // Search input
  let searchTimeout;
  searchInput.addEventListener('input', (e) => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      searchTerm = e.target.value.trim();
      renderDependencies();
    }, 300); // Usar Config.UI.SEARCH_DEBOUNCE_DELAY se disponível e carregado
  });

  // Clear filters button
  clearFiltersButton.addEventListener('click', clearAllFilters);

  // Copy buttons
  copyGradleButton.addEventListener('click', () => {
    const filteredDependencies = getFilteredDependencies();
    window.ProjectList.getAllDependenciesGradle(filteredDependencies);
  });

  copyMavenButton.addEventListener('click', () => {
    const filteredDependencies = getFilteredDependencies();
    window.ProjectList.getAllDependenciesMaven(filteredDependencies);
  });

  // Filter dropdowns
  ['java', 'kotlin', 'gradle', 'spring'].forEach(type => {
    const dropdown = document.getElementById('filter-' + type);
    if (dropdown) {
      dropdown.addEventListener('change', (e) => {
        updateActiveFilter(type, e.target.value);
      });
    }
  });
}

// Clear all filters
function clearAllFilters() {
  console.log("Clearing all filters");
  
  window._activeFilters = window.FilterModel.createEmptyFilters();
  
  ['java', 'kotlin', 'gradle', 'spring'].forEach(type => {
    const dropdown = document.getElementById('filter-' + type);
    if (dropdown) {
      dropdown.value = '';
      dropdown.disabled = false;
    }
  });
  
  window.FilterView.updateAllDropdowns();
  
  searchInput.value = '';
  searchTerm = '';
  
  renderDependencies();
  updateFilteredProjects(getFilteredProjects());
}

// Get filtered dependencies
function getFilteredDependencies() {
  // Verificar se ProjectModel está disponível
  if (!window.ProjectModel || typeof window.ProjectModel.getFilteredDependencies !== 'function') {
    console.warn("ProjectModel não está disponível ou não contém o método getFilteredDependencies");
    return [];
  }
  
  try {
    return window.ProjectModel.getFilteredDependencies(allDependencies, window._activeFilters, searchTerm);
  } catch (error) {
    console.error("Erro ao obter dependências filtradas:", error);
    return [];
  }
}

// Get filtered projects
function getFilteredProjects() {
  // Verificar se o módulo projectModel foi inicializado
  if (!window.projectModel || typeof window.projectModel.getFilteredProjects !== 'function') {
    console.warn("projectModel não está disponível ou não contém o método getFilteredProjects");
    return [];
  }
  
  // Usar diretamente a função do projectModel sem chamadas recursivas
  // Não chamar window.getFilteredProjects aqui, pois isso causa recursão infinita
  try {
    return window.projectModel.getFilteredProjects(searchTerm);
  } catch (error) {
    console.error("Erro ao obter projetos filtrados:", error);
    return [];
  }
}

// Update filtered projects
function updateFilteredProjects(projects) {
  // Garantir que estamos trabalhando com um array válido
  const validProjects = Array.isArray(projects) ? projects : [];
  
  console.log(`Updated filtered projects: ${validProjects.length} projects`);
  
  // Verificar se o módulo projectList foi inicializado e contém o método necessário
  if (!window.projectList || typeof window.projectList.updateFilteredProjectsList !== 'function') {
    console.error("Erro: window.projectList não está disponível ou não contém o método updateFilteredProjectsList");
    return;
  }
  
  // Use the existing projectList.updateFilteredProjectsList function to properly
  // render project chips with click handling
  window.projectList.updateFilteredProjectsList(validProjects);
}

// Render dependencies
function renderDependencies() {
  const filteredDependencies = getFilteredDependencies();
  
  // Verificar se ProjectView está disponível
  if (!window.ProjectView || typeof window.ProjectView.renderDependencies !== 'function') {
    console.error("Erro: window.ProjectView não está disponível ou não contém o método renderDependencies");
    return;
  }
  
  window.ProjectView.renderDependencies(filteredDependencies, window._activeFilters);
}

// Update active filter
function updateActiveFilter(id, value) {
  const filterKey = id.replace('filter-', '');
  const actualKey = filterKey === 'spring' ? 'spring_boot' : filterKey;
  
  console.log(`Atualizando filtro: ${actualKey} = ${value}`);
  
  // Atualizar valor do filtro
  window._activeFilters[actualKey] = value || null;
  
  // Garantir que o valor do select também está atualizado
  const selectId = actualKey === 'spring_boot' ? 'filter-spring' : `filter-${actualKey}`;
  const select = document.getElementById(selectId);
  if (select) {
    select.value = value || '';
    console.log(`Select ${selectId} atualizado para ${value || ''}`);
  }
  
  // Atualizar UI
  window.FilterView.updateAllDropdowns();
  
  // Atualizar projeto e dependências filtradas
  const filteredProjects = getFilteredProjects();
  console.log(`Projetos filtrados após atualização: ${filteredProjects.length}`);
  
  renderDependencies();
  updateFilteredProjects(filteredProjects);
}

// Initialize application
async function init() {
  try {
    // Carregar dependências e atribuir a window._allProjects
    const filePath = window.Config.DEPENDENCIES_JSON_PATH;
    window._allProjects = await window.api.loadDependencies(filePath);
    allDependencies = window._allProjects; // Sincronizar a variável local
    
    // Armazenar o caminho do arquivo carregado
    window._currentFilePath = filePath;
    console.log(`Arquivo inicial carregado: ${filePath}`);
    
    allDependencies = allDependencies.map(project => {
      if (!project.requirements) {
        console.warn(`Project ${project.project || 'unknown'} has no requirements object. Creating empty object.`);
        project.requirements = { java: null, kotlin: null, gradle: null, spring_boot: null };
      }
      return project;
    });
    
    // Inicializar modelos que dependem de allDependencies
    window.initializeProjectModel(allDependencies); // project-model agora usa window._allProjects
    window.initializeFilterModel(allDependencies); // filter-model agora usa window._allProjects

    initializeFilters(); // Configura a UI dos filtros
    renderDependencies();
    setupEventListeners();
    
    const filteredProjects = getFilteredProjects();
    updateFilteredProjects(filteredProjects);
  } catch (error) {
    window.errorHandler.handleError(error, "Error loading dependencies", 
      "Please check if the data file exists and is accessible.");
  }
}

// Recarregar a visualização com novos dados (para uso pelo seletor de histórico)
async function reloadVisualization(newData) {
  try {
    // Verificar se temos dados válidos
    if (!Array.isArray(newData)) {
      console.error('Dados inválidos recebidos para recarregar visualização');
      return;
    }
    
    console.log('Recarregando visualização com novos dados:', newData.length, 'projetos');
    console.log('Timestamp da recarga:', Date.now());

    // Limpar a pesquisa primeiro
    searchInput.value = '';
    searchTerm = '';
    
    // ETAPA 1: Resetar estado antes de atualizar dados
    // Limpar completamente o estado anterior
    window._allProjects = [];
    allDependencies = [];
    window._activeFilters = window.FilterModel.createEmptyFilters();
    
    // ETAPA 2: Reinicializar modelos com os novos dados
    console.log("Reinicializando modelos com novos dados...");

    // Profundo clone dos dados para evitar inconsistências quando o mesmo arquivo é carregado múltiplas vezes
    // Garantir que cada objeto é uma nova referência e que todos os arrays aninhados também são clonados
    const clonedData = JSON.parse(JSON.stringify(newData));
    
    // Garantir que cada projeto tenha seus arrays de dependências inicializados corretamente
    const preparedData = clonedData.map(project => {
      if (!project) return null;
      
      // Garantir que temos um objeto válido
      const validProject = typeof project === 'object' ? project : {};
      
      // Garantir que as dependências são um array
      if (!Array.isArray(validProject.dependencies)) {
        validProject.dependencies = [];
      }
      
      return validProject;
    }).filter(Boolean); // Remover projetos null/undefined
    
    window.initializeProjectModel(preparedData);
    window.initializeFilterModel(window._allProjects);
    
    // Sincronizar variável local
    allDependencies = window._allProjects;
    
    // Diagnóstico após a inicialização
    if (typeof window.diagnoseFilters === 'function') {
      console.log("Diagnóstico após a inicialização dos modelos:");
      window.diagnoseFilters();
    }
    
    // ETAPA 3: Resetar UI dos filtros
    ['java', 'kotlin', 'gradle', 'spring'].forEach(type => {
      const dropdown = document.getElementById('filter-' + type);
      if (dropdown) {
        dropdown.value = '';
        dropdown.disabled = false;
      }
    });
    
    // ETAPA 4: Atualizar UI
    initializeFilters(); // Isso vai chamar FilterView.updateAllDropdowns()
    
    // Verificar dados antes de renderizar
    console.log('Projetos antes da renderização:', window._allProjects.length);
    const totalDepsBeforeRender = window._allProjects.reduce(
      (total, project) => total + (Array.isArray(project.dependencies) ? project.dependencies.length : 0), 0
    );
    console.log('Dependências antes da renderização:', totalDepsBeforeRender);
    
    renderDependencies();
    
    const filteredProjects = getFilteredProjects();
    updateFilteredProjects(filteredProjects);
    
    // Mostrar estatísticas dos dados carregados
    const totalDependencies = window._allProjects.reduce(
      (total, project) => total + (Array.isArray(project.dependencies) ? project.dependencies.length : 0),
      0
    );
    
    // Registrar todos os projetos e suas contagens de dependências para diagnóstico
    const detailedProjects = window._allProjects.map(p => ({
      name: p.project,
      depsCount: p.dependencies?.length || 0
    }));
    console.log('Detalhe dos projetos carregados:', JSON.stringify(detailedProjects, null, 2));
    
    console.log(`Visualização recarregada com sucesso: ${window._allProjects.length} projetos e ${totalDependencies} dependências`);
  } catch (error) {
    console.error('Erro ao recarregar visualização:', error);
    window.errorHandler.handleError(error, "Erro ao carregar nova versão", 
      "Ocorreu um problema ao atualizar a visualização com os novos dados.");
  }
}

// Start the application - commented out, will be called from index.html
// init();

// Expose critical functions globally
window.updateActiveFilter = updateActiveFilter;
window.clearAllFilters = clearAllFilters;
window.reloadVisualization = reloadVisualization;
window.initializeProjectsView = function(data) {
  reloadVisualization(data);
};

// Expose init function so it can be called from index.html
window.initApp = init;
