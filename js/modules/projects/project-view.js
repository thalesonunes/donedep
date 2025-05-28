/**
 * DoneDep - Visualização de Projetos
 * Gerencia a visualização e o estado visual dos projetos
 */

// Usando funções e objetos expostos globalmente

/**
 * Classe ProjectView - Responsável pela renderização da visão de projetos
 */
class ProjectView {
    /**
     * Renderiza um card de projeto
     * @param {Object} project - Dados do projeto
     * @returns {HTMLElement} - Elemento do card do projeto
     */
    static renderProjectCard(project) {
        try {
            if (!project || !project.project) {
                throw new Error('Dados do projeto inválidos');
            }
            
            const card = document.createElement('div');
            card.className = 'project-card';
            
            // Cabeçalho do card com o nome do projeto
            const header = document.createElement('div');
            header.className = 'project-header';
            header.textContent = window.utils.escapeHTML(project.project);
            
            // Seção de tecnologias
            const technologies = document.createElement('div');
            technologies.className = 'project-technologies';
            
            if (project.requirements) {
                Object.entries(project.requirements).forEach(([key, value]) => {
                    if (value) {
                        const tech = document.createElement('span');
                        tech.className = 'project-tech-badge';
                        tech.textContent = getFilterDisplayLabel(key, value);
                        technologies.appendChild(tech);
                    }
                });
            }
            
            // Seção de dependências
            const dependencies = document.createElement('div');
            dependencies.className = 'project-dependencies';
            
            if (project.dependencies && project.dependencies.length > 0) {
                const depCount = document.createElement('span');
                depCount.className = 'dependency-count';
                depCount.textContent = `${project.dependencies.length} dependências`;
                dependencies.appendChild(depCount);
                
                // Lista de dependências
                const depList = document.createElement('div');
                depList.className = 'dependency-list';
                
                project.dependencies.forEach(dep => {
                    const depItem = document.createElement('div');
                    depItem.className = 'dependency-item';
                    
                    // Classe adicional se houver variável não resolvida
                    if (dep.hasUnresolvedVariable) {
                        depItem.classList.add('has-unresolved-variable');
                    }
                    
                    depItem.innerHTML = `
                        <div class="dependency-name" title="${window.utils.escapeHTML(dep.group)}:${window.utils.escapeHTML(dep.name)}">
                            ${window.utils.escapeHTML(dep.name)}
                        </div>
                        <div class="dependency-configuration">(${window.utils.escapeHTML(dep.configuration)})</div>
                        <div class="dependency-version" title="Versão: ${window.utils.escapeHTML(dep.version)}">
                            ${window.utils.escapeHTML(dep.version)}
                        </div>
                        <div class="dependency-actions">
                            <button class="copy-gradle" title="Copiar formato Gradle">
                                <span class="material-symbols-outlined">content_copy</span>
                            </button>
                            <button class="copy-maven" title="Copiar formato Maven">
                                <span class="material-symbols-outlined">content_copy</span>
                            </button>
                        </div>
                    `;
                    
                    // Adicionar event listeners para cópia
                    const copyGradle = depItem.querySelector('.copy-gradle');
                    const copyMaven = depItem.querySelector('.copy-maven');
                    
                    if (copyGradle) {
                        copyGradle.addEventListener('click', () => {
                            copyUtils.copySingleDependency(dep, 'gradle');
                        });
                    }
                    
                    if (copyMaven) {
                        copyMaven.addEventListener('click', () => {
                            copyUtils.copySingleDependency(dep, 'maven');
                        });
                    }
                    
                    // Se houver variável não resolvida, adicionar tooltip
                    if (dep.hasUnresolvedVariable) {
                        const originalVersion = document.createElement('div');
                        originalVersion.className = 'original-version-tooltip';
                        originalVersion.textContent = `Versão original: ${dep.originalVersion}`;
                        depItem.appendChild(originalVersion);
                    }
                    
                    depList.appendChild(depItem);
                });
                
                dependencies.appendChild(depList);
            } else {
                const noDeps = document.createElement('div');
                noDeps.className = 'no-dependencies';
                noDeps.textContent = 'Nenhuma dependência';
                dependencies.appendChild(noDeps);
            }
            
            // Montar o card
            card.appendChild(header);
            card.appendChild(technologies);
            card.appendChild(dependencies);
            
            return card;
        } catch (error) {
            logError({
                message: `Erro ao renderizar card do projeto: ${error.message}`,
                type: ErrorType.RENDER,
                level: ErrorLevel.ERROR,
                originalError: error,
                context: { projectName: project?.project }
            });
            
            // Retornar card de erro
            const errorCard = document.createElement('div');
            errorCard.className = 'project-card error';
            errorCard.innerHTML = `
                <div class="error-message">
                    Erro ao carregar projeto ${project?.project || ''}
                </div>
            `;
            return errorCard;
        }
    }

