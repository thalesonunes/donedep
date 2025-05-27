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
    console.log('Iniciando carregamento de dependências de:', jsonPath, 'em', Date.now());
    
    // Limpar cache ao mudar de arquivo para evitar inconsistências
    cache.clear();
    console.log('Cache limpo para evitar dados inconsistentes');
    
    // Adicionar um parâmetro de timestamp para garantir que não seja usado o cache do navegador
    const urlWithCache = `${jsonPath}?v=${Date.now()}&nocache=${Math.random()}`;
    const response = await fetchWithRetry(urlWithCache);
    
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
      // Filtrar itens vazios ou inválidos
      processedData = data.filter(item => item && typeof item === 'object');
      console.log(`Carregados ${processedData.length} projetos com sucesso (de ${data.length} totais)`);
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
  
  // Verificar se é um objeto vazio
  if (Object.keys(project).length === 0) {
    throw new Error('Projeto inválido: objeto vazio');
  }
  
  // Criar uma cópia profunda para garantir que não há referências compartilhadas
  const validProject = JSON.parse(JSON.stringify({
    project: project.project || "Projeto sem nome",
  }));
  
  // Copiar as propriedades existentes
  Object.keys(project).forEach(key => {
    // Não copiar diretamente arrays ou objetos para evitar referências compartilhadas
    if (key !== 'dependencies' && key !== 'requirements') {
      validProject[key] = project[key];
    }
  });
  
  // Garantir objeto requirements
  if (!project.requirements || typeof project.requirements !== 'object') {
    validProject.requirements = {
      java: project.javaVersion || null,
      kotlin: project.kotlinVersion || null,
      gradle: project.gradleVersion || null,
      spring_boot: project.springBootVersion || null
    };
  } else {
    // Clone requirements para evitar compartilhar referência
    validProject.requirements = { ...project.requirements };
  }
  
  // Tratar versão "NENHUM" como null para padronizar
  if (validProject.requirements.java === "NENHUM") validProject.requirements.java = null;
  if (validProject.requirements.kotlin === "NENHUM") validProject.requirements.kotlin = null;
  if (validProject.requirements.gradle === "NENHUM") validProject.requirements.gradle = null;
  if (validProject.requirements.spring_boot === "NENHUM") validProject.requirements.spring_boot = null;
  
  // Validar dependências
  if (!project.dependencies) {
    validProject.dependencies = [];
  } else if (!Array.isArray(project.dependencies)) {
    window.logError({
      message: `Projeto ${validProject.project} tem dependências em formato inválido`,
      type: window.ErrorType.VALIDATION,
      level: window.ErrorLevel.WARNING,
      context: { projectName: validProject.project }
    });
    validProject.dependencies = [];
  } else {
    // Filtrar dependências inválidas e criar novo array
    validProject.dependencies = project.dependencies
      .filter(dep => dep && typeof dep === 'object' && Object.keys(dep).length > 0)
      .map(dep => {
        // Criar nova instância de cada dependência
        const validDep = { ...dep };
        if (!validDep.name) validDep.name = "Indefinido";
        if (!validDep.group) validDep.group = "Indefinido";
        if (!validDep.version) validDep.version = "0.0.0";
        
        // Garantir que projects também é um novo array
        if (validDep.projects && Array.isArray(validDep.projects)) {
          validDep.projects = [...validDep.projects];
        } else {
          validDep.projects = [];
        }
        
        return validDep;
      });
  }
  
  return validProject;
}

/**
 * Lista todos os arquivos de dependências disponíveis
 * @returns {Promise<Array>} - Lista de arquivos disponíveis com timestamps
 */
