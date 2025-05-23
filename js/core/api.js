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

/**
 * Lista todos os arquivos de dependências disponíveis
 * @returns {Promise<Array>} - Lista de arquivos disponíveis com timestamps
 */
async function listDependencyFiles() {
  if (!window.Config.DEPENDENCIES_HISTORY_ENABLED) {
    return [{ path: window.Config.DEPENDENCIES_JSON_PATH, isLatest: true }];
  }

  try {
    // Tentar com o arquivo JSON estático
    // Tentar obter a lista direta dos arquivos na pasta data/
    try {
      const response = await fetch('data/');
      if (response.ok) {
        const files = await response.json();
        return files
          .filter(file => file.name.startsWith('dependencies_') && file.name.endsWith('.json'))
          .map(file => ({
            path: `data/${file.name}`,
            name: file.name,
            date: file.name.slice(13, 21)
          }));
      }
    } catch (error) {
      console.warn('Não foi possível listar os arquivos diretamente:', error.message);
      return [{ path: window.Config.DEPENDENCIES_JSON_PATH }];
    }
    
    // Procurar por arquivos de dependências com padrão de nome
    try {
      // Esta é uma implementação limitada que funciona apenas com servidores que suportam listagem de diretório
      const dirResponse = await fetch('data/');
      
      if (dirResponse.ok) {
        const text = await dirResponse.text();
        const matches = text.match(/dependencies_[0-9_]+\.json/g) || [];
        
        if (matches.length > 0) {
          return matches.map(filename => ({
            path: `data/${filename}`,
            name: filename,
            date: filename.replace('dependencies_', '').replace('.json', '').replace('_', ' ')
          })).concat([{ 
            path: window.Config.DEPENDENCIES_JSON_PATH, 
            name: 'dependencies.json', 
            isLatest: true,
            date: 'Atual (symlink)'
          }]);
        }
      }
    } catch (dirError) {
      console.warn('Erro ao listar diretório:', dirError.message);
    }
    
    // Se todas as tentativas falharem, retornar apenas o arquivo padrão
    console.warn('Não foi possível listar arquivos históricos. Usando arquivo padrão.');
    return [{ 
      path: window.Config.DEPENDENCIES_JSON_PATH, 
      name: 'dependencies.json', 
      isLatest: true,
      date: 'Atual' 
    }];
  } catch (error) {
    console.warn('Erro ao listar arquivos históricos:', error);
    // Em caso de erro, retornar apenas o arquivo padrão
    return [{ 
      path: window.Config.DEPENDENCIES_JSON_PATH, 
      name: 'dependencies.json', 
      isLatest: true,
      date: 'Atual' 
    }];
  }
}

// Exportar para compatibilidade com código existente
window.api = {
  loadDependencies,
  listDependencyFiles,
  parseJsonWithCommentRemoval,
  validateProject
};
