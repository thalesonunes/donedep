/**
 * DoneDep - Modelo de Filtros
 * Gerencia o estado e a lógica dos filtros da aplicação
 */

// Usando objetos globais

// Estado dos filtros ativos - inicializar no objeto window
if (typeof window._activeFilters === 'undefined') {
  window._activeFilters = {
    java: null,
    kotlin: null,
    gradle: null,
    spring_boot: null
  };
}

/**
 * Inicializa o modelo de filtros com dados de projetos
 * @param {Array} projects - Array de objetos de projetos
 */
function initializeFilterModel(projects) {
  if (!Array.isArray(projects)) {
    window.logError({
      message: 'Tentativa de inicializar filtros com dados inválidos',
      type: window.ErrorType.VALIDATION,
      level: window.ErrorLevel.ERROR,
      context: { 
        receivedType: typeof projects,
        isArray: Array.isArray(projects)
      }
    });
    // Não modificar window._allProjects aqui, apenas retornar ou não prosseguir.
    return;
  }
  
  // Não é necessário reatribuir window._allProjects aqui, ele já deve estar populado.
  // Apenas resetar os filtros.
  resetFilters();
}

/**
 * Atualiza um filtro ativo
 * @param {string} filterKey - Chave do filtro (java, kotlin, gradle, spring_boot)
 * @param {string} value - Valor do filtro (versão) ou null para limpar
 * @returns {boolean} - Retorna true se o filtro foi aplicado com sucesso
 */
function updateFilter(filterKey, value) {
  const actualKey = filterKey === 'spring' ? 'spring_boot' : filterKey;
  
  if (!['java', 'kotlin', 'gradle', 'spring_boot'].includes(actualKey)) {
    window.logError({
      message: `Chave de filtro inválida: ${filterKey}`,
      type: window.ErrorType.VALIDATION,
      level: window.ErrorLevel.WARNING,
      context: { filterKey, value }
    });
    return false;
  }
  
  window._activeFilters[actualKey] = value || null;
  return true;
}

/**
 * Verificar se a combinação atual de filtros é válida
 * @returns {boolean} - true se válida, false caso contrário
 */
function validateFilterCombination() {
  if (!Object.values(window._activeFilters).some(v => v !== null)) {
    return true;
  }
  
  const matchingProjects = (window._allProjects || []).filter(project => {
    if (!project || !project.requirements) return false;
    
    for (const [key, value] of Object.entries(window._activeFilters)) {
      if (value === null) continue;
      
      if (key === 'kotlin' && value === window.Config.FILTERS.NONE_LABEL) {
        if (project.requirements[key] !== null && project.requirements[key] !== undefined) {
          return false;
        }
      } 
      else if (value !== null && project.requirements[key] !== value) {
        return false;
      }
    }
    return true;
  });
  
  if (matchingProjects.length === 0) {
    window.logError({
      message: 'Combinação de filtros incompatível selecionada',
      type: window.ErrorType.FILTER,
      level: window.ErrorLevel.WARNING,
      context: { activeFilters: window._activeFilters }
    });
    
    window.showIncompatibleModal();
    return false;
  }
  
  return true;
}

/**
 * Obtém opções compatíveis para um determinado filtro
 * @param {string} filterToUpdate - Filtro a ser atualizado (java, kotlin, etc)
 * @param {Object} currentSelections - Seleções atuais dos filtros
 * @returns {Array} - Array de opções compatíveis
 */
function getCompatibleOptions(filterToUpdate, currentSelections = window._activeFilters) {
  try {
    // Verificar se temos dados para trabalhar
    if (!window._allProjects || !Array.isArray(window._allProjects) || window._allProjects.length === 0) {
      console.warn(`Não há projetos disponíveis para obter opções de ${filterToUpdate}`);
      return [];
    }
    
    // Garantir que estamos trabalhando com os dados mais atualizados
    let filteredProjects = [...window._allProjects];
    console.log(`Obtendo opções para ${filterToUpdate} com ${filteredProjects.length} projetos disponíveis`);
    
    // Se não temos seleções atuais válidas, usar objeto vazio
    const selections = currentSelections || {};
    
    Object.entries(selections).forEach(([key, value]) => {
      if (value && key !== filterToUpdate) {
        console.log(`Aplicando filtro ${key}=${value} para obter opções de ${filterToUpdate}`);
        
        if (key === 'kotlin' && value === window.Config.FILTERS.NONE_LABEL) {
          filteredProjects = filteredProjects.filter(p => 
            p && p.requirements && (p.requirements[key] === null || p.requirements[key] === undefined)
          );
        } else {
          filteredProjects = filteredProjects.filter(p => 
            p && p.requirements && p.requirements[key] === value
          );
        }
      }
    });
    
    const keyToUse = filterToUpdate === 'spring' ? 'spring_boot' : filterToUpdate;
    const compatibleOptions = window.FilterUtils.getUnique(filteredProjects, keyToUse);
    
    console.log(`Opções compatíveis para ${filterToUpdate}:`, compatibleOptions);
    
    return compatibleOptions;
  } catch (error) {
    window.logError({
      message: `Erro ao obter opções de filtro: ${error.message}`,
      type: window.ErrorType.FILTER,
      level: window.ErrorLevel.ERROR,
      originalError: error,
      context: { filterToUpdate, currentSelections }
    });
    return [];
  }
}

