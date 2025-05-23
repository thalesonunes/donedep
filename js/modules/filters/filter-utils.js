/**
 * DoneDep - Utilitários de Filtros
 * Funções auxiliares para manipulação e validação de filtros
 */

// Usando objetos e funções expostos globalmente

/**
 * Valida um valor de filtro para um tipo específico
 * @param {string} filterType - Tipo de filtro (java, kotlin, gradle, spring_boot)
 * @param {string} value - Valor a ser validado
 * @returns {boolean} - true se válido, false caso contrário
 */
function validateFilterValue(filterType, value) {
    if (!value) return true; // Valores vazios são válidos (significa "todos")
    
    try {
        switch (filterType) {
            case 'java':
                // Aceitar formatos: "1.8", "8", "11", "17"
                if (value.startsWith('1.')) {
                    const majorVersion = parseInt(value.substring(2));
                    return !isNaN(majorVersion) && majorVersion >= 8;
                }
                const version = parseInt(value);
                return !isNaN(version) && version >= 8;
                
            case 'kotlin':
                // Aceitar "Nenhum" ou versão semântica
                if (value === CONFIG.FILTERS.NONE_LABEL) return true;
                return /^\d+\.\d+(\.\d+)?$/.test(value);
                
            case 'gradle':
                // Aceitar versão semântica
                return /^\d+\.\d+(\.\d+)?$/.test(value);
                
            case 'spring_boot':
                // Aceitar versão semântica
                return /^\d+\.\d+\.\d+$/.test(value);
                
            default:
                logError({
                    message: `Tipo de filtro desconhecido: ${filterType}`,
                    type: ErrorType.VALIDATION,
                    level: ErrorLevel.WARNING,
                    context: { filterType, value }
                });
                return false;
        }
    } catch (error) {
        logError({
            message: `Erro ao validar valor de filtro: ${error.message}`,
            type: ErrorType.VALIDATION,
            level: ErrorLevel.WARNING,
            originalError: error,
            context: { filterType, value }
        });
        return false;
    }
}

/**
 * Normaliza um valor de filtro para um formato consistente
 * @param {string} filterType - Tipo de filtro
 * @param {string} value - Valor a ser normalizado
 * @returns {string} - Valor normalizado
 */
function normalizeFilterValue(filterType, value) {
    if (!value) return null;
    
    try {
        switch (filterType) {
            case 'java':
                return normalizeJavaVersion(value).toString();
                
            case 'kotlin':
                return value === 'null' ? CONFIG.FILTERS.NONE_LABEL : value;
                
            default:
                return value;
        }
    } catch (error) {
        logError({
            message: `Erro ao normalizar valor de filtro: ${error.message}`,
            type: ErrorType.VALIDATION,
            level: ErrorLevel.WARNING,
            originalError: error,
            context: { filterType, value }
        });
        return value;
    }
}

/**
 * Obtém o label de exibição para um valor de filtro
 * @param {string} filterType - Tipo de filtro
 * @param {string} value - Valor do filtro
 * @returns {string} - Label para exibição
 */
function getFilterDisplayLabel(filterType, value) {
    if (!value) return 'Todos';
    
    try {
        switch (filterType) {
            case 'java':
                const normalized = normalizeJavaVersion(value);
                return `Java ${normalized}`;
                
            case 'kotlin':
                return value === CONFIG.FILTERS.NONE_LABEL ? 'Sem Kotlin' : `Kotlin ${value}`;
                
            case 'gradle':
                return `Gradle ${value}`;
                
            case 'spring_boot':
                return `Spring Boot ${value}`;
                
            default:
                return value;
        }
    } catch (error) {
        logError({
            message: `Erro ao gerar label de filtro: ${error.message}`,
            type: ErrorType.RENDER,
            level: ErrorLevel.WARNING,
            originalError: error,
            context: { filterType, value }
        });
        return value;
    }
}

/**
 * Compara valores de filtro para ordenação
 * @param {string} filterType - Tipo de filtro
 * @param {string} a - Primeiro valor
 * @param {string} b - Segundo valor
 * @returns {number} - Resultado da comparação (-1, 0, 1)
 */
