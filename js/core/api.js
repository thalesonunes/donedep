/**
 * DoneDep - API e Comunicação
 * Funções para comunicação com o backend e carregamento de dados
 */

// Usando objetos e funções expostos globalmente

let cache = new Map();

/**
 * Remove comentários e faz parse do JSON
 * @param {string} jsonString - String JSON com possíveis comentários
 * @returns {Object} - Objeto JavaScript parseado
 */
function parseJsonWithCommentRemoval(text) {
  try {
    // Remover possíveis comentários que podem estar no arquivo JSON
    const jsonTextWithoutComments = text
      .split('\n')
      .filter(line => !line.trim().startsWith('//'))
      .join('\n');
    
    return JSON.parse(jsonTextWithoutComments);
  } catch (error) {
    window.logError({
      message: `Erro ao analisar JSON: ${error.message}`,
      type: window.ErrorType.PARSE,
      level: window.ErrorLevel.ERROR,
      originalError: error,
      context: { textPreview: text.substring(0, 100) + '...' }
    });
    throw error;
  }
}

/**
 * Fetch com retry automático
 * @param {string} url - URL para fazer fetch
 * @param {number} attempts - Número de tentativas
 * @returns {Promise<Response>} - Response do fetch
 */
async function fetchWithRetry(url, attempts = window.Config.API.RETRY_ATTEMPTS) {
  for (let i = 0; i < attempts; i++) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return response;
      }
    } catch (error) {
      if (i === attempts - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, window.Config.API.RETRY_DELAY));
    }
  }
  throw new Error('Failed after retry attempts');
}

/**
 * Carrega e valida as dependências
 * @param {string} jsonPath - Caminho do arquivo JSON
 * @returns {Promise<Array>} - Array de dependências
 */
async function loadDependencies(jsonPath) {
  try {
    console.log('Iniciando carregamento de dependências de:', jsonPath);
    
    // Verificar cache primeiro
    const cached = cache.get(jsonPath);
    if (cached && (Date.now() - cached.timestamp < window.Config.API.CACHE_TIMEOUT)) {
      console.log('Usando dados em cache');
      return cached.data;
    }
    
    const response = await fetchWithRetry(jsonPath + '?v=' + Date.now());
    
    if (!response.ok) {
      throw new Error(`Erro HTTP: ${response.status} ${response.statusText}`);
    }
    
    const text = await response.text();
    const data = parseJsonWithCommentRemoval(text);
    
    // Verificar erro do adaptador
    if (data && data.error === true) {
      window.logError({
        message: data.message || 'Erro ao processar dependências',
        type: window.ErrorType.DATA_LOAD,
        level: window.ErrorLevel.ERROR,
        context: { details: data }
      });
      throw new Error(data.message || 'Erro ao processar dependências');
    }
    
    // Validar e processar dados
    let processedData;
    if (Array.isArray(data)) {
      processedData = data;
      console.log(`Carregados ${data.length} projetos com sucesso`);
    } else if (data && typeof data === 'object' && data.dependencies) {
      processedData = [data];
      console.log('Carregado 1 projeto com sucesso (formato objeto)');
    } else {
      throw new Error('Formato de dados inválido');
    }
    
    // Atualizar cache
    cache.set(jsonPath, {
      data: processedData,
      timestamp: Date.now()
    });
    
    return processedData;
  } catch (error) {
    // Registrar erro detalhado
    const errorId = window.logError({
      message: `Falha ao carregar dependências: ${error.message}`,
      type: window.ErrorType.DATA_LOAD,
      level: window.ErrorLevel.ERROR,
      originalError: error
    });
    
    const enhancedError = new Error(`Falha ao carregar dependências: ${error.message}`);
    enhancedError.id = errorId;
    enhancedError.suggestion = 'Verifique se o arquivo de dados existe e é acessível';
    throw enhancedError;
  }
}

/**
 * Valida a estrutura de um projeto
 * @param {Object} project - Projeto a validar
 * @returns {Object} - Projeto validado e normalizado
 */
function validateProject(project) {
  if (!project) {
    throw new Error('Projeto inválido: null ou undefined');
  }
  
  // Validar campos essenciais
  const validProject = {
    project: project.project || "Projeto sem nome",
    ...project
  };
  
  // Garantir objeto requirements
  if (!validProject.requirements) {
    validProject.requirements = {
      java: project.javaVersion || null,
      kotlin: project.kotlinVersion || null,
      gradle: project.gradleVersion || null,
      spring_boot: project.springBootVersion || null
    };
  }
  
  // Validar dependências
  if (!validProject.dependencies) {
    validProject.dependencies = [];
  } else if (!Array.isArray(validProject.dependencies)) {
    window.logError({
      message: `Projeto ${validProject.project} tem dependências em formato inválido`,
      type: window.ErrorType.VALIDATION,
      level: window.ErrorLevel.WARNING,
      context: { projectName: validProject.project, dependencies: validProject.dependencies }
    });
    validProject.dependencies = [];
  }
  
  return validProject;
}

// Exportar para compatibilidade com código existente
window.api = {
  loadDependencies,
  parseJsonWithCommentRemoval,
  validateProject
};
