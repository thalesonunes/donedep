// JavaScript extraído do index.html
const jsonPath = 'data/dependencies.json';
let allDependencies = [];
let activeFilters = {
  java: null,
  kotlin: null,
  gradle: null,
  spring_boot: null
};
let searchTerm = '';
const filtersContainer = document.getElementById('filters-container');
const searchInput = document.getElementById('search-input');
const copyAllButton = document.getElementById('copy-all-button');
const clearFiltersButton = document.getElementById('clear-filters-button');
const dependenciesGrid = document.getElementById('dependencies-grid');

// Funções para o modal de filtro bloqueado
function showFilterLockedModal() {
  const modal = document.getElementById('filter-locked-modal');
  if (!modal.classList.contains('show')) {
    modal.classList.add('show');
    // Fechar o modal automaticamente após 3 segundos
    setTimeout(() => {
      closeFilterLockedModal();
    }, 3000);
  }
}

function closeFilterLockedModal() {
  const modal = document.getElementById('filter-locked-modal');
  modal.classList.remove('show');
}

// Definindo as funções auxiliares primeiro
function getUnique(projects, key) {
  if (!projects || projects.length === 0) {
    return [];
  }
  
  // Safe accessor function to get requirements value with error handling
  const safeGetRequirement = (project, key) => {
    try {
      // Verifica se o projeto e requirements existem
      if (!project || !project.requirements) {
        return null;
      }
      return project.requirements[key];
    } catch (e) {
      console.error(`Error accessing requirement '${key}' for project:`, project, e);
      return null;
    }
  };
  
  // Função para comparar versões
  const compareVersions = (a, b) => {
    if (a === b) return 0;
    
    // Se um dos valores é "Nenhum", ele vem por último
    if (a === 'Nenhum') return 1;
    if (b === 'Nenhum') return -1;
    
    // Converter strings de versão para arrays de números
    const aParts = a.toString().split('.').map(Number);
    const bParts = b.toString().split('.').map(Number);
    
    // Comparar cada parte da versão
    for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
      const aVal = aParts[i] || 0;
      const bVal = bParts[i] || 0;
      if (aVal !== bVal) {
        return aVal - bVal;
      }
    }
    return 0;
  };
  
  // Tratamento especial para Kotlin - incluir valores null como "Nenhum"
  if (key === 'kotlin') {
    const values = projects.map(p => {
      const value = safeGetRequirement(p, key);
      // Se o valor for null ou undefined e estivermos buscando por Kotlin, retornamos um valor especial
      if (value === null || value === undefined) {
        return 'Nenhum';
      }
      return value;
    });
    return Array.from(new Set(values.filter(v => v !== undefined))).sort(compareVersions);
  }
  
  // Para outros campos, apenas extraímos valores únicos não nulos e ordenamos por versão
  return Array.from(new Set(projects.map(p => safeGetRequirement(p, key)).filter(Boolean))).sort(compareVersions);
}

function fillDropdown(id, values, selectedValue) {
  const select = document.getElementById(id);
  select.innerHTML = '';
  
  // Se há um valor selecionado e ele existe nas opções disponíveis
  if (selectedValue && values.includes(selectedValue)) {
    // Opção selecionada
    const optSelected = document.createElement('option');
    optSelected.value = selectedValue;
    optSelected.textContent = selectedValue;
    optSelected.selected = true;
    select.appendChild(optSelected);
    
    // Bloquear o dropdown quando um valor é selecionado
    select.disabled = true;
  } else {
    // Se houver apenas uma opção disponível, selecioná-la automaticamente
    if (values.length === 1) {
      const optOnly = document.createElement('option');
      optOnly.value = values[0];
      optOnly.textContent = values[0];
      optOnly.selected = true;
      select.appendChild(optOnly);
      
      // Atualizar o filtro ativo correspondente e bloquear o dropdown
      updateActiveFilter(id, values[0]);
      select.disabled = true;
    } else {
      // Se houver múltiplas opções, mostrar todas
      const optAll = document.createElement('option');
      optAll.value = '';
      optAll.textContent = 'Todas';
      select.appendChild(optAll);
      
      // Adicionar opções compatíveis em ordem alfabética
      values.sort().forEach(val => {
        const opt = document.createElement('option');
        opt.value = val;
        opt.textContent = val;
        select.appendChild(opt);
      });
      
      // Manter o dropdown desbloqueado quando não há seleção
      select.disabled = false;
    }
  }
  
  // Se não houver opções disponíveis, desabilitar o dropdown
  if (values.length === 0) {
    select.disabled = true;
  }
}