    /**
     * Renderiza a listagem de projetos em um container
     * @param {Array} projects - Array de projetos
     * @param {HTMLElement} container - Container onde renderizar
     */
    static renderProjectsList(projects, container) {
        try {
            if (!container) {
                throw new Error('Container não fornecido para renderização');
            }
            
            // Limpar container
            container.innerHTML = '';
            
            if (!Array.isArray(projects) || projects.length === 0) {
                container.innerHTML = `
                    <div class="no-projects">
                        <div class="message">Nenhum projeto encontrado</div>
                        <div class="suggestion">Tente ajustar os filtros de busca</div>
                    </div>
                `;
                return;
            }
            
            // Renderizar cada projeto
            projects.forEach(project => {
                const card = ProjectView.renderProjectCard(project);
                container.appendChild(card);
            });
            
            // Atualizar contadores
            ProjectView.updateProjectCounters(projects);
        } catch (error) {
            logError({
                message: `Erro ao renderizar lista de projetos: ${error.message}`,
                type: ErrorType.RENDER,
                level: ErrorLevel.ERROR,
                originalError: error,
                context: { projectsCount: projects?.length }
            });
            
            container.innerHTML = `
                <div class="error-container">
                    <div class="error-message">Erro ao carregar projetos</div>
                    <div class="error-suggestion">Por favor, tente novamente mais tarde</div>
                </div>
            `;
        }
    }

    /**
     * Atualiza os contadores de projetos e dependências
     * @param {Array} projects - Array de projetos
     */
    static updateProjectCounters(projects) {
        try {
            const projectCount = document.getElementById('filtered-projects-count');
            const totalDependencyCount = document.getElementById('filtered-dependencies-total-count');
            const uniqueDependencyCount = document.getElementById('filtered-dependencies-unique-count');
            
            // Contagem de projetos
            const validProjectCount = Array.isArray(projects) ? projects.length : 0;
            if (projectCount) {
                projectCount.textContent = validProjectCount;
                console.log(`Contadores atualizados: ${validProjectCount} projetos`);
            }
            
            // Usar a mesma lógica de getDependencyCounts para consistência
            if (totalDependencyCount && uniqueDependencyCount) {
                // Se não há projetos, zerar contadores
                if (validProjectCount === 0) {
                    totalDependencyCount.textContent = 0;
                    uniqueDependencyCount.textContent = 0;
                    console.log('Contadores zerados - nenhum projeto válido');
                    return;
                }
                
                // Usar getDependencyCounts com filtros atuais para obter contagens consistentes
                const activeFilters = window._activeFilters || {};
                const searchTerm = window.searchTerm || '';
                
                if (window.getDependencyCounts) {
                    const counts = window.getDependencyCounts(projects, activeFilters, searchTerm);
                    totalDependencyCount.textContent = counts.totalCount;
                    uniqueDependencyCount.textContent = counts.uniqueCount;
                    console.log(`Contadores atualizados: ${counts.totalCount} dependências totais, ${counts.uniqueCount} dependências únicas`);
                } else {
                    // Fallback para contagem manual se getDependencyCounts não estiver disponível
                    let totalDeps = 0;
                    const uniqueDepsSet = new Set();
                    
                    if (Array.isArray(projects)) {
                        projects.forEach(project => {
                            if (project && Array.isArray(project.dependencies)) {
                                // Contagem total
                                totalDeps += project.dependencies.length;
                                
                                // Contagem única
                                project.dependencies.forEach(dep => {
                                    if (dep && dep.group && dep.name) {
                                        const depKey = `${dep.group}:${dep.name}:${dep.version}`;
                                        uniqueDepsSet.add(depKey);
                                    }
                                });
                            }
                        });
                    }
                    
                    const uniqueDeps = uniqueDepsSet.size;
                    totalDependencyCount.textContent = totalDeps;
                    uniqueDependencyCount.textContent = uniqueDeps;
                    console.log(`Contadores atualizados (fallback): ${totalDeps} dependências totais, ${uniqueDeps} dependências únicas`);
                }
            }
        } catch (error) {
            logError({
                message: `Erro ao atualizar contadores: ${error.message}`,
                type: ErrorType.RENDER,
                level: ErrorLevel.WARNING,
                originalError: error
            });
        }
    }

