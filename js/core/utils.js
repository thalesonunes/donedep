/**
 * DoneDep - Utilitários Gerais
 * Funções utilitárias reutilizáveis em toda a aplicação
 */

/**
 * Compara versões semânticas (x.y.z)
 * @param {string|number} a - Primeira versão a comparar
 * @param {string|number} b - Segunda versão a comparar
 * @returns {number} - Negativo se a < b, positivo se a > b, 0 se iguais
 */
function compareVersions(a, b) {
  if (a === b) return 0;
  
  // Se um dos valores é "Nenhum", ele vem por último
  if (a === 'Nenhum') return 1;
  if (b === 'Nenhum') return -1;
  
  // Para versões semânticas (x.y.z), comparar cada parte
  const aParts = a.toString().split('.').map(Number);
  const bParts = b.toString().split('.').map(Number);
  
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
 * Normaliza versões Java (converte 1.8 para 8)
 * @param {string} version - Versão Java a ser normalizada
 * @returns {string|number} - Versão normalizada
 */
function normalizeJavaVersion(version) {
  if (typeof version === 'string' && version.startsWith('1.')) {
    const majorVersion = version.substring(2);
    if (!isNaN(parseInt(majorVersion))) {
      return parseInt(majorVersion);
    }
  } 
  // Formato "8" -> retorna 8 como número
  else if (!isNaN(parseInt(version))) {
    return parseInt(version);
  }
  // Fallback: retorna o valor original
  return version;
}

/**
 * Escapa caracteres HTML especiais para evitar XSS
 * @param {string} str - String a ser escapada
 * @returns {string} - String com caracteres especiais escapados
 */
function escapeHTML(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/**
 * Extrai valores únicos de um array de objetos com base em uma propriedade
 * @param {Array} items - Array de objetos
 * @param {string} key - Chave a ser usada para extração
 * @returns {Array} - Array de valores únicos
 */
function getUniqueValues(items, key) {
  if (!Array.isArray(items) || items.length === 0) {
    return [];
  }
  
  const values = new Set();
  
  items.forEach(item => {
    if (item && item[key] !== undefined) {
      values.add(item[key]);
    }
  });
  
  return Array.from(values).filter(Boolean);
}

/**
 * Aplica uma espera antes de executar uma função (debounce)
 * @param {Function} func - Função a ser executada após o delay
 * @param {number} delay - Tempo de espera em ms
 * @returns {Function} - Função com debounce aplicado
 */
function debounce(func, delay = 300) {
  let timeout;
  
  return function(...args) {
    clearTimeout(timeout);
    timeout = setTimeout(() => {
      func.apply(this, args);
    }, delay);
  };
}

/**
 * Extrai valores únicos de uma lista de projetos baseados em requirements
 * @param {Array} projects - Lista de projetos
 * @param {string} key - Chave do requirement a extrair (java, kotlin, etc)
 * @returns {Array} - Valores únicos ordenados
 */
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
  
  // Tratamento especial para Kotlin - incluir valores null como "Nenhum"
  if (key === 'kotlin') {
    const values = projects.map(p => {
      const value = safeGetRequirement(p, key);
      // Se o valor for null ou undefined e estivermos buscando por Kotlin, retornamos um valor especial
      if (value === null || value === undefined) {
        return window.Config.FILTERS.NONE_LABEL;
      }
      return value;
    });
    return Array.from(new Set(values.filter(v => v !== undefined))).sort(compareVersions);
  }
  
  // Tratamento especial para Spring Boot - incluir valores "NENHUM", null ou undefined como "Nenhum"
  if (key === 'spring_boot') {
    const values = projects.map(p => {
      const value = safeGetRequirement(p, key);
      // Se o valor for "NENHUM", null ou undefined, convertemos para "Nenhum" para exibição
      if (value === 'NENHUM' || value === null || value === undefined) {
        return window.Config.FILTERS.NONE_LABEL;
      }
      return value;
    });
    return Array.from(new Set(values.filter(v => v !== undefined))).sort(compareVersions);
  }
  
  // Para outros campos, apenas extraímos valores únicos não nulos e ordenamos por versão
  return Array.from(new Set(projects.map(p => safeGetRequirement(p, key)).filter(Boolean))).sort(compareVersions);
}

// Exportar para compatibilidade com código existente
window.utils = {
  compareVersions,
  normalizeJavaVersion,
  escapeHTML,
  getUniqueValues,
  debounce,
  getUnique
};

// Expor globalmente também para acesso direto
window.compareVersions = compareVersions;
window.normalizeJavaVersion = normalizeJavaVersion;
window.escapeHTML = escapeHTML;
window.getUniqueValues = getUniqueValues;
window.debounce = debounce;
window.getUnique = getUnique;