function escapeHTML(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function copyToClipboard(text, message = 'Copiado com sucesso!') {
  // Usar a API moderna para copiar para a área de transferência
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text)
      .then(() => {
        showCopyModal(message);
      })
      .catch(err => {
        console.error('Erro ao copiar para a área de transferência:', err);
        // Fallback para o método antigo
        fallbackCopyToClipboard(text, message);
      });
  } else {
    // Método antigo para navegadores que não suportam a API Clipboard
    fallbackCopyToClipboard(text, message);
  }
}

function fallbackCopyToClipboard(text, message) {
  const textarea = document.createElement('textarea');
  textarea.value = text;
  textarea.setAttribute('readonly', '');
  textarea.style.position = 'absolute';
  textarea.style.left = '-9999px';
  document.body.appendChild(textarea);
  textarea.select();
  document.execCommand('copy');
  document.body.removeChild(textarea);
  showCopyModal(message);
}

function showCopyModal(message) {
  // Mostrar o modal personalizado
  const copyModal = document.getElementById('copy-modal');
  const copyModalText = document.getElementById('copy-modal-text');
  
  // Remover a classe show caso já esteja aplicada
  copyModal.classList.remove('show');
  
  // Forçar reflow para reiniciar a animação
  void copyModal.offsetWidth;
  
  copyModalText.textContent = message;
  copyModal.classList.add('show');
  
  // Esconder o modal após 2 segundos
  setTimeout(() => {
    copyModal.classList.remove('show');
  }, 2000);
}

function showIncompatibleModal() {
  // Mostrar o modal de incompatibilidade
  const incompatibleModal = document.getElementById('incompatible-modal');
  
  // Remover a classe show caso já esteja aplicada
  incompatibleModal.classList.remove('show');
  
  // Forçar reflow para reiniciar a animação
  void incompatibleModal.offsetWidth;
  
  incompatibleModal.classList.add('show');
  
  // Esconder o modal após 3 segundos
  setTimeout(() => {
    incompatibleModal.classList.remove('show');
  }, 3000);
}

// Função principal para carregar as dependências
async function loadDependencies() {
  try {
    console.log('Iniciando carregamento de dependências de:', jsonPath);
    
    const response = await fetch(jsonPath + '?v=' + Date.now());
    
    if (!response.ok) {
      throw new Error(`Erro HTTP: ${response.status} ${response.statusText}`);
    }
    
    const data = await response.json();
    
    // Verificar se temos um erro retornado pelo adaptador de dados
    if (data && data.error === true) {
      console.error('Erro retornado pelo adaptador de dados:', data.message);
      throw new Error(data.message || 'Erro ao processar dependências');
    }
    
    // Validar e processar os dados recebidos
    if (Array.isArray(data)) {
      allDependencies = data;
      console.log(`Carregadas ${allDependencies.length} projetos com sucesso`);
    } else if (data && typeof data === 'object' && data.dependencies) {
      // Caso seja um objeto individual, converte para array
      allDependencies = [data];
      console.log('Carregado 1 projeto com sucesso (formato objeto)');
    } else {
      console.error('Formato de dados inválido');
      throw new Error('Formato de dados inválido');
    }
    
    // Verificação adicional para garantir que requirements existe
    allDependencies = allDependencies.map(project => {
      if (!project.requirements) {
        console.warn(`Projeto ${project.project || 'desconhecido'} não tem objeto requirements. Criando um objeto vazio.`);
        project.requirements = {
          java: null,
          kotlin: null,
          gradle: null,
          spring_boot: null
        };
      }
      return project;
    });
    
    initializeFilters();
    renderDependencies();
    setupEventListeners();
  } catch (error) {
    // Exibir mensagem de erro mais detalhada na interface
    const errorHtml = `
      <div class="error-container">
        <div class="error-title">Erro ao carregar dependências</div>
        <div class="error-message">${error.message}</div>
        ${error.suggestion ? `<div class="error-suggestion">${error.suggestion}</div>` : ''}
        <div class="error-action">
          <button class="retry-button" onclick="location.reload()">Tentar Novamente</button>
        </div>
      </div>
    `;
    
    dependenciesGrid.innerHTML = errorHtml;
    console.error('Erro ao carregar dependências:', error);
  }
}
function initializeFilters() {
  // Coletar todos os projetos e suas combinações
  window._allProjects = allDependencies;
  
  // Mostrar todos os projetos, mesmo que não tenham dependências
  // Isso é útil para visualizar as tecnologias usadas mesmo sem dependências
  
  // Inicializar os dropdowns com as opções válidas
  updateAllDropdowns();
  
  // Debug: exibir relações entre filtros no console
  debugFilterRelationships();
  
  // Aviso se não houver dependências
  if (!window._allProjects.some(p => p.dependencies && p.dependencies.length > 0)) {
    console.warn("Nenhum projeto tem dependências. Verifique a extração.");
  }
}

