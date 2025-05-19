<!-- filepath: /home/thalesnunes/Documentos/jone-dep/README.md -->
<p align="center">
  <img src="assets/jone-dep-logo.svg" alt="JoneDep Logo" width="400"/>
</p>

# JoneDep - Gerenciador de Dependências de Microsserviços

JoneDep é uma ferramenta simples e direta para extrair e visualizar dependências de projetos Java/Kotlin com Gradle e Maven. Ela permite identificar facilmente quais dependências são usadas em diferentes projetos e com quais combinações de tecnologias (Java, Kotlin, Gradle, Spring Boot).

## Eficiência e Simplicidade

Este projeto foi projetado sob o princípio "menos é mais". A ferramenta realiza de forma eficiente duas tarefas:
1. **Extração de dependências** - usando scripts shell simples e eficientes
2. **Visualização de dependências** - com interface web mínima e funcional

O código foi completamente simplificado para garantir manutenibilidade e confiabilidade, evitando complexidades desnecessárias como:
- Múltiplas versões de arquivos (tudo consolidado em versões únicas)
- Validações excessivas para casos extremos
- Transformações de dados complicadas
- Camadas de abstração desnecessárias
- Arquivos de backup e temporários (todos removidos)

## Estrutura do Projeto

```
├── assets/               # Arquivos de imagem e recursos
│   └── jone-dep-logo.svg # Logo do JoneDep
├── css/                  # Arquivos de estilo
│   └── style.css         # Estilos da aplicação
├── data/                 # Dados da aplicação
│   ├── dependencies.json # Arquivo com dependências extraídas
│   ├── jone-dep.log      # Arquivo de log
│   └── repo_cache/       # Cache dos repositórios clonados
├── js/                   # Arquivos JavaScript
│   ├── app.js            # Lógica principal da aplicação
│   └── data-adapter.js   # Adaptador simplificado para compatibilidade de dados
├── scripts/              # Diretório de scripts
│   ├── main.sh           # Script principal modularizado
│   ├── check_json.sh     # Script para validar JSON gerado
│   ├── verify.sh         # Script de verificação rápida
│   ├── install.sh        # Script de instalação
│   └── modules/          # Módulos do sistema
│       ├── common.sh           # Funções comuns e utilitários
│       ├── repo_manager.sh     # Gerenciamento de repositórios Git
│       ├── version_extractor.sh # Extração de versões de tecnologias
│       ├── dependency_parser.sh # Parsing de dependências
│       ├── json_handler.sh     # Manipulação de JSON
│       └── project_analyzer.sh # Análise de estrutura de projetos
├── run.sh                # Script principal para execução
├── index.html            # Página principal da aplicação
└── README.md             # Este arquivo de documentação
```

## Funcionalidades

- **Extração automatizada de dependências** de múltiplos projetos Git
- **Interface web interativa** para filtrar e visualizar dependências
- **Filtros inteligentes bidirecionais** que se atualizam dinamicamente
- **Cópia fácil** de dependências para uso em novos projetos
- **Detecção automática** de versões Java, Kotlin, Gradle e Spring Boot
- **Arquitetura modular** para fácil manutenção e extensibilidade

## Processo de Simplificação

O projeto JoneDep passou por uma completa simplificação para focar em sua proposta original. As principais melhorias incluem:

### Principais Realizações

1. **Consolidação de Arquivos**
   - Eliminação de todas as versões redundantes de scripts
   - Remoção completa de diretórios de backup e arquivos temporários
   - Redução da base de código em aproximadamente 60%

2. **Melhorias de Interface**
   - Simplificação do adaptador de dados front-end
   - Correção do erro "Failed to fetch" na interface web
   - Interface mais direta e intuitiva

3. **Aprimoramentos de Registro e Logging**
   - Formato de timestamp consistente em todos os logs
   - Mensagens de log mais claras e informativas

4. **Princípios da Simplificação**
   - **Clareza sobre complexidade**: Preferência por código claro e direto em vez de abstrações complexas
   - **Redução de redundâncias**: Eliminação de validações excessivas e código duplicado
   - **Manutenibilidade**: Foco em tornar o código fácil de entender e manter
   - **Eficiência**: A ferramenta deve extrair e apresentar dependências de forma rápida e confiável

### Resultados Mensuráveis

- Redução de 60% no tamanho total do projeto
- Eliminação de todas as ocorrências de "Failed to fetch" na interface
- Processamento mais rápido e eficiente das dependências

## Arquitetura Técnica

O JoneDep utiliza uma arquitetura modular baseada em scripts Bash, dividida em componentes com responsabilidades específicas:

### Módulos do Sistema

- **common.sh**: Funções comuns utilizadas em todos os módulos (logging, utilitários)
- **repo_manager.sh**: Funções para gerenciamento de repositórios Git
- **version_extractor.sh**: Funções para extração de versões (Java, Kotlin, Gradle, Spring Boot)
- **dependency_parser.sh**: Funções para extração de dependências de diferentes sistemas de build
- **json_handler.sh**: Funções para manipulação de JSON
- **project_analyzer.sh**: Funções para análise da estrutura de projetos