/**
 * Limpa todos os filtros ativos
 */
function resetFilters() {
  window._activeFilters = {
    java: null,
    kotlin: null,
    gradle: null,
    spring_boot: null
  };
}

/**
 * Obtém os filtros ativos atualmente
 * @returns {Object} - Objeto com os filtros ativos
 */
function getActiveFilters() {
  return { ...window._activeFilters };
}

/**
 * Obtém os filtros ativos formatados como array para exibição
 * @returns {Array} - Array de strings do formato "chave: valor"
 */
function getActiveFilterLabels() {
  const labels = [];
  const currentFilters = window._activeFilters;
  if (currentFilters.java) labels.push(`Java: ${currentFilters.java}`);
  if (currentFilters.kotlin) labels.push(`Kotlin: ${currentFilters.kotlin}`);
  if (currentFilters.gradle) labels.push(`Gradle: ${currentFilters.gradle}`);
  if (currentFilters.spring_boot) labels.push(`Spring Boot: ${currentFilters.spring_boot}`);
  
  return labels;
}

/**
 * Verifica se algum filtro está ativo
 * @returns {boolean} - true se algum filtro estiver ativo
 */
function hasActiveFilters() {
  return Object.values(window._activeFilters).some(v => v !== null);
}

/**
 * Debug: Mostrar relações entre filtros no console
 */
function debugFilterRelationships() {
  const projects = window._allProjects || [];
  if (projects.length === 0) {
    console.warn("Nenhum projeto carregado para analisar relações entre filtros");
    return;
  }
  
  console.log("%c=== Análise de Relações entre Filtros ===", "font-weight:bold; color:blue;");
  
  console.log("%cDados dos projetos carregados:", "font-weight:bold");
  projects.forEach(p => {
    try {
      if (p && p.requirements) {
        console.log(`Projeto: ${p.project || 'Sem nome'}, Java: ${p.requirements.java || 'N/A'}, Gradle: ${p.requirements.gradle || 'N/A'}, Kotlin: ${p.requirements.kotlin || 'N/A'}, Spring: ${p.requirements.spring_boot || 'N/A'}`);
      } else if (p) {
        console.log(`Projeto: ${p.project || 'Sem nome'}, sem requisitos definidos`);
      } else {
        console.log('Projeto inválido encontrado');
      }
    } catch (e) {
      console.error('Erro ao mostrar informações do projeto:', e);
    }
  });
  
  console.log("%cVersões de Gradle por versão de Java:", "font-weight:bold");
  const javaVersions = window.FilterUtils.getUnique(projects, 'java');
  
  javaVersions.forEach(javaVersion => {
    const filtered = projects.filter(
      p => p.requirements && p.requirements.java === javaVersion
    );
    const gradleVersions = window.FilterUtils.getUnique(filtered, 'gradle');
    console.log(`Java ${javaVersion}: Gradle ${gradleVersions.join(', ')}`);
  });
  
  console.log("%cVersões de Spring Boot por versão de Java:", "font-weight:bold");
  javaVersions.forEach(javaVersion => {
    const filtered = projects.filter(
      p => p.requirements && p.requirements.java === javaVersion
    );
    const springVersions = window.FilterUtils.getUnique(filtered, 'spring_boot');
    console.log(`Java ${javaVersion}: Spring Boot ${springVersions.join(', ')}`);
  });
  
  console.log("%cVersões de Kotlin por versão de Java:", "font-weight:bold");
  javaVersions.forEach(javaVersion => {
    const filtered = projects.filter(
      p => p.requirements && p.requirements.java === javaVersion
    );
    const kotlinVersions = window.FilterUtils.getUnique(filtered, 'kotlin');
    console.log(`Java ${javaVersion}: Kotlin ${kotlinVersions.join(', ')}`);
  });
}

