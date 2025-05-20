// filepath: /home/thalesnunes/Documentos/jone-dep/js/data-adapter.js
// JoneDep Data Adapter - Maps raw JSON data from the backend to the format expected by the frontend
// Este script deve ser incluído antes do app.js

console.log('JoneDep Data Adapter carregado');

// Função para formatar referências a variáveis de forma mais amigável ao usuário
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
    
    // Fornecer valores conhecidos para variáveis comuns
    const knownVariables = {
        'kotlinVersion': '1.9.10',
        'springBootVersion': '2.6.15',
        'oracleDriverVersion': '19.8.0.0',
        'jjwtVersion': '0.11.5',
        'swaggerVersion': '2.10.0'
    };
    
    // Se for uma variável conhecida, mostrar o valor
    if (knownVariables[varName]) {
        return knownVariables[varName];
    }
    
    // Retornar uma representação mais amigável da variável não resolvida
    return `<Ref: ${varName}>`;
}

// Função para remover comentários e fazer parse do JSON
function parseJsonWithCommentRemoval(text) {
    // Remover possíveis comentários que podem estar no arquivo JSON
    const jsonTextWithoutComments = text
        .split('\n')
        .filter(line => !line.trim().startsWith('//'))
        .join('\n');
    
    return JSON.parse(jsonTextWithoutComments);
}

// Override the fetch function para transformar as respostas de dependencies.json
const originalFetch = window.fetch;
window.fetch = async function(...args) {
    const response = await originalFetch(...args);
    
    // Interceptar apenas requisições para o arquivo dependencies.json
    if (args[0] && args[0].includes('dependencies.json')) {
        const clonedResponse = response.clone();
        try {
            // Primeiro tentar obter o texto bruto para manipular variáveis não resolvidas
            const rawText = await clonedResponse.text();
            
            // Remover possíveis comentários e fazer parse do JSON
            let data;
            try {
                data = parseJsonWithCommentRemoval(rawText);
            } catch (parseError) {
                console.error('Erro ao fazer parse do JSON:', parseError);
                
                // Criar uma resposta de erro mais amigável
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
            const transformedData = data.map(project => {
                if (!project) return null;
                
                // Validar e normalizar o objeto do projeto
                const validProject = {
                    project: project.project || "Projeto sem nome",
                    kotlinVersion: project.kotlinVersion || null,
                    gradleVersion: project.gradleVersion || null,
                    springBootVersion: project.springBootVersion || null,
                    javaVersion: project.javaVersion || null,
                    ...project
                };
                
                // Criar objeto requirements
                const requirements = {
                    java: validProject.javaVersion || null,
                    kotlin: validProject.kotlinVersion || null,
                    gradle: validProject.gradleVersion || null,
                    spring_boot: validProject.springBootVersion || null
                };
                
                // Processar dependências - apenas formatar referências de variáveis não resolvidas
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
                                originalVersion: originalVersion, // Guardar a versão original para debugging
                                configuration: dep.configuration || 'implementation',
                                projects: [project.project], // Adicionar o nome do projeto atual
                                hasUnresolvedVariable: isVariableVersion && formattedVersion.includes('<Ref:'),
                                declaration: dep.declaration || 
                                    `${dep.configuration || 'implementation'}("${dep.group}:${dep.name}:${formattedVersion || 'N/A'}")`
                            };
                        });
                }
                
                // Adicionar informação sobre variáveis não resolvidas
                if (hasUnresolvedVariables) {
                    console.warn(`Projeto ${validProject.project} contém variáveis não resolvidas`);
                }
                
                // Retornar o projeto transformado
                return {
                    ...project,
                    requirements,
                    dependencies: processedDependencies
                };
            }).filter(Boolean);
            
            // Criar resposta com os dados transformados
            return new Response(JSON.stringify(transformedData), {
                status: response.status,
                statusText: response.statusText,
                headers: new Headers({'Content-Type': 'application/json'})
            });
        } catch (error) {
            console.error('Erro ao processar dependências:', error);
            
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
    
    // Para todas as outras requisições, retornar a resposta original
    return response;
};