function compareFilterValues(filterType, a, b) {
    try {
        // Tratar casos especiais primeiro
        if (a === b) return 0;
        if (!a) return -1; // Valores vazios vêm primeiro
        if (!b) return 1;
        
        switch (filterType) {
            case 'java':
                const aNorm = normalizeJavaVersion(a);
                const bNorm = normalizeJavaVersion(b);
                return parseInt(aNorm) - parseInt(bNorm);
                
            case 'kotlin':
                if (a === CONFIG.FILTERS.NONE_LABEL) return 1;
                if (b === CONFIG.FILTERS.NONE_LABEL) return -1;
                return compareVersions(a, b);
                
            default:
                return compareVersions(a, b);
        }
    } catch (error) {
        logError({
            message: `Erro ao comparar valores de filtro: ${error.message}`,
            type: ErrorType.VALIDATION,
            level: ErrorLevel.WARNING,
            originalError: error,
            context: { filterType, a, b }
        });
        return 0;
    }
}

/**
 * Verifica se dois filtros são compatíveis entre si
 * @param {string} filterType1 - Primeiro tipo de filtro
 * @param {string} value1 - Valor do primeiro filtro
 * @param {string} filterType2 - Segundo tipo de filtro
 * @param {string} value2 - Valor do segundo filtro
 * @returns {boolean} - true se compatíveis, false caso contrário
 */
function areFiltersCompatible(filterType1, value1, filterType2, value2) {
    // Se algum dos valores é nulo, são compatíveis
    if (!value1 || !value2) return true;
    
    try {
        // Regras específicas de compatibilidade
        if (filterType1 === 'java' && filterType2 === 'kotlin') {
            // Java 8 não é compatível com Kotlin
            if (normalizeJavaVersion(value1) === '8' && value2 !== CONFIG.FILTERS.NONE_LABEL) {
                return false;
            }
        }
        
        if (filterType1 === 'spring_boot' && filterType2 === 'java') {
            // Spring Boot 3.x requer Java 17+
            if (value1.startsWith('3') && parseInt(normalizeJavaVersion(value2)) < 17) {
                return false;
            }
        }
        
        return true;
    } catch (error) {
        logError({
            message: `Erro ao verificar compatibilidade de filtros: ${error.message}`,
            type: ErrorType.VALIDATION,
            level: ErrorLevel.WARNING,
            originalError: error,
            context: { filterType1, value1, filterType2, value2 }
        });
        return true; // Em caso de erro, assumir compatível
    }
}

/**
 * Classe FilterUtils - Utilitários para manipulação de filtros
 */