/**
 * Diagnóstica o estado atual dos filtros e dados
 * Função de debug para ajudar a identificar problemas
 */
function diagnoseFilters() {
  console.group('Diagnóstico de Filtros');
  console.log('Projetos carregados:', window._allProjects?.length || 0);
  
  // Ver alguns exemplos de projetos
  if (window._allProjects && window._allProjects.length > 0) {
    console.log('Exemplo de projeto:', window._allProjects[0]);
    
    // Verificar requisitos disponíveis
    const javaVersions = new Set();
    const kotlinVersions = new Set();
    const gradleVersions = new Set();
    const springVersions = new Set();
    
    window._allProjects.forEach(project => {
      if (project?.requirements) {
        if (project.requirements.java) javaVersions.add(project.requirements.java);
        if (project.requirements.kotlin) kotlinVersions.add(project.requirements.kotlin);
        if (project.requirements.gradle) gradleVersions.add(project.requirements.gradle);
        if (project.requirements.spring_boot) springVersions.add(project.requirements.spring_boot);
      }
    });
    
    console.log('Versões de Java disponíveis:', Array.from(javaVersions));
    console.log('Versões de Kotlin disponíveis:', Array.from(kotlinVersions));
    console.log('Versões de Gradle disponíveis:', Array.from(gradleVersions));
    console.log('Versões de Spring Boot disponíveis:', Array.from(springVersions));
  }
  
  // Verificar filtros ativos
  console.log('Filtros ativos:', window._activeFilters);
  
  console.groupEnd();
}

window.filterModel = {
  initializeFilterModel,
  updateFilter,
  validateFilterCombination,
  getCompatibleOptions,
  resetFilters,
  getActiveFilters,
  getActiveFilterLabels,
  hasActiveFilters,
  debugFilterRelationships
};

/**
 * Classe FilterModel - Modelo de Filtros
 * Métodos estáticos para manipulação de filtros
 */
class FilterModel {
  static createEmptyFilters() {
    return {
      java: null,
      kotlin: null,
      gradle: null,
      spring_boot: null
    };
  }

  static getCompatibleOptions(filterToUpdate, currentSelections, allProjectsData) {
    let filteredProjects = [...(allProjectsData || [])];
    
    Object.entries(currentSelections).forEach(([key, value]) => {
      if (value && key !== filterToUpdate) {
        if (key === 'kotlin' && value === 'Nenhum') {
          filteredProjects = filteredProjects.filter(p => 
            p && p.requirements && (p.requirements[key] === null || p.requirements[key] === undefined)
          );
        } else {
          filteredProjects = filteredProjects.filter(p => 
            p && p.requirements && p.requirements[key] === value
          );
        }
      }
    });
    
    const keyToUse = filterToUpdate === 'spring' ? 'spring_boot' : filterToUpdate;
    return window.FilterUtils.getUnique(filteredProjects, keyToUse);
  }

  static applyFilters(allProjectsData, activeFiltersData) {
    return (allProjectsData || []).filter(project => {
      if (!project) return false;
      
      for (const [filterType, filterValue] of Object.entries(activeFiltersData)) {
        if (filterValue) {
          if (filterType === 'kotlin' && filterValue === 'Nenhum') {
            if (project.requirements && project.requirements[filterType] !== null && project.requirements[filterType] !== undefined) {
              return false;
            }
          } else if (!project.requirements || project.requirements[filterType] !== filterValue) {
            return false;
          }
        }
      }
      return true;
    });
  }

  static applySearch(projects, searchTerm) {
    if (!searchTerm) return projects;
    
    return projects.filter(project => 
      project.project && project.project.toLowerCase().includes(searchTerm.toLowerCase())
    );
  }
}

window.FilterModel = FilterModel;
window.initializeFilterModel = initializeFilterModel;
window.updateFilter = updateFilter;
window.validateFilterCombination = validateFilterCombination;
window.getCompatibleOptions = getCompatibleOptions;
window.resetFilters = resetFilters;
window.getActiveFilters = getActiveFilters;
window.getActiveFilterLabels = getActiveFilterLabels;
window.hasActiveFilters = hasActiveFilters;
window.debugFilterRelationships = debugFilterRelationships;
window.diagnoseFilters = diagnoseFilters;
