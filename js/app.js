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

// Definindo as funções auxiliares primeiro
function getUnique(projects, key) {
  if (!projects || projects.length === 0) {
    return [];
  }
  
  // Tratamento especial para Kotlin - incluir valores null como "Nenhum"
  if (key === 'kotlin') {
    const values = projects.map(p => {
      const value = p.requirements && p.requirements[key];
      // Se o valor for null ou undefined e estivermos buscando por Kotlin, retornamos um valor especial
      if (value === null || value === undefined) {
        return 'Nenhum';
      }
      return value;
    });
    return Array.from(new Set(values.filter(v => v !== undefined))).sort();
  }
  
  // Para outros campos, apenas extraímos valores únicos não nulos
  return Array.from(new Set(projects.map(p => p.requirements && p.requirements[key]).filter(Boolean))).sort();
}

function fillDropdown(id, values, selectedValue) {
  const select = document.getElementById(id);
  if (!select) {
    console.error(`Elemento com ID '${id}' não encontrado`);
    return;
  }
  
  // Guardar o valor atual antes de limpar o dropdown
  const prev = select.value;
  
  // Limpar e adicionar opção padrão
  select.innerHTML = '<option value="">Todas</option>';
  
  // Se não houver opções compatíveis e um valor estiver selecionado,
  // é preciso resetar porque a combinação não é compatível
  if (values.length === 0 && selectedValue) {
    console.warn(`Nenhuma opção compatível para ${id} com o valor ${selectedValue}. Resetando filtro.`);
    
    // Resetar o valor do dropdown
    select.value = '';
    
    // Atualizar o filtro ativo correspondente
    const filterId = id.replace('filter-', '');
    const filterKey = filterId === 'spring' ? 'spring_boot' : filterId;
    activeFilters[filterKey] = null;
    
    // Notificar que este filtro foi resetado devido a incompatibilidade
    if (!select.classList.contains('filter-reset-animation')) {
      select.classList.add('filter-reset-animation');
      setTimeout(() => {
        select.classList.remove('filter-reset-animation');
      }, 1000);
    }
    
    // Acionar evento de mudança para atualizar os outros dropdowns
    const event = new Event('change');
    select.dispatchEvent(event);
    
    return;
  }
  
  // Adicionar opções disponíveis
  values.sort().forEach(val => {
    const opt = document.createElement('option');
    opt.value = val;
    opt.textContent = val;
    if (selectedValue === val) opt.selected = true;
    select.appendChild(opt);
  });
  
  // Se houver apenas uma opção, selecioná-la automaticamente
  if (values.length === 1 && !selectedValue) {
    select.value = values[0];
    
    // Atualizar o filtro ativo correspondente
    const filterId = id.replace('filter-', '');
    const filterKey = filterId === 'spring' ? 'spring_boot' : filterId;
    activeFilters[filterKey] = values[0];
    
    console.log(`Seleção automática: ${filterId} = ${values[0]}`);
  }
  
  // Se um valor está selecionado mas não existe mais nas opções disponíveis,
  // resetar para "Todas"
  if (selectedValue && !values.includes(selectedValue)) {
    select.value = '';
    
    // Atualizar o filtro ativo correspondente
    const filterId = id.replace('filter-', '');
    const filterKey = filterId === 'spring' ? 'spring_boot' : filterId;
    activeFilters[filterKey] = null;
    
    // Notificar que este filtro foi resetado devido a incompatibilidade
    if (!select.classList.contains('filter-reset-animation')) {
      select.classList.add('filter-reset-animation');
      setTimeout(() => {
        select.classList.remove('filter-reset-animation');
      }, 1000);
    }
    
    // Acionar evento de mudança para atualizar os outros dropdowns
    const event = new Event('change');
    select.dispatchEvent(event);
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

// Função principal para carregar as dependências
async function loadDependencies() {
  try {
    const response = await fetch(jsonPath + '?v=' + Date.now());
    if (!response.ok) {
      throw new Error('Falha ao carregar o arquivo JSON');
    }
    const data = await response.json();
    if (Array.isArray(data)) {
      allDependencies = data;
    } else if (data.dependencies) {
      allDependencies = [data];
    } else {
      throw new Error('Formato de dados inválido');
    }
    initializeFilters();
    renderDependencies();
    setupEventListeners();
  } catch (error) {
    dependenciesGrid.innerHTML = `<div class="error">Erro ao carregar dependências: ${error.message}</div>`;
    console.error('Erro:', error);
  }
}
function initializeFilters() {
  // Coletar todos os projetos e suas combinações
  window._allProjects = allDependencies;
  
  // Filtrar projetos que não têm dependências
  window._allProjects = window._allProjects.filter(p => p.dependencies && p.dependencies.length > 0);
  
  // Inicializar os dropdowns com as opções válidas
  updateAllDropdowns();
  
  // Debug: exibir relações entre filtros no console
  debugFilterRelationships();
}

function updateAllDropdowns() {
  // Filtros ativos
  const selected = {
    java: document.getElementById('filter-java').value || null,
    kotlin: document.getElementById('filter-kotlin').value || null,
    gradle: document.getElementById('filter-gradle').value || null,
    spring_boot: document.getElementById('filter-spring').value || null
  };
  
  console.log("Atualizando dropdowns com seleções:", selected);
  
  // Filtrar projetos com base nas seleções atuais
  let filteredProjects = [...window._allProjects].filter(p => p.dependencies && p.dependencies.length > 0);
  
  // Aplicar os filtros selecionados
  Object.entries(selected).forEach(([key, value]) => {
    if (value) {
      console.log(`Aplicando filtro: ${key} = ${value}`);
      
      // Tratamento especial para o valor "Nenhum" do Kotlin
      if (key === 'kotlin' && value === 'Nenhum') {
        filteredProjects = filteredProjects.filter(p => 
          p.requirements && (p.requirements[key] === null || p.requirements[key] === undefined)
        );
      } else {
        filteredProjects = filteredProjects.filter(p => 
          p.requirements && p.requirements[key] === value
        );
      }
    }
  });
  
  console.log(`Após filtragem: ${filteredProjects.length} projetos correspondem aos filtros`);
  
  // Obter as opções compatíveis para cada filtro com base nos projetos filtrados
  const compatibleOptions = {
    java: getUnique(filteredProjects, 'java'),
    kotlin: getUnique(filteredProjects, 'kotlin'),
    gradle: getUnique(filteredProjects, 'gradle'),
    spring_boot: getUnique(filteredProjects, 'spring_boot')
  };
  
  console.log("Opções compatíveis:", compatibleOptions);
  
  // Atualizar cada dropdown com as opções compatíveis
  // Agora, para cada dropdown, vamos mostrar apenas as opções compatíveis com as seleções atuais
  // mesmo para dropdowns que já têm uma seleção
  
  // Para cada tipo de filtro, precisamos simular como seria o filtro se removêssemos este filtro,
  // mas mantendo os outros filtros ativos
  
  // Atualizar Java dropdown - sempre mostrar opções compatíveis com outros filtros
  const javaCompatibleOptions = getCompatibleOptions('java', selected);
  fillDropdown('filter-java', javaCompatibleOptions, selected.java);
  
  // Atualizar Gradle dropdown - sempre mostrar opções compatíveis com outros filtros
  const gradleCompatibleOptions = getCompatibleOptions('gradle', selected);
  fillDropdown('filter-gradle', gradleCompatibleOptions, selected.gradle);
  
  // Atualizar Kotlin dropdown - sempre mostrar opções compatíveis com outros filtros
  const kotlinCompatibleOptions = getCompatibleOptions('kotlin', selected);
  fillDropdown('filter-kotlin', kotlinCompatibleOptions, selected.kotlin);
  
  // Atualizar Spring Boot dropdown - sempre mostrar opções compatíveis com outros filtros
  const springBootCompatibleOptions = getCompatibleOptions('spring_boot', selected);
  fillDropdown('filter-spring', springBootCompatibleOptions, selected.spring_boot);
}
// Função para debug - imprime no console os filtros relacionados
function debugFilterRelationships() {
  console.log("%c=== Análise de Relações entre Filtros ===", "font-weight:bold; color:blue;");
  
  // Dados de cada projeto
  console.log("%cDados dos projetos carregados:", "font-weight:bold");
  window._allProjects.forEach(p => {
    console.log(`Projeto: ${p.project}, Java: ${p.requirements.java}, Gradle: ${p.requirements.gradle}, Kotlin: ${p.requirements.kotlin}, Spring: ${p.requirements.spring_boot}`);
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
  // Cria uma cópia das seleções atuais, mas remove a seleção do filtro que estamos atualizando
  const simulatedSelections = {...currentSelections};
  simulatedSelections[filterToUpdate] = null;
  
  // Filtra projetos com base nas seleções simuladas (todos os filtros exceto o que estamos atualizando)
  let filteredProjects = [...window._allProjects].filter(p => p.dependencies && p.dependencies.length > 0);
  
  // Aplica os filtros das seleções simuladas
  Object.entries(simulatedSelections).forEach(([key, value]) => {
    if (value) {
      // Tratamento especial para o valor "Nenhum" do Kotlin
      if (key === 'kotlin' && value === 'Nenhum') {
        filteredProjects = filteredProjects.filter(p => 
          p.requirements && (p.requirements[key] === null || p.requirements[key] === undefined)
        );
      } else {
        filteredProjects = filteredProjects.filter(p => 
          p.requirements && p.requirements[key] === value
        );
      }
    }
  });
  
  // Agora obtemos os valores únicos para o filtro que estamos atualizando
  const compatibleOptions = getUnique(filteredProjects, filterToUpdate);
  
  // Log de depuração para mostrar opções compatíveis
  console.log(`Opções compatíveis para ${filterToUpdate}: ${compatibleOptions.join(', ') || 'nenhuma'}`);
  
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
  
  // Resetar todos os dropdowns manualmente
  document.getElementById('filter-java').value = '';
  document.getElementById('filter-kotlin').value = '';
  document.getElementById('filter-gradle').value = '';
  document.getElementById('filter-spring').value = '';
  
  // Atualizar todos os dropdowns para mostrar todas as opções válidas
  updateAllDropdowns();
  
  // Limpar campo de busca
  searchInput.value = '';
  searchTerm = '';
  
  // Resetar todos os dropdowns
  ['java', 'kotlin', 'gradle', 'spring'].forEach(type => {
    const dropdown = document.getElementById('filter-' + type);
    if (dropdown) {
      dropdown.value = '';
    }
  });
  
  // Mostrar todas as opções disponíveis nos dropdowns
  fillDropdown('filter-java', getUnique(window._allProjects, 'java'), null);
  fillDropdown('filter-kotlin', getUnique(window._allProjects, 'kotlin'), null);
  fillDropdown('filter-gradle', getUnique(window._allProjects, 'gradle'), null);
  fillDropdown('filter-spring', getUnique(window._allProjects, 'spring_boot'), null);
  
  // Renderizar todas as dependências
  renderDependencies();
  
  console.log("Filtros limpos com sucesso");
}

function setupEventListeners() {
  // Dropdowns
  ['java','kotlin','gradle','spring'].forEach(type => {
    document.getElementById('filter-' + type).addEventListener('change', e => {
      const filterKey = type === 'spring' ? 'spring_boot' : type;
      activeFilters[filterKey] = e.target.value || null;
      
      // Atualizar os dropdowns para refletir as opções compatíveis
      // Esta função agora filtra bidirecionalmente todos os dropdowns
      updateAllDropdowns();
      
      // Renderizar dependências com os novos filtros
      renderDependencies();
      
      console.log(`Filtro ${filterKey} alterado para: ${activeFilters[filterKey]}`);
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
    
    // Sem formatação especial para variáveis, já que não temos mais essa informação
    const versionClass = 'version';
    
    card.innerHTML = `
      <div class="dependency-group">${dep.group}</div>
      <div class="dependency-name">${dep.name}</div>
      <div class="dependency-version">
        <span class="${versionClass}">${dep.version}</span>
        <button class="copy-button" data-declaration="${escapeHTML(copyDeclaration)}">
          <svg class="icon" viewBox="0 0 24 24">
            <path d="M8 4V16C8 17.1 8.9 18 10 18H18C19.1 18 20 17.1 20 16V7.4L16.6 4H10C8.9 4 8 4.9 8 6"></path>
            <path d="M16 4V8H20"></path>
            <path d="M4 8V18C4 19.1 4.9 20 6 20H14"></path>
          </svg>
        </button>
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
  // Coletar todas as dependências de todos os projetos
  let allDeps = [];
  let anyFilterActive = Object.values(activeFilters).some(v => v);
  // Usar window._allProjects que já foi filtrado para conter apenas projetos com dependências
  const projects = window._allProjects;
  
  projects.forEach(project => {
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
        } else if (project.requirements && project.requirements[filterType] !== filterValue) {
          passesFilters = false;
          break;
        }
      }
    }
    if (passesFilters && project.dependencies) {
      allDeps = allDeps.concat(project.dependencies);
    }
  });
  
  // Se nenhum filtro estiver ativo, mostrar todas as dependências de todos os projetos
  if (!anyFilterActive) {
    allDeps = [];
    projects.forEach(project => {
      if (project.dependencies) allDeps = allDeps.concat(project.dependencies);
    });
  }
  // Corrige: filtrar dependências válidas (com group e name)
  allDeps = allDeps.filter(dep => dep && dep.group && dep.name);
  // Aplicar filtro de busca
  if (searchTerm) {
    allDeps = allDeps.filter(dep => 
      dep.name.toLowerCase().includes(searchTerm) || 
      dep.group.toLowerCase().includes(searchTerm)
    );
  }
  return allDeps;
}
// Inicializar a aplicação
loadDependencies();