### Fluxo de Processamento

1. O script principal `main.sh` orquestra o processo de extração
2. Os repositórios são clonados ou atualizados usando `repo_manager.sh` 
3. Para cada repositório, `project_analyzer.sh` identifica sua estrutura
4. `version_extractor.sh` extrai informações de versões das tecnologias
5. `dependency_parser.sh` analisa os arquivos de build para extrair dependências
6. `json_handler.sh` formata e valida os dados coletados
7. O resultado é salvo em `data/dependencies.json`

### Interface Web

A interface web utiliza JavaScript para carregar e exibir as dependências:

- **app.js**: Controla a lógica da aplicação e gerenciamento de estado
- **data-adapter.js**: Adaptador simplificado que garante compatibilidade de formato

## Formatos de Dependências Suportados

### Gradle (Groovy)
```groovy
dependencies {
    implementation 'group:artifact:version'
    api 'group:artifact:version'
    compileOnly 'group:artifact:version'
}
```

### Gradle (Kotlin DSL)
```kotlin
dependencies {
    implementation("group:artifact:version")
    api("group:artifact:version") 
    implementation(kotlin("stdlib-jdk8"))
}
```

### Maven
```xml
<dependencies>
    <dependency>
        <groupId>group</groupId>
        <artifactId>artifact</artifactId>
        <version>version</version>
    </dependency>
</dependencies>
```

## Formato de Saída JSON

O JoneDep gera um arquivo JSON com a seguinte estrutura:

```json
[
  {
    "name": "nome-do-projeto",
    "path": "/caminho/para/o/projeto",
    "javaVersion": "17",
    "kotlinVersion": "1.8.0",
    "gradleVersion": "8.0.1",
    "springBootVersion": "3.0.4",
    "modules": ["módulo1", "módulo2"],
    "dependencies": [
      {
        "group": "org.springframework.boot",
        "artifact": "spring-boot-starter-web",
        "version": "3.0.4"
      }
    ]
  }
]
```

## Como Usar

### Instalação

```bash
# Clone o repositório
git clone https://github.com/user/jone-dep.git
cd jone-dep

# Torne os scripts executáveis
chmod +x run.sh scripts/*.sh scripts/modules/*.sh
```

### Extração de Dependências

Adicione os repositórios Git que deseja analisar ao arquivo `repos.txt`, um por linha:

```
https://github.com/user/projeto1.git
https://github.com/user/projeto2.git
/caminho/local/para/projeto3
```

Execute o script de extração:

```bash
./run.sh extract
```

### Visualização de Dependências

Abra a interface web:

```bash
./run.sh view
```

Ou manualmente:

```bash
python3 -m http.server 8000
# Acesse http://localhost:8000 no navegador
```

### Verificação do Sistema

```bash
./run.sh verify
```

## Uso da Interface

### Filtros

Use os filtros à esquerda para refinar a visualização de dependências:

- **Por projeto**: Selecione um ou mais projetos específicos
- **Por tecnologia**: Filtre por versão de Java, Kotlin, Gradle ou Spring Boot
- **Por dependência**: Selecione dependências específicas para ver onde são utilizadas

Para limpar todos os filtros, clique no botão "X" ao lado dos filtros.

### Busca

Digite termos de busca na caixa de pesquisa para encontrar dependências específicas. A busca considera tanto o nome quanto o grupo da dependência.

### Cópia

- Para copiar uma dependência individual, clique no botão de cópia ao lado dela
- Para copiar todas as dependências filtradas atualmente, clique no botão "COPIAR LISTA COMPLETA"

## Solução de Problemas

### Arquivo JSON vazio

Verifique:
- Se os repositórios estão disponíveis em `repos.txt`
- Se as credenciais Git estão configuradas corretamente
- Se há espaço suficiente em disco
- O arquivo de log em `data/jone-dep.log` para detalhes

### Interface web não carrega dependências

Verifique:
- Se o arquivo `data/dependencies.json` existe e é válido
- Se está utilizando um navegador moderno com JavaScript habilitado
- Se o arquivo `js/data-adapter.js` está presente e não foi modificado

### O script apresenta erros ao clonar repositórios

Verifique:
- Se você tem acesso aos repositórios listados
- Se as credenciais Git estão configuradas corretamente
- Se o Git está instalado e disponível no PATH

## Lições Aprendidas

- Código simples é mais fácil de depurar e manter
- Excesso de validações e transformações pode introduzir novos bugs
- A solução mais eficaz é geralmente a mais direta
- Ferramentas devem ser simples e fazer bem sua tarefa principal

---

**Versão:** 2.1  
**Última atualização:** 21/05/2025  
**Autor:** Thales Nunes
