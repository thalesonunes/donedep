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
  
  // Adicionar chips para cada projeto
  uniqueProjects.forEach(project => {
    const chip = document.createElement('div');
    chip.className = 'project-chip';
    chip.textContent = project;
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
