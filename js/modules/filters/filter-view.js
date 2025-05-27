/**
 * DoneDep - Interface dos Filtros
 * Funções para gerenciar a visualização e interação com os filtros
 */

// Usando funções e objetos expostos globalmente

/**
 * Classe FilterView - Responsável pela visualização dos filtros
 */
class FilterView {
  static isUpdatingDropdowns = false; // Add this guard flag

  /**
   * Preenche um dropdown com as opções disponíveis
   * @param {string} id - ID do elemento select
   * @param {Array} values - Valores a serem colocados no dropdown
   * @param {string} selectedValue - Valor atualmente selecionado
   */
  static fillDropdown(id, values, selectedValue) {
    try {
      const select = document.getElementById(id);
      if (!select) {
        window.logError({
          message: `Elemento select não encontrado: ${id}`,
          type: window.ErrorType.RENDER,
          level: window.ErrorLevel.WARNING
        });
        return;
      }
      
      // Verificar se temos valores válidos
      const validValues = Array.isArray(values) ? values : [];
      console.log(`Preenchendo dropdown ${id} com ${validValues.length} valores válidos`);
      
      select.innerHTML = '';
      
      // Se não há valores para mostrar
      if (validValues.length === 0) {
        select.disabled = false; // Deixamos habilitado, mas sem opções
        const optEmpty = document.createElement('option');
        optEmpty.value = '';
        optEmpty.textContent = 'Todas';
        select.appendChild(optEmpty);
        return;
      }
      
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
          
          // REMOVED: const filterKey = id.replace('filter-', '');
          // REMOVED: updateFilter(filterKey, values[0]); // This was causing recursion
          select.disabled = true;
        } else {
          // Se houver múltiplas opções, mostrar todas
          const optAll = document.createElement('option');
          optAll.value = '';
          optAll.textContent = 'Todas';
          select.appendChild(optAll);
          
          // Determinar o tipo de filtro (java, kotlin, etc.) com base no ID
          const filterType = id.replace('filter-', '');
          
          // Adicionar opções ordenadas por versão
          const sortedValues = [...values].sort((a, b) => {
            if (filterType === 'java') {
              const aNormalized = window.normalizeJavaVersion(a);
              const bNormalized = window.normalizeJavaVersion(b);
              if (typeof aNormalized === 'number' && typeof bNormalized === 'number') {
                return aNormalized - bNormalized;
              }
            }
            return window.compareVersions(a, b);
          });
          
          sortedValues.forEach(val => {
            const opt = document.createElement('option');
            opt.value = val;
            opt.textContent = val;
            select.appendChild(opt);
          });
          
          select.disabled = false;
        }
      }
    } catch (error) {
      window.logError({
        message: `Erro ao preencher dropdown ${id}: ${error.message}`,
        type: window.ErrorType.RENDER,
        level: window.ErrorLevel.ERROR,
        originalError: error,
        context: { id, valuesCount: values?.length }
      });
    }
  }

  /**
   * Atualiza todos os dropdowns com base nos filtros atuais
   */
  static updateAllDropdowns() {
    if (FilterView.isUpdatingDropdowns) {
      console.warn("FilterView.updateAllDropdowns called while already updating. Skipping to prevent recursion.");
      return;
    }
    FilterView.isUpdatingDropdowns = true;
    try {
      const selected = window.getActiveFilters();
      console.log("Atualizando dropdowns com seleções:", selected);
      
      // Verificar se os dados são válidos
      if (!window._allProjects || !Array.isArray(window._allProjects) || window._allProjects.length === 0) {
        console.warn("Não há projetos disponíveis para atualizar os dropdowns");
        // Resetar todos os dropdowns para estado vazio
        this.fillDropdown('filter-java', [], null);
        this.fillDropdown('filter-gradle', [], null);
        this.fillDropdown('filter-kotlin', [], null);
        this.fillDropdown('filter-spring', [], null);
        return;
      }
      
      // Obter as opções compatíveis com base nos dados atuais
      console.log("Obtendo opções compatíveis com", window._allProjects.length, "projetos disponíveis");
      const javaCompatibleOptions = window.getCompatibleOptions('java', selected);
      const gradleCompatibleOptions = window.getCompatibleOptions('gradle', selected);
      const kotlinCompatibleOptions = window.getCompatibleOptions('kotlin', selected);
      const springBootCompatibleOptions = window.getCompatibleOptions('spring_boot', selected);
      
      // Preencher os dropdowns com as opções compatíveis
      this.fillDropdown('filter-java', javaCompatibleOptions, selected.java);
      this.fillDropdown('filter-gradle', gradleCompatibleOptions, selected.gradle);
      this.fillDropdown('filter-kotlin', kotlinCompatibleOptions, selected.kotlin);
      this.fillDropdown('filter-spring', springBootCompatibleOptions, selected.spring_boot);

    } catch (error) {
      window.logError({
        message: `Erro ao atualizar dropdowns: ${error.message}`,
        type: window.ErrorType.RENDER,
        level: window.ErrorLevel.ERROR,
        originalError: error
      });
    } finally {
      FilterView.isUpdatingDropdowns = false; // Reset the guard flag
    }
  }

  /**
   * Atualiza um filtro ativo e a UI correspondente
   * @param {string} id - ID do filtro (sem o prefixo 'filter-')
   * @param {string} value - Valor do filtro
   */
  static updateActiveFilter(id, value) {
    const filterKey = id.replace('filter-', '');
    const actualKey = filterKey === 'spring' ? 'spring_boot' : filterKey;
    
    window.updateFilter(actualKey, value || null);
    
    const isValidCombination = window.validateFilterCombination();
    
    if (!isValidCombination) {
      console.warn('Combinação de filtros inválida detectada');
    }
    
    this.updateAllDropdowns();
  }

  /**
   * Limpa todos os filtros e reseta a interface
   */
  static clearAllFilters() {
    console.log("Limpando todos os filtros");
    
    // Verificar se a função resetFilters existe
    if (typeof window.resetFilters === 'function') {
      window.resetFilters();
    } else {
      // Caso a função não exista, resetar manualmente
      window._activeFilters = {
        java: null,
        kotlin: null,
        gradle: null,
        spring_boot: null
      };
    }
    
    // Resetar UI
    ['java', 'kotlin', 'gradle', 'spring'].forEach(type => {
      const dropdown = document.getElementById('filter-' + type);
      if (dropdown) {
        dropdown.value = '';
        dropdown.disabled = false;
      }
    });
    
    // Atualizar dropdowns
    this.updateAllDropdowns();
    
    console.log("Filtros limpos com sucesso");
  }

  /**
   * Configura os event listeners dos filtros
   */
  static setupFilterEventListeners() {
    const clearFiltersButton = document.getElementById('clear-filters-button');
    if (clearFiltersButton) {
      clearFiltersButton.addEventListener('click', () => this.clearAllFilters()); // Ensure 'this' context
    }

    ['java', 'kotlin', 'gradle', 'spring'].forEach(type => {
      const dropdown = document.getElementById('filter-' + type);
      if (dropdown) {
        dropdown.addEventListener('change', (e) => {
          this.updateActiveFilter(type, e.target.value); // Ensure 'this' context
        });
      }
    });
  }

  static showFilterLockedModal() {
    window.showModal('locked-filter-modal', 3000); // Assuming showModal is global
  }
}

// Exportar para compatibilidade com código existente
window.filterView = FilterView;

// Expor classes globalmente
window.FilterView = FilterView;
