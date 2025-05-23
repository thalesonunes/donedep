/**
 * DoneDep - Lista de Projetos
 * Gerencia a visualização e interação com a lista de projetos filtrados
 */

// Usando funções e objetos expostos globalmente

/**
 * Atualiza a lista de projetos filtrados na UI
 * @param {Array} filteredData - Projetos filtrados para exibir
 */
function updateFilteredProjectsList(filteredData = []) {
  try {
    const filteredProjectsList = document.getElementById('filtered-projects-list');
    const filteredProjectsCount = document.getElementById('filtered-projects-count');
    const filteredDependenciesCount = document.getElementById('filtered-dependencies-count');
    
    if (!filteredProjectsList || !filteredProjectsCount || !filteredDependenciesCount) {
      throw new Error('Elementos de UI para projetos filtrados não encontrados');
    }
    
    // Limpar a lista atual
    filteredProjectsList.innerHTML = '';
    
    // Extrair projetos únicos dos dados filtrados
    const uniqueProjects = [...new Set(filteredData.map(item => item.project))];
    
    // Atualizar o contador de projetos
    filteredProjectsCount.textContent = uniqueProjects.length;
    
    // Calcular e atualizar o total de dependências
    const totalDependencies = filteredData.reduce((total, project) => {
      return total + (project.dependencies ? project.dependencies.length : 0);
    }, 0);
    filteredDependenciesCount.textContent = totalDependencies;
    
    // Adicionar chips para cada projeto
    uniqueProjects.forEach(project => {
      const chip = document.createElement('button');
      chip.className = 'project-chip';
      chip.textContent = window.utils.escapeHTML(project);
      
      // Encontrar os dados do projeto
      const projectData = filteredData.find(item => item.project === project);
      
      // Adicionar evento de clique
      chip.addEventListener('click', () => {
        // Atualizar os filtros com as versões do projeto
        if (projectData) {
          // Primeiro, desbloquear todos os dropdowns
          ['java', 'kotlin', 'gradle', 'spring'].forEach(type => {
            const dropdown = document.getElementById('filter-' + type);
            if (dropdown) {
              dropdown.disabled = false;
            }
          });

          // Atualizar os selects com as versões do projeto
          const filters = {
            java: projectData.javaVersion || projectData.requirements?.java,
            kotlin: projectData.kotlinVersion || projectData.requirements?.kotlin,
            gradle: projectData.gradleVersion || projectData.requirements?.gradle,
            spring_boot: projectData.springBootVersion || projectData.requirements?.spring_boot
          };

          // Atualizar cada filtro e suas opções
          Object.entries(filters).forEach(([key, value]) => {
            const selectId = key === 'spring_boot' ? 'filter-spring' : `filter-${key}`;
            const select = document.getElementById(selectId);
            if (select && value) {
              // Atualizar o filtro ativo usando a função global
              const filterKey = key === 'spring_boot' ? 'spring' : key;
              window.updateActiveFilter(filterKey, value);
            }
          });
        }
      });
      
      filteredProjectsList.appendChild(chip);
    });
  } catch (error) {
    logError({
      message: `Erro ao atualizar lista de projetos: ${error.message}`,
      type: ErrorType.RENDER,
      level: ErrorLevel.ERROR,
      originalError: error,
      context: { projectsCount: filteredData.length }
    });
  }
}

/**
 * Atualiza a lista de projetos com base nos filtros atuais
 * @param {string} [searchTerm] - Termo de busca opcional
 */
function refreshProjectsList(searchTerm = '') {
  try {
    const filteredProjects = getFilteredProjects(searchTerm);
    updateFilteredProjectsList(filteredProjects);
  } catch (error) {
    logError({
      message: `Erro ao atualizar lista de projetos: ${error.message}`,
      type: ErrorType.RENDER,
      level: ErrorLevel.ERROR,
      originalError: error
    });
  }
}

/**
 * Classe ProjectList - Manipulação de listas de projetos
 */
class ProjectList {
  /**
   * Copia todas as dependências no formato Gradle
   * @param {Array} dependencies - Lista de dependências
   */
  static getAllDependenciesGradle(dependencies) {
    if (dependencies.length === 0) {
      copyToClipboard('', 'Nenhuma dependência para copiar!');
      return;
    }
    const declarations = dependencies.map(dep =>
      `implementation "${dep.group}:${dep.name}:${dep.version}"`
    ).join('\n');
    copyToClipboard(declarations, 'Dependências copiadas no formato Gradle!');
  }

  /**
   * Copia todas as dependências no formato Maven
   * @param {Array} dependencies - Lista de dependências
   */
  static getAllDependenciesMaven(dependencies) {
    if (dependencies.length === 0) {
      copyToClipboard('', 'Nenhuma dependência para copiar!');
      return;
    }
    const declarations = dependencies.map(dep => 
      `<dependency>\n    <groupId>${dep.group}</groupId>\n    <artifactId>${dep.name}</artifactId>\n    <version>${dep.version}</version>\n</dependency>`
    ).join('\n');
    copyToClipboard(declarations, 'Dependências copiadas no formato Maven!');
  }
}

// Exportar para compatibilidade com código existente
window.projectList = {
  updateFilteredProjectsList,
  refreshProjectsList
};

// Expor globalmente
window.ProjectList = ProjectList;
window.updateFilteredProjectsList = updateFilteredProjectsList;
window.refreshProjectsList = refreshProjectsList;
