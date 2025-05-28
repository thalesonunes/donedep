/**
 * DoneDep - Adaptador de Dados
 * Adapta dados do backend para o formato esperado pelo frontend
 */

console.log('DoneDep Data Adapter carregado');

/**
 * Formata referências a variáveis de forma mais amigável ao usuário
 * @param {string|any} value - Valor a ser formatado
 * @returns {string|any} - Valor formatado ou original
 */
function formatVariableReference(value) {
    // Se não for uma string ou não conter $, retorna o valor original
    if (typeof value !== 'string' || !value.includes('$')) {
        return value;
    }
    
    // Para variáveis no formato ${var}, extrair o nome da variável
    let varName;
    if (value.startsWith('${') && value.endsWith('}')) {
        varName = value.slice(2, -1);
    } else if (value.startsWith('$')) {
        varName = value.substring(1);
    } else if (value.includes('${') && value.includes('}')) {
        // Extração mais complexa: pode ter ${var} em qualquer parte da string
        const match = value.match(/\$\{([^}]+)\}/);
        if (match && match[1]) {
            varName = match[1];
        } else {
            return value; // Não conseguiu extrair o nome da variável
        }
    } else {
        return value; // Não é uma variável no formato esperado
    }
    
    // Marcar a variável como não resolvida para tratamento especial na UI
    return {
        value: value,
        originalVersion: value,
        hasUnresolvedVariable: true,
        variableName: varName
    };
}

/**
 * Transforma os dados do backend para o formato esperado pelo frontend
 * @param {Object} project - Dados do projeto a serem transformados
 * @returns {Object} - Dados transformados
 */
function transformProjectData(project) {
    if (!project) {
        throw new Error('Projeto inválido: null ou undefined');
    }
    
    try {
        // Validar e normalizar o objeto do projeto
        const validProject = {
            project: project.project || "Projeto sem nome",
            kotlinVersion: project.kotlinVersion || null,
            gradleVersion: project.gradleVersion || null,
            mavenVersion: project.mavenVersion || null,
            springBootVersion: project.springBootVersion || null,
            javaVersion: project.javaVersion || null,
            ...project
        };
        
        // Criar objeto requirements
        const requirements = {
            java: validProject.javaVersion || null,
            kotlin: validProject.kotlinVersion || null,
            gradle: validProject.gradleVersion || null,
            maven: validProject.mavenVersion || null,
            spring_boot: validProject.springBootVersion || null
        };
        
        // Processar dependências
        let processedDependencies = [];
        let hasUnresolvedVariables = false;
        
        if (project.dependencies && Array.isArray(project.dependencies)) {
            processedDependencies = project.dependencies
                .filter(dep => dep && dep.group && dep.name)
                .map(dep => {
                    // Verificar se a versão contém variáveis não resolvidas
                    const originalVersion = dep.version;
                    const isVariableVersion = typeof originalVersion === 'string' && 
                        (originalVersion.includes('$') || originalVersion.includes('${'));
                    
                    // Formatar referências a variáveis
                    const formattedVersion = formatVariableReference(originalVersion);
                    
                    // Marcar se ainda temos variáveis não resolvidas
                    if (isVariableVersion && formattedVersion.includes('<Ref:')) {
                        hasUnresolvedVariables = true;
                    }
                    
                    return {
                        group: dep.group,
                        name: dep.name,
                        version: formattedVersion || 'N/A',
                        originalVersion: originalVersion,
                        configuration: dep.configuration || 'implementation',
                        projects: [project.project],
                        hasUnresolvedVariable: isVariableVersion && formattedVersion.includes('<Ref:'),
                        declaration: dep.declaration || 
                            `${dep.configuration || 'implementation'}("${dep.group}:${dep.name}:${formattedVersion || 'N/A'}")`
                    };
                });
        }
        
        // Adicionar informação sobre variáveis não resolvidas
        if (hasUnresolvedVariables) {
            window.errorHandler.logError({
                message: `Projeto ${validProject.project} contém variáveis não resolvidas`,
                type: window.ErrorType.VALIDATION,
                level: window.ErrorLevel.WARNING,
                context: { project: validProject.project }
            });
        }
        
        // Retornar o projeto transformado
        return {
            ...project,
            requirements,
            dependencies: processedDependencies
        };
    } catch (error) {
        window.errorHandler.logError({
            message: `Erro ao transformar dados do projeto: ${error.message}`,
            type: window.ErrorType.DATA_LOAD,
            level: window.ErrorLevel.ERROR,
            originalError: error,
            context: { projectName: project.project || 'unknown' }
        });
        throw error;
    }
}

