/**
 * DoneDep - Modelo de Projetos
 * Gerencia a lógica e os dados relacionados aos projetos
 */

// Usando objetos e funções expostos globalmente

// Armazenamento de todos os projetos carregados
// Definir no window para evitar redeclaração
if (typeof window._allProjects === 'undefined') {
  window._allProjects = [];
}

/**
 * Inicializa o modelo de projetos com dados carregados
 * @param {Array} projects - Array de objetos de projetos
 */
function initializeProjectModel(projects) {
  try {
    if (!Array.isArray(projects)) {
      throw new Error('Dados de projetos em formato inválido');
    }
    
    window._allProjects = projects.map(project => {
      try {
        // Assuming validateProject is exposed via window.api
        return window.api.validateProject(project);
      } catch (err) {
        window.logError({ 
          message: `Projeto inválido ignorado: ${err.message}`,
          type: window.ErrorType.VALIDATION, 
          level: window.ErrorLevel.WARNING, 
          originalError: err,
          context: { project }
        });
        return null;
      }
    }).filter(Boolean); 
    
    console.log(`Modelo de projetos inicializado com ${window._allProjects.length} projetos válidos`);
  } catch (error) {
    window.logError({ 
      message: `Falha ao inicializar modelo de projetos: ${error.message}`,
      type: window.ErrorType.DATA_LOAD, 
      level: window.ErrorLevel.ERROR, 
      originalError: error
    });
    window._allProjects = []; 
  }
}

/**
 * Obtém todos os projetos carregados
 * @returns {Array} - Array de projetos
 */
function getAllProjects() {
  return [...window._allProjects]; 
}

/**
 * Obtém um projeto pelo nome
 * @param {string} projectName - Nome do projeto a ser buscado
 * @returns {Object|null} - Projeto encontrado ou null
 */
function getProjectByName(projectName) {
  if (!projectName) return null;
  
  return window._allProjects.find(p => p && p.project === projectName) || null; 
}

/**
 * Filtra projetos com base nos filtros ativos e termo de busca
 * @param {string} [searchTerm] - Termo de busca opcional
 * @returns {Array} - Projetos filtrados
 */
function getFilteredProjects(searchTerm = '') {
  let projectsToFilter = [...window._allProjects]; 

  try {
    const activeFilters = window.getActiveFilters(); 
    
    if (activeFilters && Object.values(activeFilters).some(v => v !== null)) {
      projectsToFilter = projectsToFilter.filter(project => {
        if (!project || !project.requirements) return false;

        for (const [filterType, filterValue] of Object.entries(activeFilters)) {
          if (filterValue) { 
            const projectRequirement = project.requirements[filterType];
            if (filterType === 'kotlin' && filterValue === window.Config.FILTERS.NONE_LABEL) {
              if (projectRequirement !== null && typeof projectRequirement !== 'undefined') {
                return false; 
              }
            } else if (projectRequirement !== filterValue) {
              return false; 
            }
          }
        }
        return true; 
      });
    }

    if (searchTerm) {
      const lowerSearchTerm = searchTerm.toLowerCase();
      projectsToFilter = projectsToFilter.filter(project => 
        project.project && project.project.toLowerCase().includes(lowerSearchTerm)
      );
    }
    return projectsToFilter;
  } catch (error) {
    window.logError({ 
      message: `Erro ao filtrar projetos: ${error.message}`,
      type: window.ErrorType.FILTER, 
      level: window.ErrorLevel.ERROR, 
      originalError: error,
      context: { searchTerm, activeFilters: window.getActiveFilters ? window.getActiveFilters() : {} } 
    });
    return []; 
  }
}

/**
 * Obtém estatísticas sobre os projetos carregados
 * @returns {Object} - Objeto com estatísticas
 */
function getProjectsStats() {
  const stats = {
    total: window._allProjects.length, 
    withDependencies: 0,
    withoutDependencies: 0,
    javaVersions: new Set(),
    kotlinVersions: new Set(),
    gradleVersions: new Set(),
    springBootVersions: new Set(),
    totalDependencies: 0
  };
  
  window._allProjects.forEach(project => { 
    if (!project) return;
    
    if (project.dependencies && project.dependencies.length > 0) {
      stats.withDependencies++;
      stats.totalDependencies += project.dependencies.length;
    } else {
      stats.withoutDependencies++;
    }
    
    if (project.requirements) {
      if (project.requirements.java) stats.javaVersions.add(project.requirements.java);
      if (project.requirements.kotlin) stats.kotlinVersions.add(project.requirements.kotlin);
      if (project.requirements.gradle) stats.gradleVersions.add(project.requirements.gradle);
      if (project.requirements.spring_boot) stats.springBootVersions.add(project.requirements.spring_boot);
    }
  });
  
  stats.javaVersions = Array.from(stats.javaVersions);
  stats.kotlinVersions = Array.from(stats.kotlinVersions);
  stats.gradleVersions = Array.from(stats.gradleVersions);
  stats.springBootVersions = Array.from(stats.springBootVersions);
  
  return stats;
}

