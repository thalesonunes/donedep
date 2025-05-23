/**
 * DoneDep - Utilitários de Cópia
 * Funções para copiar conteúdo para a área de transferência
 */

// Usando a função showModal exposta globalmente

/**
 * Copia um texto para a área de transferência
 * @param {string} text - Texto a ser copiado
 * @param {string} [message="Copiado com sucesso!"] - Mensagem de confirmação
 */
function copyToClipboard(text, message = 'Copiado com sucesso!') {
  // Usar a API moderna para copiar para a área de transferência
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text)
      .then(() => {
        // Atualizar texto do modal primeiro
        const textElement = document.getElementById('copy-modal-text');
        if (textElement) {
          textElement.textContent = message;
        }
        
        // Exibir o modal com a classe show
        const modal = document.getElementById('copy-modal');
        if (modal) {
          // Remover classes existentes e forçar reflow
          modal.classList.remove('show');
          void modal.offsetWidth;
          modal.classList.add('show');
          
          // Esconder após timeout
          setTimeout(() => {
            modal.classList.remove('show');
          }, Config.MODAL_TIMEOUT.COPY);
        }
      })
      .catch(err => {
        console.error('Error copying to clipboard:', err);
        // Fallback para o método antigo
        fallbackCopyToClipboard(text, message);
      });
  } else {
    // Método antigo para navegadores que não suportam a API Clipboard
    fallbackCopyToClipboard(text, message);
  }
}

/**
 * Método alternativo de cópia para navegadores sem suporte à Clipboard API
 * @param {string} text - Texto a ser copiado
 * @param {string} message - Mensagem de confirmação
 */
function fallbackCopyToClipboard(text, message) {
  const textarea = document.createElement('textarea');
  textarea.value = text;
  textarea.setAttribute('readonly', '');
  textarea.style.position = 'absolute';
  textarea.style.left = '-9999px';
  document.body.appendChild(textarea);
  textarea.select();
  document.execCommand('copy');
  document.body.removeChild(textarea);
  
  // Atualizar texto do modal primeiro
  const textElement = document.getElementById('copy-modal-text');
  if (textElement) {
    textElement.textContent = message;
  }
  
  // Exibir o modal com a classe show
  const modal = document.getElementById('copy-modal');
  if (modal) {
    // Remover classes existentes e forçar reflow
    modal.classList.remove('show');
    void modal.offsetWidth;
    modal.classList.add('show');
    
    // Esconder após timeout
    setTimeout(() => {
      modal.classList.remove('show');
    }, Config.MODAL_TIMEOUT.COPY);
  }
}

/**
 * Copia todas as dependências filtradas em um formato específico
 * @param {Array} dependencies - Array de dependências filtradas
 * @param {string} format - Formato ('gradle' ou 'maven')
 */
function copyAllDependencies(dependencies, format) {
  if (!dependencies || dependencies.length === 0) {
    copyToClipboard('', 'Nenhuma dependência para copiar!');
    return;
  }
  
  let declarations;
  
  try {
    if (format === 'gradle') {
      declarations = dependencies
        .map(dep => `implementation "${dep.group}:${dep.name}:${dep.version}"`)
        .join('\n');
    } else if (format === 'maven') {
      declarations = dependencies
        .map(dep => 
          `<dependency>\n    <groupId>${dep.group}</groupId>\n    <artifactId>${dep.name}</artifactId>\n    <version>${dep.version}</version>\n</dependency>`
        )
        .join('\n');
    } else {
      throw new Error(`Formato não suportado: ${format}`);
    }
    
    copyToClipboard(declarations, `Dependências copiadas no formato ${format === 'gradle' ? 'Gradle' : 'Maven'}!`);
  } catch (err) {
    console.error('Erro ao formatar dependências para cópia:', err);
    copyToClipboard('', 'Erro ao copiar dependências!');
  }
}

/**
 * Copia uma única dependência em um formato específico
 * @param {Object} dependency - Objeto de dependência
 * @param {string} format - Formato ('gradle' ou 'maven')
 */
function copySingleDependency(dependency, format) {
  if (!dependency || !dependency.group || !dependency.name) {
    copyToClipboard('', 'Dependência inválida!');
    return;
  }
  
  try {
    let declaration;
    
    if (format === 'gradle') {
      declaration = `implementation "${dependency.group}:${dependency.name}:${dependency.version}"`;
    } else if (format === 'maven') {
      declaration = `<dependency>\n    <groupId>${dependency.group}</groupId>\n    <artifactId>${dependency.name}</artifactId>\n    <version>${dependency.version}</version>\n</dependency>`;
    } else {
      throw new Error(`Formato não suportado: ${format}`);
    }
    
    copyToClipboard(declaration, `Dependência copiada no formato ${format === 'gradle' ? 'Gradle' : 'Maven'}!`);
  } catch (err) {
    console.error('Erro ao copiar dependência:', err);
    copyToClipboard('', 'Erro ao copiar dependência!');
  }
}

// Exportar para compatibilidade com código existente
window.copyUtils = {
  copyToClipboard,
  copyAllDependencies,
  copySingleDependency
};

// Expor funções globalmente
window.copyToClipboard = copyToClipboard;
window.copyAllDependencies = copyAllDependencies;
window.copySingleDependency = copySingleDependency;
