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
  window.FilterView.updateAllDropdowns(allDependencies, window._activeFilters);
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
  
  window.FilterView.updateAllDropdowns(allDependencies, window._activeFilters);
  
  searchInput.value = '';
  searchTerm = '';
  
  renderDependencies();
  updateFilteredProjects(getFilteredProjects());
}

// Get filtered dependencies
function getFilteredDependencies() {
  return window.ProjectModel.getFilteredDependencies(allDependencies, window._activeFilters, searchTerm);
}

// Get filtered projects
function getFilteredProjects() {
  // Usar diretamente a função do projectModel sem chamadas recursivas
  // Não chamar window.getFilteredProjects aqui, pois isso causa recursão infinita
  return window.projectModel.getFilteredProjects(searchTerm);
}

// Update filtered projects
function updateFilteredProjects(projects) {
  console.log(`Updated filtered projects: ${projects.length} projects`);
  
  // Use the existing projectList.updateFilteredProjectsList function to properly
  // render project chips with click handling
  window.projectList.updateFilteredProjectsList(projects);
}

// Render dependencies
function renderDependencies() {
  const filteredDependencies = getFilteredDependencies();
  window.ProjectView.renderDependencies(filteredDependencies, window._activeFilters);
}

// Update active filter
function updateActiveFilter(id, value) {
  const filterKey = id.replace('filter-', '');
  const actualKey = filterKey === 'spring' ? 'spring_boot' : filterKey;
  
  window._activeFilters[actualKey] = value || null;
  window.FilterView.updateAllDropdowns(allDependencies, window._activeFilters);
  renderDependencies();
  updateFilteredProjects(getFilteredProjects());
}

// Initialize application
async function init() {
  try {
    // Carregar dependências e atribuir a window._allProjects
    window._allProjects = await window.api.loadDependencies(window.Config.DEPENDENCIES_JSON_PATH);
    allDependencies = window._allProjects; // Sincronizar a variável local
    
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

// Start the application
init();

// Expose critical functions globally
window.updateActiveFilter = updateActiveFilter;
window.clearAllFilters = clearAllFilters;