    /**
     * Exibe detalhes de um projeto em um modal
     * @param {Object} project - Projeto a ser exibido
     */
    static showProjectDetails(project) {
        try {
            if (!project) return;
            
            const modalContent = `
                <div class="project-details">
                    <h2>${window.utils.escapeHTML(project.project)}</h2>
                    
                    <div class="project-info">
                        <div class="info-group">
                            <h3>Tecnologias</h3>
                            <ul>
                                ${project.requirements ? Object.entries(project.requirements)
                                    .filter(([_, value]) => value)
                                    .map(([key, value]) => `<li>${getFilterDisplayLabel(key, value)}</li>`)
                                    .join('') : '<li>Nenhuma informação disponível</li>'}
                            </ul>
                        </div>
                        
                        <div class="info-group">
                            <h3>Dependências (${project.dependencies?.length || 0})</h3>
                            ${project.dependencies?.length ? `
                                <table class="dependency-table">
                                    <thead>
                                        <tr>
                                            <th>Nome</th>
                                            <th>Grupo</th>
                                            <th>Versão</th>
                                            <th>Configuração</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        ${project.dependencies.map(dep => `
                                            <tr>
                                                <td>${window.utils.escapeHTML(dep.name)}</td>
                                                <td>${window.utils.escapeHTML(dep.group)}</td>
                                                <td>${window.utils.escapeHTML(dep.version)}${dep.hasUnresolvedVariable ? ' ⚠️' : ''}</td>
                                                <td>${window.utils.escapeHTML(dep.configuration)}</td>
                                            </tr>
                                        `).join('')}
                                    </tbody>
                                </table>
                            ` : '<p>Nenhuma dependência</p>'}
                        </div>
                    </div>
                </div>
            `;
            
            showModal({
                id: 'project-details-modal',
                content: modalContent,
                title: 'Detalhes do Projeto'
            });
        } catch (error) {
            logError({
                message: `Erro ao exibir detalhes do projeto: ${error.message}`,
                type: ErrorType.RENDER,
                level: ErrorLevel.ERROR,
                originalError: error,
                context: { projectName: project?.project }
            });
            
            showNotification({
                message: 'Erro ao exibir detalhes do projeto',
                type: NotificationType.ERROR
            });
        }
    }