async function listDependencyFiles() {
  console.log('🔍 [listDependencyFiles] Iniciando...');
  console.log('🔍 [listDependencyFiles] DEPENDENCIES_HISTORY_ENABLED:', window.Config.DEPENDENCIES_HISTORY_ENABLED);
  
  if (!window.Config.DEPENDENCIES_HISTORY_ENABLED) {
    console.log('🔍 [listDependencyFiles] Histórico desabilitado, retornando arquivo padrão');
    return [{ path: window.Config.DEPENDENCIES_JSON_PATH }];
  }

  try {
    console.log('🔍 [listDependencyFiles] Carregando lista de arquivos reais de dependências...');
    
    // Primeiro, tentar carregar a lista de arquivos gerada pelo script
    try {
      console.log('🔍 [listDependencyFiles] Tentando carregar dependency-files-list.json...');
      const listResponse = await fetch('data/dependency-files-list.json');
      
      if (listResponse.ok) {
        const filesList = await listResponse.json();
        console.log('🔍 [listDependencyFiles] Lista carregada:', filesList);
        
        if (Array.isArray(filesList) && filesList.length > 0) {
          // Validar que os arquivos ainda existem
          const validFiles = [];
          
          for (const fileInfo of filesList) {
            try {
              const response = await fetch(fileInfo.path, { method: 'HEAD' });
              if (response.ok) {
                // Criar nome mais amigável baseado no timestamp
                let displayName = fileInfo.name;
                if (fileInfo.date) {
                  displayName = fileInfo.date;
                }
                
                validFiles.push({
                  path: fileInfo.path,
                  name: displayName,
                  date: fileInfo.date || new Date().toISOString().substring(0, 19).replace('T', ' '),
                  originalName: fileInfo.name,
                  timestamp: fileInfo.date
                });
                console.log(`✅ [listDependencyFiles] Arquivo validado: ${fileInfo.name}`);
              } else {
                console.warn(`⚠️ [listDependencyFiles] Arquivo listado mas não encontrado: ${fileInfo.path}`);
              }
            } catch (err) {
              console.warn(`⚠️ [listDependencyFiles] Erro ao validar ${fileInfo.path}:`, err.message);
            }
          }
          
          if (validFiles.length > 0) {
            // Ordenar por timestamp (mais recente primeiro)
            validFiles.sort((a, b) => {
              if (a.timestamp && b.timestamp) {
                return new Date(b.timestamp) - new Date(a.timestamp);
              }
              return 0;
            });
            
            console.log(`🎉 [listDependencyFiles] ${validFiles.length} arquivos reais encontrados`);
            return validFiles;
          }
        }
      }
    } catch (err) {
      console.warn('⚠️ [listDependencyFiles] Erro ao carregar dependency-files-list.json:', err.message);
    }
    
    // Fallback: buscar arquivos automaticamente por padrão de timestamp
    console.log('🔍 [listDependencyFiles] Fallback: Buscando arquivos por padrão de timestamp...');
    const files = [];
    
    // Buscar arquivos com timestamp (formato: dependencies_YYYYMMDD_HHMMSS.json)
    try {
      const today = new Date();
      
      // Verificar últimos 30 dias para encontrar arquivos gerados por extração
      for (let day = 0; day < 30; day++) {
        const currentDate = new Date(today);
        currentDate.setDate(today.getDate() - day);
        
        const year = currentDate.getFullYear();
        const month = String(currentDate.getMonth() + 1).padStart(2, '0');
        const date = String(currentDate.getDate()).padStart(2, '0');
        
        // Verificar algumas horas estratégicas do dia
        for (const hour of [0, 6, 12, 18, 23]) {
          for (const minute of [0, 30]) {
            const hourStr = String(hour).padStart(2, '0');
            const minuteStr = String(minute).padStart(2, '0');
            
            const filename = `dependencies_${year}${month}${date}_${hourStr}${minuteStr}00.json`;
            const path = `data/${filename}`;
            
            try {
              const response = await fetch(path, { method: 'HEAD' });
              if (response.ok) {
                files.push({
                  path: path,
                  name: `${year}-${month}-${date} ${hourStr}:${minuteStr}:00`,
                  date: `${year}-${month}-${date} ${hourStr}:${minuteStr}:00`,
                  originalName: filename,
                  timestamp: `${year}-${month}-${date} ${hourStr}:${minuteStr}:00`
                });
                console.log(`✅ [listDependencyFiles] Arquivo com timestamp encontrado: ${filename}`);
              }
            } catch (err) {
              // Ignorar arquivos não encontrados
            }
          }
        }
      }
    } catch (error) {
      console.warn('⚠️ [listDependencyFiles] Erro ao buscar arquivos de extração:', error);
    }
    
    if (files.length > 0) {
      // Ordenar por timestamp (mais recente primeiro)
      files.sort((a, b) => {
        if (a.timestamp && b.timestamp) {
          return new Date(b.timestamp) - new Date(a.timestamp);
        }
        return 0;
      });
      
      console.log(`🎉 [listDependencyFiles] ${files.length} arquivos encontrados`);
      return files;
    }
    
    // Se nenhum arquivo foi encontrado, retornar lista vazia indicando que não há histórico
    console.warn('⚠️ [listDependencyFiles] Nenhum arquivo de dependências encontrado');
    return [{
      path: 'data/dependencies.json',
      name: 'Sem arquivos de histórico disponíveis',
      date: new Date().toISOString().substring(0, 19).replace('T', ' ')
    }];
    
  } catch (error) {
    console.error('❌ [listDependencyFiles] Erro ao carregar arquivos:', error);
    return [{
      path: 'data/dependencies.json',
      name: 'Erro ao carregar histórico',
      date: new Date().toISOString().substring(0, 19).replace('T', ' ')
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