class FilterUtils {
  /**
   * Compara duas versões semânticas ou valores especiais como "Nenhum"
   * @param {string} a - Primeira versão
   * @param {string} b - Segunda versão
   * @returns {number} - Resultado da comparação (-1, 0, 1)
   */
  static compareVersions(a, b) {
    if (a === b) return 0;
    
    // Se um dos valores é "Nenhum", vem por último
    if (a === 'Nenhum') return 1;
    if (b === 'Nenhum') return -1;
    
    // Para versões semânticas (x.y.z), compara cada parte
    const aParts = a.toString().split('.').map(Number);
    const bParts = b.toString().split('.').map(Number);
    
    // Compara cada parte da versão
    for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
      const aVal = aParts[i] || 0;
      const bVal = bParts[i] || 0;
      if (aVal !== bVal) {
        return aVal - bVal;
      }
    }
    return 0;
  }

  /**
   * Obtém valores únicos de um projeto para uma chave específica
   * @param {Array} projects - Lista de projetos
   * @param {string} key - Chave da qual obter os valores
   * @returns {Array} - Valores únicos encontrados
   */
  static getUnique(projects, key) {
    if (!projects || projects.length === 0) {
      return [];
    }
    
    // Função de acesso seguro para obter o valor da requirement com tratamento de erros
    const safeGetRequirement = (project, key) => {
      try {
        if (!project || !project.requirements) {
          return null;
        }
        return project.requirements[key];
      } catch (e) {
        console.error(`Erro ao acessar requirement '${key}' do projeto:`, project, e);
        return null;
      }
    };
    
    // Tratamento especial para Kotlin - inclui valores nulos como "Nenhum"
    if (key === 'kotlin') {
      const values = projects.map(p => {
        const value = safeGetRequirement(p, key);
        if (value === null || value === undefined) {
          return 'Nenhum';
        }
        return value;
      });
      return Array.from(new Set(values.filter(v => v !== undefined))).sort(this.compareVersions);
    }
    
    // Para outros campos, extrai apenas os valores únicos não nulos e ordena pela versão
    return Array.from(new Set(projects.map(p => safeGetRequirement(p, key)).filter(Boolean))).sort(this.compareVersions);
  }

  /**
   * Normaliza a versão do Java para um formato numérico
   * @param {string} version - Versão a ser normalizada
   * @returns {number|string} - Versão normalizada ou valor original em caso de erro
   */
  static normalizeJavaVersion(version) {
    if (typeof version === 'string' && version.startsWith('1.')) {
      const majorVersion = version.substring(2);
      if (!isNaN(parseInt(majorVersion))) {
        return parseInt(majorVersion);
      }
    } 
    // Caso 2: Formato "8" -> retorna 8 como número
    else if (!isNaN(parseInt(version))) {
      return parseInt(version);
    }
    // Padrão: retorna o valor original
    return version;
  }

  /**
   * Analisa e exibe relacionamentos de filtros entre projetos
   * @param {Array} allProjects - Lista de todos os projetos
   */
  static debugFilterRelationships(allProjects) {
    console.log("%c=== Análise de Relacionamento de Filtros ===", "font-weight:bold; color:blue;");
    
    // Dados dos projetos
    console.log("%cProjetos carregados:", "font-weight:bold");
    allProjects.forEach(p => {
      try {
        if (p && p.requirements) {
          console.log(`Projeto: ${p.project || 'Sem Nome'}, Java: ${p.requirements.java || 'N/A'}, Gradle: ${p.requirements.gradle || 'N/A'}, Kotlin: ${p.requirements.kotlin || 'N/A'}, Spring: ${p.requirements.spring_boot || 'N/A'}`);
        } else if (p) {
          console.log(`Projeto: ${p.project || 'Sem Nome'}, nenhum requisito definido`);
        } else {
          console.log('Projeto inválido encontrado');
        }
      } catch (e) {
        console.error('Erro ao mostrar info do projeto:', e);
      }
    });
    
    // Verifica quais versões do Gradle existem para cada versão do Java
    console.log("%cVersões do Gradle por versão do Java:", "font-weight:bold");
    const javaVersions = this.getUnique(allProjects, 'java');
    
    javaVersions.forEach(javaVersion => {
      const filteredProjects = allProjects.filter(
        p => p.requirements && p.requirements.java === javaVersion
      );
      const gradleVersions = this.getUnique(filteredProjects, 'gradle');
      console.log(`Java ${javaVersion}: Gradle ${gradleVersions.join(', ')}`);
      
      // Lista projetos com essa combinação
      const projectNames = filteredProjects.map(p => p.project).join(", ");
      console.log(`  Projetos com Java ${javaVersion}: ${projectNames}`);
    });
    
    // Verifica quais versões do Spring Boot existem para cada versão do Java
    console.log("%cVersões do Spring Boot por versão do Java:", "font-weight:bold");
    javaVersions.forEach(javaVersion => {
      const filteredProjects = allProjects.filter(
        p => p.requirements && p.requirements.java === javaVersion
      );
      const springVersions = this.getUnique(filteredProjects, 'spring_boot');
      console.log(`Java ${javaVersion}: Spring Boot ${springVersions.join(', ')}`);
    });
    
    // Verifica quais versões do Kotlin existem para cada versão do Java
    console.log("%cVersões do Kotlin por versão do Java:", "font-weight:bold");
    javaVersions.forEach(javaVersion => {
      const filteredProjects = allProjects.filter(
        p => p.requirements && p.requirements.java === javaVersion
      );
      const kotlinVersions = this.getUnique(filteredProjects, 'kotlin');
      console.log(`Java ${javaVersion}: Kotlin ${kotlinVersions.join(', ')}`);
    });
  }
}

// Exportar para compatibilidade com código existente
window.filterUtils = {
    validateFilterValue,
    normalizeFilterValue,
    getFilterDisplayLabel,
    compareFilterValues,
    areFiltersCompatible
};

// Expor globalmente
window.FilterUtils = FilterUtils;
window.validateFilterValue = validateFilterValue;
window.normalizeFilterValue = normalizeFilterValue;
window.getFilterDisplayLabel = getFilterDisplayLabel;
window.compareFilterValues = compareFilterValues;
window.areFiltersCompatible = areFiltersCompatible;
