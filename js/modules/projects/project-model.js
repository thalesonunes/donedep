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
    // Limpar dados anteriores completamente
    window._allProjects = [];
    
    if (!Array.isArray(projects)) {
      throw new Error('Dados de projetos em formato inválido');
    }
    
    // Registrar momento da inicialização para diagnóstico
    console.log(`Iniciando inicialização do modelo em ${Date.now()}`);
    
    // Contar projetos originais para diagnóstico
    const originalCount = projects.length;
    console.log(`Processando ${originalCount} projetos originais`);
    
    // Filtrar projetos vazios antes mesmo de validar
    const nonEmptyProjects = projects.filter(project => 
      project && typeof project === 'object' && Object.keys(project).length > 0
    );
    
    if (originalCount !== nonEmptyProjects.length) {
      console.warn(`Removidos ${originalCount - nonEmptyProjects.length} projetos vazios`);
    }
    
    // Criar uma nova array de projetos para evitar problemas de referência
    const validatedProjects = [];
    
    // Validar cada projeto individualmente
    for (const project of nonEmptyProjects) {
      try {
        if (!project) continue;
        
        // Validar o projeto usando API
        const validProject = window.api.validateProject(project);
        
        // Verificar explicitamente as dependências
        if (!validProject.dependencies) validProject.dependencies = [];
        if (!Array.isArray(validProject.dependencies)) validProject.dependencies = [];
        
        // Garantir que cada dependência seja um objeto válido
        validProject.dependencies = validProject.dependencies.filter(dep => 
          dep && typeof dep === 'object' && Object.keys(dep).length > 0
        );
        
        validatedProjects.push(validProject);
      } catch (err) {
        window.logError({ 
          message: `Projeto inválido ignorado: ${err.message}`,
          type: window.ErrorType.VALIDATION, 
          level: window.ErrorLevel.WARNING, 
          originalError: err,
          context: { project: project ? project.project : 'unknown' }
        });
      }
    }
    
    // Atribuir ao global
    window._allProjects = validatedProjects;
    
    // Contar dependências totais para diagnóstico
    const totalDependencies = window._allProjects.reduce(
      (total, project) => total + (project.dependencies ? project.dependencies.length : 0),
      0
    );
    
    console.log(`Modelo de projetos inicializado com ${window._allProjects.length} projetos válidos contendo ${totalDependencies} dependências`);
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
            if ((filterType === 'kotlin' || filterType === 'java' || filterType === 'spring_boot') && filterValue === window.Config.FILTERS.NONE_LABEL) {
              if (projectRequirement !== 'NENHUM' && 
                  projectRequirement !== null && 
                  typeof projectRequirement !== 'undefined') {
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
      // Validar e filtrar projetos não-nulos de antemão
      const projects = Array.isArray(projectsToProcess) 
        ? projectsToProcess.filter(p => p && typeof p === 'object')
        : [];
      
      console.log(`getFilteredDependencies: processando ${projects.length} projetos`);
      console.log(`Filtros ativos:`, JSON.stringify(activeFilters));
      
      projects.forEach(project => {
        if (!project) return;
        
        // Garantir que requirements existe
        if (!project.requirements) {
          console.warn(`Project ${project.project || 'unnamed'} has no requirements. Creating empty object.`);
          project.requirements = { 
            java: project.javaVersion || null, 
            kotlin: project.kotlinVersion || null, 
            gradle: project.gradleVersion || null, 
            spring_boot: project.springBootVersion || null 
          };
        }
        
        // Determinar se o projeto passa pelos filtros
        let passesFilters = true;
        
        if (anyFilterActive) {
            for (const [filterType, filterValue] of Object.entries(activeFilters)) {
              if (!filterValue) continue; // Pular filtros sem valor
              
              const projectRequirement = project.requirements[filterType];
              
              // Log para depuração do filtro
              console.log(`Verificando filtro ${filterType}=${filterValue} para projeto ${project.project}: valor=${projectRequirement}`);
              
              // Caso especial para java "NENHUM"
              if (filterType === 'java' && filterValue === window.Config.FILTERS.NONE_LABEL) { 
                if (projectRequirement !== 'NENHUM' && 
                    projectRequirement !== null && 
                    typeof projectRequirement !== 'undefined') {
                  console.log(`Projeto ${project.project} não passa no filtro NONE para java`);
                  passesFilters = false;
                  break;
                }
              } 
              // Caso especial para kotlin "NENHUM"
              else if (filterType === 'kotlin' && filterValue === window.Config.FILTERS.NONE_LABEL) { 
                if (projectRequirement !== 'NENHUM' && 
                    projectRequirement !== null && 
                    typeof projectRequirement !== 'undefined') {
                  console.log(`Projeto ${project.project} não passa no filtro NONE para kotlin`);
                  passesFilters = false;
                  break;
                }
              } 
              // Caso especial para gradle "NENHUM"
              else if (filterType === 'gradle' && filterValue === window.Config.FILTERS.NONE_LABEL) { 
                if (projectRequirement !== 'NENHUM' && 
                    projectRequirement !== null && 
                    typeof projectRequirement !== 'undefined') {
                  console.log(`Projeto ${project.project} não passa no filtro NONE para gradle`);
                  passesFilters = false;
                  break;
                }
              } 
              // Caso especial para spring_boot "NENHUM"
              else if (filterType === 'spring_boot' && filterValue === window.Config.FILTERS.NONE_LABEL) { 
                if (projectRequirement !== null && typeof projectRequirement !== 'undefined' && projectRequirement !== "NENHUM") {
                  console.log(`Projeto ${project.project} não passa no filtro NONE para spring_boot`);
                  passesFilters = false;
                  break;
                }
              } 
              // Verificação normal de igualdade
              else if (projectRequirement !== filterValue) {
                console.log(`Projeto ${project.project} não passa no filtro ${filterType}=${filterValue}`);
                passesFilters = false;
                break;
              }
            }
        }
        
        // Se o projeto passar nos filtros, adicionar suas dependências
        if (passesFilters) {
          console.log(`Projeto ${project.project} passa em todos os filtros`);
          
          // Validação adicional de dependências
          if (Array.isArray(project.dependencies)) {
            const validDeps = project.dependencies.filter(d => d && typeof d === 'object');
            console.log(`Projeto ${project.project} tem ${validDeps.length} dependências válidas`);
            
            // Criar cópias de cada dependência para evitar mutações indesejadas
            const projectDeps = validDeps.map(dep => {
              // Criar nova instância da dependência
              const newDep = { ...dep };
              
              // Garantir que projects é um novo array e que inclui o projeto atual
              newDep.projects = Array.isArray(dep.projects) ? [...dep.projects] : [];
              if (!newDep.projects.includes(project.project)) {
                newDep.projects.push(project.project);
              }
              
              // Incluir o nome do projeto para referência
              newDep.projectName = project.project;
              
              return newDep;
            });
            
            allDeps = allDeps.concat(projectDeps);
          }
        }
      });
      
      let validDeps = allDeps.filter(dep => dep && typeof dep === 'object' && dep.group && dep.name);
      
      // Sempre retornar todas as dependências sem deduplicação para contagem total
      validDeps = validDeps.map(dep => {
        const uniqueId = Math.random().toString(36).substring(2) + Date.now().toString(36);
        const projectsList = dep.projects ? [...dep.projects] : [];
        if (dep.projectName && !projectsList.includes(dep.projectName)) {
          projectsList.push(dep.projectName);
        }
        return {...dep, id: uniqueId, projects: projectsList};
      });
      
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

/**
 * Obtém contagens separadas de dependências totais e únicas
 * @param {Array} projectsToProcess - Array de projetos para processar
 * @param {Object} activeFilters - Filtros ativos
 * @param {string} searchTerm - Termo de busca
 * @returns {Object} - Objeto com totalCount e uniqueCount
 */
function getDependencyCounts(projectsToProcess, activeFilters, searchTerm) {
  try {
    // Obter todas as dependências (totais)
    const totalDependencies = window.ProjectModel.getFilteredDependencies(projectsToProcess, activeFilters, searchTerm);
    
    // Criar versão única das dependências para contagem
    const depMap = {};
    totalDependencies.forEach(dep => {
      const versionString = (typeof dep.version === 'object' && dep.version !== null) ? dep.version.value : dep.version;
      const uniqueKey = `${dep.group}:${dep.name}:${versionString}`;
      
      if (!depMap[uniqueKey]) {
        depMap[uniqueKey] = { ...dep, projects: [] };
        if (dep.projectName && !depMap[uniqueKey].projects.includes(dep.projectName)) {
          depMap[uniqueKey].projects.push(dep.projectName);
        }
      } else if (dep.projectName && !depMap[uniqueKey].projects.includes(dep.projectName)) {
        depMap[uniqueKey].projects.push(dep.projectName);
      }
    });
    
    const uniqueDependencies = Object.values(depMap);
    
    return {
      totalCount: totalDependencies.length,
      uniqueCount: uniqueDependencies.length,
      totalDependencies: totalDependencies,
      uniqueDependencies: uniqueDependencies
    };
  } catch (error) {
    console.error("Erro ao obter contagens de dependências:", error);
    return {
      totalCount: 0,
      uniqueCount: 0,
      totalDependencies: [],
      uniqueDependencies: []
    };
  }
}

window.ProjectModel = ProjectModel;
window.initializeProjectModel = initializeProjectModel;
window.getAllProjects = getAllProjects;
window.getProjectByName = getProjectByName;
window.getFilteredProjects = getFilteredProjects;
window.getProjectsStats = getProjectsStats;
window.getDependencyCounts = getDependencyCounts;

window.projectModel = {
  initializeProjectModel,
  getAllProjects,
  getProjectByName,
  getFilteredProjects,
  getProjectsStats,
  getDependencyCounts
};