class ProjectModel {
  static getFilteredDependencies(projectsToProcess, activeFilters, searchTerm) {
    let allDeps = [];
    const anyFilterActive = activeFilters && Object.values(activeFilters).some(v => v);
    
    try {
      const projects = projectsToProcess || []; 
      
      projects.forEach(project => {
        if (!project) return;
        
        if (!project.requirements) {
          console.warn(`Project ${project.project || 'unnamed'} has no requirements. Creating empty object.`);
          project.requirements = { java: null, kotlin: null, gradle: null, spring_boot: null };
        }
        
        let passesFilters = true;
        if (anyFilterActive) {
            for (const [filterType, filterValue] of Object.entries(activeFilters)) {
              if (filterValue) {
                const projectRequirement = project.requirements[filterType];
                if (filterType === 'kotlin' && filterValue === window.Config.FILTERS.NONE_LABEL) { 
                  if (projectRequirement !== null && typeof projectRequirement !== 'undefined') {
                    passesFilters = false;
                    break;
                  }
                } else if (projectRequirement !== filterValue) {
                  passesFilters = false;
                  break;
                }
              }
            }
        }
        
        if (passesFilters) {
          if (Array.isArray(project.dependencies)) {
            const projectDeps = project.dependencies.map(dep => ({
              ...dep,
              projects: dep.projects ? [...dep.projects] : [], 
              projectName: project.project 
            }));
            allDeps = allDeps.concat(projectDeps);
          }
        }
      });
      
      let validDeps = allDeps.filter(dep => dep && typeof dep === 'object' && dep.group && dep.name);
      
      if (!anyFilterActive) { 
        const depMap = {};
        validDeps.forEach(dep => {
          const versionString = (typeof dep.version === 'object' && dep.version !== null) ? dep.version.value : dep.version;
          const uniqueKey = `${dep.group}:${dep.name}:${versionString}`;

          if (!depMap[uniqueKey]) {
            const uniqueId = Math.random().toString(36).substring(2) + Date.now().toString(36);
            depMap[uniqueKey] = {...dep, id: uniqueId, projects: []};
            if (dep.projectName && !depMap[uniqueKey].projects.includes(dep.projectName)) {
              depMap[uniqueKey].projects.push(dep.projectName);
            }
          } else if (dep.projectName && !depMap[uniqueKey].projects.includes(dep.projectName)) {
            depMap[uniqueKey].projects.push(dep.projectName);
          }
        });
        validDeps = Object.values(depMap);
      } else { 
        validDeps = validDeps.map(dep => {
          const uniqueId = Math.random().toString(36).substring(2) + Date.now().toString(36);
          const projectsList = dep.projects ? [...dep.projects] : [];
          if (dep.projectName && !projectsList.includes(dep.projectName)) {
            projectsList.push(dep.projectName);
          }
          return {...dep, id: uniqueId, projects: projectsList};
        });
      }
      
      if (searchTerm) {
        const lowerSearchTerm = searchTerm.toLowerCase();
        validDeps = validDeps.filter(dep => {
          try {
            const nameMatch = dep.name && dep.name.toLowerCase().includes(lowerSearchTerm);
            const groupMatch = dep.group && dep.group.toLowerCase().includes(lowerSearchTerm);
            
            const versionString = (typeof dep.version === 'object' && dep.version !== null) ? dep.version.value : dep.version;
            const versionMatch = versionString && versionString.toLowerCase().includes(lowerSearchTerm);
            
            let projectsMatch = false;
            if (dep.projects && Array.isArray(dep.projects)) {
              projectsMatch = dep.projects.some(pName => 
                pName && pName.toLowerCase().includes(lowerSearchTerm)
              );
            }
            return nameMatch || groupMatch || versionMatch || projectsMatch;
          } catch (e) {
            console.error("Error filtering dependency by search term:", e, dep);
            return false;
          }
        });
      }
      return validDeps;
    } catch (error) {
      window.logError({
          message: `Error processing dependencies in ProjectModel: ${error.message}`,
          type: window.ErrorType.RUNTIME, 
          level: window.ErrorLevel.ERROR,
          originalError: error
      });
      return []; 
    }
  }
}

window.ProjectModel = ProjectModel;
window.initializeProjectModel = initializeProjectModel;
window.getAllProjects = getAllProjects;
window.getProjectByName = getProjectByName;
window.getFilteredProjects = getFilteredProjects;
window.getProjectsStats = getProjectsStats;

window.projectModel = {
  initializeProjectModel,
  getAllProjects,
  getProjectByName,
  getFilteredProjects,
  getProjectsStats
};
