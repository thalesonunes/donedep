// Função para atualizar a lista de projetos filtrados
function updateFilteredProjects(filteredData) {
  const filteredProjectsList = document.getElementById('filtered-projects-list');
  const filteredProjectsCount = document.getElementById('filtered-projects-count');
  const filteredDependenciesCount = document.getElementById('filtered-dependencies-count');
  
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
    chip.textContent = project;
    
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
          java: projectData.javaVersion,
          kotlin: projectData.kotlinVersion,
          gradle: projectData.gradleVersion,
          spring_boot: projectData.springBootVersion
        };

        // Atualizar cada filtro e suas opções
        Object.entries(filters).forEach(([key, value]) => {
          const selectId = key === 'spring_boot' ? 'filter-spring' : `filter-${key}`;
          const select = document.getElementById(selectId);
          if (select && value) {
            // Atualizar o activeFilters
            activeFilters[key] = value;
            // Atualizar o valor do select
            select.value = value;
          }
        });

        // Forçar atualização de todos os dropdowns
        updateAllDropdowns();
        
        // Atualizar a lista de projetos com os novos filtros
        const filteredProjects = getFilteredProjects();
        updateFilteredProjects(filteredProjects);
      }
    });
    
    filteredProjectsList.appendChild(chip);
  });
}

// Função para aplicar os filtros e buscar projetos
function getFilteredProjects() {
  // Se não houver filtros ativos, retornar todos os projetos
  const hasActiveFilters = Object.values(activeFilters).some(filter => filter !== null);
  if (!hasActiveFilters) {
    return allDependencies;
  }

  // Se houver filtros ativos, aplicar os filtros
  return allDependencies.filter(project => {
    const javaMatch = !activeFilters.java || project.javaVersion === activeFilters.java;
    const kotlinMatch = !activeFilters.kotlin || project.kotlinVersion === activeFilters.kotlin;
    const gradleMatch = !activeFilters.gradle || project.gradleVersion === activeFilters.gradle;
    const springMatch = !activeFilters.spring_boot || project.springBootVersion === activeFilters.spring_boot;
    
    return javaMatch && kotlinMatch && gradleMatch && springMatch;
  });
}
