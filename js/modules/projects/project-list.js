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
    console.log(`updateFilteredProjectsList chamado com ${filteredData?.length || 0} projetos`);
    
    const filteredProjectsList = document.getElementById('filtered-projects-list');
    const filteredProjectsCount = document.getElementById('filtered-projects-count');
    const filteredDependenciesCount = document.getElementById('filtered-dependencies-count');
    
    if (!filteredProjectsList || !filteredProjectsCount || !filteredDependenciesCount) {
      throw new Error('Elementos de UI para projetos filtrados não encontrados');
    }
    
    // Limpar a lista atual
    filteredProjectsList.innerHTML = '';
    
    // Garantir que estamos trabalhando com dados válidos
    const validData = Array.isArray(filteredData) ? filteredData.filter(item => item && item.project) : [];
    console.log(`Dados válidos após filtragem: ${validData.length} projetos`);
    
    // Verificar todos os projetos para diagnóstico
    console.log("Projetos filtrados:", validData.map(item => item.project).join(", "));
    
    // Extrair projetos únicos dos dados filtrados usando um Set para garantir unicidade
    const projectNames = validData.map(item => item.project);
    const uniqueProjects = [...new Set(projectNames)];
    console.log(`Projetos únicos: ${uniqueProjects.length} (${uniqueProjects.join(", ")})`);
    
    // Atualizar o contador de projetos
    filteredProjectsCount.textContent = uniqueProjects.length;
    
    // Mapa para armazenar dependências únicas por projeto
    const projectDepsMap = new Map();
    
    // Contar dependências únicas por projeto
    validData.forEach(project => {
      if (!project || !project.project) return;
      
      if (!projectDepsMap.has(project.project)) {
        // Inicializar com conjunto vazio para este projeto
        projectDepsMap.set(project.project, new Set());
      }
      
      // Adicionar cada dependência ao conjunto (usando chave única)
      if (Array.isArray(project.dependencies)) {
        project.dependencies.forEach(dep => {
          if (dep && dep.group && dep.name) {
            const depKey = `${dep.group}:${dep.name}:${dep.version}`;
            projectDepsMap.get(project.project).add(depKey);
          }
        });
      }
    });
    
    // Contar total de dependências únicas
    let totalDependencies = 0;
    projectDepsMap.forEach(depSet => {
      totalDependencies += depSet.size;
    });
    
    console.log(`Total de dependências únicas por projeto: ${totalDependencies}`);
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
        console.log(`Projeto selecionado: ${project}`);
        
        // Primeiro, limpar todos os filtros atuais
        window.clearAllFilters();
        
        // Atualizar os filtros com as versões do projeto
        if (projectData) {
          console.log('Dados do projeto selecionado:', projectData);
          
          // Garantir que os dropdowns estão habilitados
          ['java', 'kotlin', 'gradle', 'spring'].forEach(type => {
            const dropdown = document.getElementById('filter-' + type);
            if (dropdown) {
              dropdown.disabled = false;
            }
          });

          // Atualizar os selects com as versões do projeto
          // Verificar primeiro em requirements e depois nos campos legados
          const filters = {
            java: projectData.requirements?.java || projectData.javaVersion,
            kotlin: projectData.requirements?.kotlin || projectData.kotlinVersion,
            gradle: projectData.requirements?.gradle || projectData.gradleVersion,
            spring_boot: projectData.requirements?.spring_boot || projectData.springBootVersion
          };

          console.log('Aplicando filtros:', filters);

          // Atualizar cada filtro e suas opções
          Object.entries(filters).forEach(([key, value]) => {
            if (!value) return; // Pular se não houver valor
            
            const selectId = key === 'spring_boot' ? 'filter-spring' : `filter-${key}`;
            const select = document.getElementById(selectId);
            
            if (select) {
              // Verificar se a opção existe no select
              const optionExists = Array.from(select.options).some(option => option.value === value);
              
              if (optionExists) {
                // Atualizar o filtro ativo usando a função global
                const filterKey = key === 'spring_boot' ? 'spring' : key;
                window.updateActiveFilter(filterKey, value);
                console.log(`Filtro ${filterKey} definido para ${value}`);
              } else {
                console.warn(`Valor ${value} não encontrado no select ${selectId}`);
              }
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
