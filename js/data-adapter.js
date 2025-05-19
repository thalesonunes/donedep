// JoneDep Data Adapter - Maps raw JSON data from the backend to the format expected by the frontend
// Este script deve ser incluído antes do app.js

console.log('JoneDep Data Adapter carregado');

// Override the fetch function para transformar as respostas de dependencies.json
const originalFetch = window.fetch;
window.fetch = async function(...args) {
    const response = await originalFetch(...args);
    
    // Interceptar apenas requisições para o arquivo dependencies.json
    if (args[0] && args[0].includes('dependencies.json')) {
        const clonedResponse = response.clone();
        try {
            const data = await clonedResponse.json();
            
            if (!Array.isArray(data)) {
                return response;
            }
            
            // Transformar os dados para o formato esperado pelo frontend
            const transformedData = data.map(project => {
                if (!project) return null;
                
                // Criar objeto requirements
                const requirements = {
                    java: project.javaVersion || null,
                    kotlin: project.kotlinVersion || null,
                    gradle: project.gradleVersion || null,
                    spring_boot: project.springBootVersion || null
                };
                
                // Processar dependências
                let processedDependencies = [];
                if (project.dependencies && Array.isArray(project.dependencies)) {
                    processedDependencies = project.dependencies
                        .filter(dep => dep && dep.group && dep.name)
                        .map(dep => ({
                            group: dep.group,
                            name: dep.name,
                            version: dep.version || 'N/A',
                            configuration: dep.configuration || 'implementation',
                            declaration: dep.declaration || `${dep.configuration || 'implementation'}("${dep.group}:${dep.name}:${dep.version || 'N/A'}")`
                        }));
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
            // Em caso de erro, retornar a resposta original
            return response;
        }
    }
    
    // Para todas as outras requisições, retornar a resposta original
    return response;
};