function updateAllDropdowns() {
  // Obter as seleções atuais dos filtros
  const selected = {
    java: document.getElementById('filter-java').value || null,
    kotlin: document.getElementById('filter-kotlin').value || null,
    gradle: document.getElementById('filter-gradle').value || null,
    spring_boot: document.getElementById('filter-spring').value || null
  };
  
  // Sincronizar com activeFilters para garantir consistência
  Object.entries(selected).forEach(([key, value]) => {
    activeFilters[key] = value;
  });
  
  console.log("Atualizando dropdowns com seleções:", selected);
  
  // Garantir que todos os projetos tenham o objeto requirements
  if (window._allProjects) {
    window._allProjects.forEach(project => {
      if (!project.requirements) {
        console.warn(`Projeto ${project.project || 'sem nome'} não tem requisitos definidos. Criando objeto vazio.`);
        project.requirements = {
          java: null,
          kotlin: null,
          gradle: null,
          spring_boot: null
        };
      }
    });
  }
  
  // Para cada filtro, precisamos obter as opções compatíveis considerando os outros filtros ativos
  const javaCompatibleOptions = getCompatibleOptions('java', selected);
  const gradleCompatibleOptions = getCompatibleOptions('gradle', selected);
  const kotlinCompatibleOptions = getCompatibleOptions('kotlin', selected);
  const springBootCompatibleOptions = getCompatibleOptions('spring_boot', selected);
  
  // Atualizar cada dropdown mantendo sua seleção atual se ainda for válida
  fillDropdown('filter-java', javaCompatibleOptions, selected.java);
  fillDropdown('filter-gradle', gradleCompatibleOptions, selected.gradle);
  fillDropdown('filter-kotlin', kotlinCompatibleOptions, selected.kotlin);
  fillDropdown('filter-spring', springBootCompatibleOptions, selected.spring_boot);
  
  // Se algum dropdown tiver apenas uma opção e não estiver selecionado,
  // selecionar automaticamente
  if (javaCompatibleOptions.length === 1 && !selected.java) {
    document.getElementById('filter-java').value = javaCompatibleOptions[0];
    activeFilters.java = javaCompatibleOptions[0];
  }
  if (gradleCompatibleOptions.length === 1 && !selected.gradle) {
    document.getElementById('filter-gradle').value = gradleCompatibleOptions[0];
    activeFilters.gradle = gradleCompatibleOptions[0];
  }
  if (kotlinCompatibleOptions.length === 1 && !selected.kotlin) {
    document.getElementById('filter-kotlin').value = kotlinCompatibleOptions[0];
    activeFilters.kotlin = kotlinCompatibleOptions[0];
  }
  if (springBootCompatibleOptions.length === 1 && !selected.spring_boot) {
    document.getElementById('filter-spring').value = springBootCompatibleOptions[0];
    activeFilters.spring_boot = springBootCompatibleOptions[0];
  }
}
function debugFilterRelationships() {
  console.log("%c=== Análise de Relações entre Filtros ===", "font-weight:bold; color:blue;");
  
  // Dados de cada projeto
  console.log("%cDados dos projetos carregados:", "font-weight:bold");
  window._allProjects.forEach(p => {
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
  
  // Ver quais versões de Gradle existem para cada versão de Java
  console.log("%cVersões de Gradle por versão de Java:", "font-weight:bold");
  const javaVersions = getUnique(window._allProjects, 'java');
  
  javaVersions.forEach(javaVersion => {
    const filteredProjects = window._allProjects.filter(
      p => p.requirements && p.requirements.java === javaVersion
    );
    const gradleVersions = getUnique(filteredProjects, 'gradle');
    console.log(`Java ${javaVersion}: Gradle ${gradleVersions.join(', ')}`);
    
    // Listar os projetos que têm essa combinação
    const projectNames = filteredProjects.map(p => p.project).join(", ");
    console.log(`  Projetos com Java ${javaVersion}: ${projectNames}`);
  });
  
  // Ver quais versões de Spring Boot existem para cada versão de Java
  console.log("%cVersões de Spring Boot por versão de Java:", "font-weight:bold");
  javaVersions.forEach(javaVersion => {
    const filteredProjects = window._allProjects.filter(
      p => p.requirements && p.requirements.java === javaVersion
    );
    const springVersions = getUnique(filteredProjects, 'spring_boot');
    console.log(`Java ${javaVersion}: Spring Boot ${springVersions.join(', ')}`);
  });
  
  // Ver quais versões de Kotlin existem para cada versão de Java
  console.log("%cVersões de Kotlin por versão de Java:", "font-weight:bold");
  javaVersions.forEach(javaVersion => {
    const filteredProjects = window._allProjects.filter(
      p => p.requirements && p.requirements.java === javaVersion
    );
    const kotlinVersions = getUnique(filteredProjects, 'kotlin');
    console.log(`Java ${javaVersion}: Kotlin ${kotlinVersions.join(', ')}`);
  });
}

// Função para obter opções compatíveis para um determinado filtro
function getCompatibleOptions(filterToUpdate, currentSelections) {
  // Começar com todos os projetos
  let filteredProjects = [...window._allProjects];
  
  // Aplicar apenas os filtros que estão ativos e não são o filtro que estamos atualizando
  Object.entries(currentSelections).forEach(([key, value]) => {
    // Só aplicar o filtro se ele tiver um valor e não for o filtro que estamos atualizando
    if (value && key !== filterToUpdate) {
      console.log(`Aplicando filtro ${key}=${value} para obter opções de ${filterToUpdate}`);
      
      if (key === 'kotlin' && value === 'Nenhum') {
        // Caso especial para Kotlin "Nenhum"
        filteredProjects = filteredProjects.filter(p => 
          p && p.requirements && (p.requirements[key] === null || p.requirements[key] === undefined)
        );
      } else {
        // Filtro normal
        filteredProjects = filteredProjects.filter(p => 
          p && p.requirements && p.requirements[key] === value
        );
      }
    }
  });
  
  // Obter as opções únicas para o filtro que estamos atualizando
  const key = filterToUpdate === 'spring' ? 'spring_boot' : filterToUpdate;
  const compatibleOptions = getUnique(filteredProjects, key);
  
  console.log(`Opções compatíveis para ${filterToUpdate}:`, compatibleOptions);
  
  return compatibleOptions;
}

function clearAllFilters() {
  console.log("Limpando todos os filtros");
  
  // Limpar todos os filtros ativos
  activeFilters = {
    java: null,
    kotlin: null,
    gradle: null,
    spring_boot: null
  };
  
  // Desbloquear e resetar todos os dropdowns
  ['java', 'kotlin', 'gradle', 'spring'].forEach(type => {
    const dropdown = document.getElementById('filter-' + type);
    if (dropdown) {
      dropdown.value = '';
      dropdown.disabled = false;
    }
  });
  
  // Atualizar todos os dropdowns para mostrar todas as opções válidas
  updateAllDropdowns();
  
  // Limpar campo de busca
  searchInput.value = '';
  searchTerm = '';
  
  // Renderizar todas as dependências
  renderDependencies();
  
  console.log("Filtros limpos com sucesso");
}

function setupEventListeners() {
  // Dropdowns
  ['java','kotlin','gradle','spring'].forEach(type => {
    const dropdown = document.getElementById('filter-' + type);
    
    // Evento de mudança no dropdown
    dropdown.addEventListener('change', e => {
      const filterKey = type === 'spring' ? 'spring_boot' : type;
      const newValue = e.target.value;
      
      // Atualizar apenas o filtro que mudou
      activeFilters[filterKey] = newValue || null;
      
      // Atualizar os dropdowns para refletir as opções compatíveis
      // considerando a mudança apenas neste filtro
      updateAllDropdowns();
      
      // Renderizar dependências com os novos filtros
      renderDependencies();
      
      console.log(`Filtro ${filterKey} alterado para: ${activeFilters[filterKey]}`);
    });
    
    // Evento de clique no dropdown - para mostrar o modal quando estiver desabilitado
    dropdown.addEventListener('mousedown', (e) => {
      if (e.target.disabled) {
        e.preventDefault();
        showFilterLockedModal();
      }
    });
  });
  // Busca
  searchInput.addEventListener('input', (e) => {
    searchTerm = e.target.value.toLowerCase();
    renderDependencies();
  });
  // Botão para limpar filtros
  clearFiltersButton.addEventListener('click', clearAllFilters);
  // Copiar todas as declarações
  copyAllButton.addEventListener('click', () => {
    const filteredDependencies = getFilteredDependencies();
    if (filteredDependencies.length === 0) {
      copyToClipboard('', 'Nenhuma dependência para copiar!');
      return;
    }
    const declarations = filteredDependencies.map(dep => {
      // Sempre usar a declaração normal (já resolvida no back-end)
      return dep.declaration;
    }).join('\n');
    copyToClipboard(declarations, 'Todas as dependências copiadas!');
  });
}
function renderDependencies() {
  const filteredDependencies = getFilteredDependencies();
  if (filteredDependencies.length === 0) {
    // Verificar quais filtros estão ativos
    const activeFilterLabels = [];
    if (activeFilters.java) activeFilterLabels.push(`Java: ${activeFilters.java}`);
    if (activeFilters.kotlin) activeFilterLabels.push(`Kotlin: ${activeFilters.kotlin}`);
    if (activeFilters.gradle) activeFilterLabels.push(`Gradle: ${activeFilters.gradle}`);
    if (activeFilters.spring_boot) activeFilterLabels.push(`Spring Boot: ${activeFilters.spring_boot}`);
    
    // Mensagem personalizada baseada nos filtros ativos
    let message = 'Nenhuma dependência encontrada com os filtros atuais.';
    if (activeFilterLabels.length > 0) {
      message += '<br><span class="filter-info">Filtros ativos: ' + activeFilterLabels.join(', ') + '</span>';
      message += '<br><span class="filter-tip">Tente uma combinação diferente ou limpe os filtros.</span>';
    } else {
      // Se não há filtros ativos mas ainda não tem dependências, é provável que o script não extraiu corretamente
      message += '<br><span class="filter-info">Nenhuma dependência foi encontrada em nenhum projeto.</span>';
      message += '<br><span class="filter-tip">Verifique se o script de extração está configurado corretamente.</span>';
    }
    
    dependenciesGrid.innerHTML = `<div class="no-results">${message}</div>`;
    return;
  }
  dependenciesGrid.innerHTML = '';
  filteredDependencies.forEach(dep => {
    const card = document.createElement('div');
    card.className = 'dependency-card';
    
    // Simplificado: usar sempre o campo declaration
    const copyDeclaration = dep.declaration;
    
    // Verificar se tem variável não resolvida
    const versionClass = dep.hasUnresolvedVariable ? 'version version-warning' : 'version';
    
    // Preparar conteúdo adicional para variáveis não resolvidas
    let warningInfo = '';
    if (dep.hasUnresolvedVariable) {
      warningInfo = `<div class="variable-warning">
        <span class="warning-icon">⚠️</span> 
        <span class="warning-text">Variável não resolvida</span>
        <span class="original-version" title="Versão original: ${dep.originalVersion}">ℹ️</span>
      </div>`;
    }
    
    // Extrair os projetos que usam esta dependência
    let projectsHtml = '';
    const anyFilterActive = Object.values(activeFilters).some(v => v);
    
    // Se há projetos e contém um array
    if (dep.projects && Array.isArray(dep.projects) && dep.projects.length > 0) {
      // Se houver apenas um projeto ou se filtros estiverem ativos, mostre o nome do projeto
      if (dep.projects.length === 1 || anyFilterActive) {
        projectsHtml = `<div class="dependency-projects">${dep.projects.join(', ')}</div>`;
      } 
      // Se não houver filtros ativos e houver múltiplos projetos, mostre a lista de projetos
      else if (dep.projects.length > 1) {
        projectsHtml = `<div class="dependency-projects">${dep.projects.join(',\n')}</div>`;
      }
    }
    
    card.innerHTML = `
      <div class="dependency-group">${dep.group}</div>
      <div class="dependency-name">${dep.name}</div>
      ${projectsHtml}
      <div class="dependency-version">
        <span class="${versionClass}" id="version-${dep.id || Math.random().toString(36).substring(2)}">${dep.version}</span>
        ${warningInfo}
        <span class="material-symbols-outlined copy-button" data-declaration="${escapeHTML(copyDeclaration)}">content_copy</span>
      </div>
    `;
    dependenciesGrid.appendChild(card);
    card.querySelector('.copy-button').addEventListener('click', (e) => {
      const declaration = e.currentTarget.dataset.declaration;
      copyToClipboard(declaration, 'Dependência copiada!');
    });
  });
}
function getFilteredDependencies() {
  console.log("Obtendo dependências filtradas...");
  
  // Coletar todas as dependências de todos os projetos
  let allDeps = [];
  let anyFilterActive = Object.values(activeFilters).some(v => v);
  
  try {
    // Usar window._allProjects que já foi filtrado para conter apenas projetos com dependências
    const projects = window._allProjects || [];
    
    // Primeiro verificar se todos os projetos têm a estrutura requirements
    projects.forEach((project, index) => {
      if (!project) {
        console.warn(`Projeto na posição ${index} é null ou undefined`);
        return;
      }
      
      if (!project.requirements) {
        console.warn(`Projeto ${project.project || 'sem nome'} não tem requisitos definidos`);
        project.requirements = {
          java: null,
          kotlin: null,
          gradle: null,
          spring_boot: null
        };
      }
    });
    
    // Processar projetos para filtros
    projects.forEach(project => {
      if (!project) return;
      
      // Verificar se o projeto passa pelos filtros ativos
      let passesFilters = true;
      for (const [filterType, filterValue] of Object.entries(activeFilters)) {
        if (filterValue) {
          // Tratamento especial para o valor "Nenhum" do Kotlin
          if (filterType === 'kotlin' && filterValue === 'Nenhum') {
            // Verifica se o projeto NÃO tem o valor de Kotlin (ou seja, é null ou undefined)
            if (project.requirements && project.requirements[filterType] !== null && project.requirements[filterType] !== undefined) {
              passesFilters = false;
              break;
            }
          } else if (!project.requirements || project.requirements[filterType] !== filterValue) {
            passesFilters = false;
            break;
          }
        }
      }
      
      if (passesFilters) {
        // Verificar se o projeto tem dependências válidas
        if (Array.isArray(project.dependencies)) {
          allDeps = allDeps.concat(project.dependencies);
        } else if (project.dependencies) {
          console.warn(`Projeto ${project.project} tem dependências no formato inválido:`, project.dependencies);
        }
      }
    });
    
    console.log(`Encontradas ${allDeps.length} dependências antes da filtragem`);
    
    // Recarregar todas as dependências de todos os projetos se não houver filtro
    if (!anyFilterActive) {
      allDeps = [];
      projects.forEach(project => {
        if (project && Array.isArray(project.dependencies)) {
          // Adicionar o nome do projeto em cada dependência
          const projectDeps = project.dependencies.map(dep => ({
            ...dep,
            projects: dep.projects ? [...dep.projects] : [],
            projectName: project.project
          }));
          allDeps = allDeps.concat(projectDeps);
        }
      });
      
      // Filtrar dependências válidas (com group e name)
      const validDeps = allDeps.filter(dep => dep && typeof dep === 'object' && dep.group && dep.name);
      if (validDeps.length < allDeps.length) {
        console.warn(`Removidas ${allDeps.length - validDeps.length} dependências inválidas`);
      }
      allDeps = validDeps;
      
      // Quando não há filtros, agrupar dependências iguais com projetos diferentes
      console.log("Nenhum filtro ativo - agrupando dependências por grupo/nome");
      const depMap = {};
      allDeps.forEach(dep => {
        const key = `${dep.group}:${dep.name}:${dep.version}`;
        if (!depMap[key]) {
          // Adicionar um ID único para cada dependência
          const uniqueId = Math.random().toString(36).substring(2) + Date.now().toString(36);
          depMap[key] = {...dep, id: uniqueId, projects: []};
          // Adicionar o primeiro projeto se existir
          if (dep.projectName && !depMap[key].projects.includes(dep.projectName)) {
            depMap[key].projects.push(dep.projectName);
          }
        } else {
          // Se a dependência já existe, adicionar o projeto à lista
          if (dep.projectName && !depMap[key].projects.includes(dep.projectName)) {
            depMap[key].projects.push(dep.projectName);
          }
        }
      });
      allDeps = Object.values(depMap);
    } else {
      // Se houver filtros ativos, NÃO agrupar as dependências
      console.log("Filtros ativos - mantendo dependências separadas por projeto");
      
      // Filtrar dependências válidas (com group e name)
      const validDeps = allDeps.filter(dep => dep && typeof dep === 'object' && dep.group && dep.name);
      if (validDeps.length < allDeps.length) {
        console.warn(`Removidas ${allDeps.length - validDeps.length} dependências inválidas`);
      }
      allDeps = validDeps;
      
      // Garantir que cada dependência tem o array projects com pelo menos o nome do projeto
      allDeps = allDeps.map(dep => {
        // Adicionar ID único para cada dependência
        const uniqueId = Math.random().toString(36).substring(2) + Date.now().toString(36);
        
        // Garantir que projects é um array
        if (!dep.projects) {
          dep.projects = [];
        }
        
        // Se não temos um nome de projeto específico para a dependência,
        // tentar identificar o projeto de alguma forma
        if (dep.projectName && !dep.projects.includes(dep.projectName)) {
          dep.projects.push(dep.projectName);
        }
        
        return {...dep, id: uniqueId};
      });
    }
    
    // Aplicar filtro de busca
    if (searchTerm) {
      const beforeSearchCount = allDeps.length;
      allDeps = allDeps.filter(dep => {
        try {
          // Buscar em nome, grupo e versão
          const nameMatch = dep.name && dep.name.toLowerCase().includes(searchTerm.toLowerCase());
          const groupMatch = dep.group && dep.group.toLowerCase().includes(searchTerm.toLowerCase());
          const versionMatch = dep.version && dep.version.toLowerCase().includes(searchTerm.toLowerCase());
          
          // Buscar também nos projetos (se houver)
          let projectsMatch = false;
          if (dep.projects && Array.isArray(dep.projects)) {
            projectsMatch = dep.projects.some(project => 
              project && project.toLowerCase().includes(searchTerm.toLowerCase())
            );
          } else if (dep.projectName) {
            projectsMatch = dep.projectName.toLowerCase().includes(searchTerm.toLowerCase());
          }
          
          return nameMatch || groupMatch || versionMatch || projectsMatch;
        } catch (e) {
          console.error("Erro ao filtrar dependência por termo de busca:", e, dep);
          return false;
        }
      });
      console.log(`Filtro de busca '${searchTerm}' reduziu de ${beforeSearchCount} para ${allDeps.length} dependências`);
    }
  } catch (error) {
    console.error("Erro ao processar dependências:", error);
    allDeps = [];
  }
  
  console.log(`Retornando ${allDeps.length} dependências filtradas`);
  return allDeps;
}
// Inicializar a aplicação
loadDependencies();

function updateActiveFilter(id, value) {
  // Converter o ID do elemento para a chave do filtro
  const filterKey = id.replace('filter-', '');
  const actualKey = filterKey === 'spring' ? 'spring_boot' : filterKey;
  
  // Atualizar o filtro ativo
  activeFilters[actualKey] = value || null;
  
  // Recarregar as dependências para refletir a mudança
  renderDependencies();
}