/**
 * Intercepta e processa respostas da API
 * @param {Response} response - Resposta da fetch API
 * @returns {Promise<Response>} - Resposta processada
 */
async function processApiResponse(response) {
    // Interceptar apenas requisições para o arquivo dependencies.json
    if (!response.url.includes('dependencies.json')) {
        return response;
    }
    
    const clonedResponse = response.clone();
    
    try {
        // Primeiro tentar obter o texto bruto para manipular variáveis não resolvidas
        const rawText = await clonedResponse.text();
        
        // Remover possíveis comentários e fazer parse do JSON
        let data;
        try {
            data = window.api.parseJsonWithCommentRemoval(rawText);
        } catch (parseError) {
            window.errorHandler.logError({
                message: `Erro ao analisar JSON: ${parseError.message}`,
                type: window.ErrorType.PARSE,
                level: window.ErrorLevel.ERROR,
                originalError: parseError,
                context: { textPreview: rawText.substring(0, 100) + '...' }
            });
            
            return new Response(JSON.stringify({
                error: true,
                message: `Erro ao analisar o arquivo JSON: ${parseError.message}`,
                suggestion: 'Verifique a sintaxe do arquivo dependencies.json'
            }), {
                status: 200,
                headers: new Headers({'Content-Type': 'application/json'})
            });
        }
        
        // Verificar se os dados são válidos para processamento
        if (!Array.isArray(data) || data.length === 0) {
            return new Response(JSON.stringify({
                error: true,
                message: 'Formato de dados inválido ou vazio',
                suggestion: 'O arquivo dependencies.json deve conter um array de projetos'
            }), {
                status: 200,
                headers: new Headers({'Content-Type': 'application/json'})
            });
        }
        
        // Transformar os dados para o formato esperado pelo frontend
        const transformedData = data
            .map(project => {
                try {
                    return transformProjectData(project);
                } catch (error) {
                    window.errorHandler.logError({
                        message: `Erro ao processar projeto: ${error.message}`,
                        type: window.ErrorType.DATA_LOAD,
                        level: window.ErrorLevel.WARNING,
                        originalError: error,
                        context: { project }
                    });
                    return null;
                }
            })
            .filter(Boolean);
        
        // Criar resposta com os dados transformados
        return new Response(JSON.stringify(transformedData), {
            status: response.status,
            statusText: response.statusText,
            headers: new Headers({'Content-Type': 'application/json'})
        });
    } catch (error) {
        window.errorHandler.logError({
            message: `Erro ao processar dependências: ${error.message}`,
            type: window.ErrorType.DATA_LOAD,
            level: window.ErrorLevel.ERROR,
            originalError: error
        });
        
        // Criar uma resposta de erro mais informativa
        return new Response(JSON.stringify({
            error: true,
            message: `Erro ao processar dependências: ${error.message}`,
            details: error.stack,
            suggestion: 'Verifique o formato do arquivo e as propriedades das dependências'
        }), {
            status: 200,
            headers: new Headers({'Content-Type': 'application/json'})
        });
    }
}

// Sobrescrever o fetch para processar as respostas
const originalFetch = window.fetch;
window.fetch = async function(...args) {
    const response = await originalFetch(...args);
    return processApiResponse(response);
};

// Exportar para compatibilidade com código existente
window.dataAdapter = {
    formatVariableReference,
    transformProjectData,
    processApiResponse
};