    /**
     * Renderiza as dependências em um grid
     * @param {Array} dependencies - Lista de dependências
     * @param {Object} activeFilters - Filtros ativos
     */
    static renderDependencies(dependencies, activeFilters) {
        const dependenciesGrid = document.getElementById('dependencies-grid');
        
        // Obter contagens separadas usando a nova função
        const counts = window.getDependencyCounts(window._allProjects, activeFilters, window.searchTerm || '');
        
        // Atualizar contadores na interface
        document.getElementById('filtered-dependencies-total-count').textContent = counts.totalCount;
        document.getElementById('filtered-dependencies-unique-count').textContent = counts.uniqueCount;

        // Para a visualização, mostrar dependências únicas
        const uniqueDependencies = counts.uniqueDependencies;

        if (uniqueDependencies.length === 0) {
            // Check which filters are active
            const activeFilterLabels = [];
            if (activeFilters.java) activeFilterLabels.push(`Java: ${activeFilters.java}`);
            if (activeFilters.kotlin) activeFilterLabels.push(`Kotlin: ${activeFilters.kotlin}`);
            if (activeFilters.gradle) activeFilterLabels.push(`Gradle: ${activeFilters.gradle}`);
            if (activeFilters.spring_boot) activeFilterLabels.push(`Spring Boot: ${activeFilters.spring_boot}`);
            
            // Custom message based on active filters
            let message = 'Nenhuma dependência encontrada com os filtros atuais.';
            if (activeFilterLabels.length > 0) {
                message += '<br><span class="filter-info">Filtros ativos: ' + activeFilterLabels.join(', ') + '</span>';
                message += '<br><span class="filter-tip">Tente uma combinação diferente ou limpe os filtros.</span>';
            } else {
                message += '<br><span class="filter-info">Nenhuma dependência encontrada em nenhum projeto.</span>';
                message += '<br><span class="filter-tip">Verifique se o script de extração está configurado corretamente.</span>';
            }
            
            dependenciesGrid.innerHTML = `<div class="no-results">${message}</div>`;
            return;
        }

        dependenciesGrid.innerHTML = '';
        uniqueDependencies.forEach(dep => {
            const card = document.createElement('div');
            card.className = 'dependency-card';
            
            // Check for unresolved variable
            const versionClass = dep.hasUnresolvedVariable ? 'version version-warning' : 'version';
            
            // Prepare additional content for unresolved variables
            let warningInfo = '';
            if (dep.hasUnresolvedVariable) {
                warningInfo = `<div class="variable-warning">
                  <span class="warning-icon">⚠️</span> 
                  <span class="warning-text">Variável não resolvida</span>
                  <span class="original-version" title="Versão original: ${dep.originalVersion}">ℹ️</span>
                </div>`;
            }
            
            // Extract projects using this dependency
            let projectsHtml = '';
            if (dep.projects && Array.isArray(dep.projects) && dep.projects.length > 0) {
                projectsHtml = `<div class="dependency-projects">${dep.projects.join(', ')}</div>`;
            }
            
            card.innerHTML = `
              <div class="dependency-group">${window.utils.escapeHTML(dep.group)}</div>
              <div class="dependency-name">${window.utils.escapeHTML(dep.name)}</div>
              <div class="dependency-configuration">(${window.utils.escapeHTML(dep.configuration)})</div>
              <div class="dependency-version">
                <span class="${versionClass}" id="version-${dep.id || Math.random().toString(36).substring(2)}">${window.utils.escapeHTML(dep.version)}</span>
                ${warningInfo}
              </div>
              <div class="copy-buttons">
                <button class="copy-button" title="Copiar formato Gradle"
                  data-format="gradle" 
                  data-group="${window.utils.escapeHTML(dep.group)}" 
                  data-name="${window.utils.escapeHTML(dep.name)}" 
                  data-version="${window.utils.escapeHTML(dep.version)}">
                  <span class="material-symbols-outlined">content_copy</span>
                  <span class="button-text">Gradle</span>
                </button>
                <button class="copy-button" title="Copiar formato Maven"
                  data-format="maven" 
                  data-group="${window.utils.escapeHTML(dep.group)}" 
                  data-name="${window.utils.escapeHTML(dep.name)}" 
                  data-version="${window.utils.escapeHTML(dep.version)}">
                  <span class="material-symbols-outlined">content_copy</span>
                  <span class="button-text">Maven</span>
                </button>
              </div>
              ${projectsHtml}
            `;
            
            // Add copy button event listeners
            card.querySelectorAll('.copy-button').forEach(button => {
              button.addEventListener('click', (e) => {
                const format = e.target.closest('.copy-button').dataset.format;
                const group = e.target.closest('.copy-button').dataset.group;
                const name = e.target.closest('.copy-button').dataset.name;
                const version = e.target.closest('.copy-button').dataset.version;
                
                let declaration;
                if (format === 'gradle') {
                  declaration = `implementation "${group}:${name}:${version}"`;
                } else {
                  declaration = `<dependency>\n    <groupId>${group}</groupId>\n    <artifactId>${name}</artifactId>\n    <version>${version}</version>\n</dependency>`;
                }
                
                copyToClipboard(declaration, `Dependência copiada no formato ${format === 'gradle' ? 'Gradle' : 'Maven'}!`);
              });
            });
            
            dependenciesGrid.appendChild(card);
        });
    }
}

// Exportar para compatibilidade com código existente
window.projectView = {
    renderProjectCard: ProjectView.renderProjectCard,
    renderProjectsList: ProjectView.renderProjectsList,
    showProjectDetails: ProjectView.showProjectDetails
};

// Expor classe globalmente
window.ProjectView = ProjectView;
