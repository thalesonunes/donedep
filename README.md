<p align="center">
  <img src="assets/donedep-logo.svg" alt="DoneDep Logo" width="400"/>
</p>

# DoneDep - Gerenciador de Dependências de Microsserviços

DoneDep é uma ferramenta simples e direta para visualizar e gerenciar dependências de projetos Java/Kotlin com Gradle e Maven. Projetada para ambientes com múltiplos microsserviços, ela permite identificar facilmente quais dependências são usadas em diferentes projetos e com quais combinações de tecnologias (Java, Kotlin, Gradle, Maven, Spring Boot).

## Filosofia do Projeto

Este projeto foi desenvolvido com foco em simplicidade e funcionalidade objetiva. A ferramenta foi construída para realizar duas tarefas essenciais com máxima eficiência:

1. **Extração de dependências** - através de scripts shell diretos e eficazes
2. **Visualização interativa** - com interface web responsiva e intuitiva
3. **Histórico de dependências** - mantém versões com timestamp das dependências extraídas ao longo do tempo

O projeto foi desenvolvido utilizando pair programming com assistência de IA, permitindo explorar novas abordagens de desenvolvimento colaborativo.

A escolha de scripts shell para o backend foi uma decisão experimental, visando explorar as capacidades desta tecnologia em análise de código e automação.

Durante o desenvolvimento, priorizamos a clareza e a manutenibilidade do código, evitando:
- Duplicação de arquivos e funcionalidades
- Validações desnecessárias para casos raros
- Complexidade excessiva em transformações de dados
- Abstrações que dificultam a compreensão do código
- Acúmulo de arquivos temporários ou de backup

## Estrutura do Projeto

```
├── assets/               # Recursos visuais e imagens
│   ├── donedep-logo-bk.svg # Logo backup do DoneDep
│   └── donedep-logo.svg    # Logo principal do DoneDep
├── css/                  # Estilos da interface
│   ├── base.css             # Estilos base e resets
│   ├── buttons.css          # Estilos para botões
│   ├── dependencies.css     # Estilos para visualização de dependências
│   ├── filters.css          # Estilos para filtros
│   ├── header.css           # Estilos para o cabeçalho
│   ├── messages.css         # Estilos para mensagens e notificações
│   ├── modals.css           # Estilos para modais
│   ├── projects.css         # Estilos para visualização de projetos
│   ├── responsive.css       # Media queries para responsividade
│   └── search.css           # Estilos para componentes de busca
├── data/                 # Dados da aplicação
│   ├── dependencies.json # Arquivo com dependências extraídas
│   ├── donedep.log      # Arquivo de log
│   └── repo_cache/       # Cache local de repositórios
├── js/                   # Lógica da aplicação (JavaScript)
│   ├── adapters/         # Adaptadores para compatibilidade de dados
│   │   └── data-adapter.js  # Adaptador para formatar dados JSON
│   ├── core/             # Funcionalidades essenciais
│   │   ├── api.js           # Interface para API de dados
│   │   ├── config.js        # Configurações globais
│   │   ├── error-handler.js # Tratamento de erros
│   │   └── utils.js         # Utilitários gerais
│   ├── modules/          # Módulos funcionais
│   │   ├── dependencies/    # Módulos relacionados às dependências
│   │   │   ├── dependency-helper.js # Funções auxiliares
│   │   │   ├── dependency-model.js  # Modelo de dados
│   │   │   └── dependency-view.js   # Visualização de dependências
│   │   ├── filters/         # Módulos para filtragem
│   │   │   ├── filter-model.js   # Modelo de dados para filtros
│   │   │   ├── filter-utils.js   # Utilitários para filtros
│   │   │   └── filter-view.js    # Visualização de filtros
│   │   ├── projects/        # Módulos relacionados aos projetos
│   │   │   ├── project-list.js   # Listagem de projetos
│   │   │   ├── project-model.js  # Modelo de dados de projetos
│   │   │   └── project-view.js   # Visualização de projetos
│   │   └── ui/              # Componentes de interface
│   │       ├── copy-utils.js     # Utilitários de cópia
│   │       ├── modals.js         # Gerenciamento de modais
│   │       └── notifications.js  # Sistema de notificações
│   └── app.js            # Aplicação principal
├── scripts/              # Scripts para extração de dependências
│   ├── install.sh        # Script de instalação
│   ├── main.sh           # Script principal modularizado
│   ├── verify.sh         # Script de verificação rápida
│   └── modules/          # Módulos do sistema de extração
│       ├── common.sh           # Funções comuns e utilitários
│       ├── dependency_parser.sh # Parsing de dependências
│       ├── json_handler.sh     # Manipulação de JSON
│       ├── project_analyzer.sh # Análise da estrutura de projetos
│       ├── repo_manager.sh     # Gerenciamento de repositórios Git
│       └── version_extractor.sh # Extração de versões de tecnologias
├── index.html            # Página principal da aplicação
├── repos.txt             # Lista de repositórios para análise
├── run.sh                # Script principal para execução
└── README.md             # Este arquivo de documentação
```

## Funcionalidades

O DoneDep oferece um conjunto focado de funcionalidades para facilitar o gerenciamento de dependências:

**Extração de Dados**
- Detecção automática de versões do Java, Kotlin, Gradle, Maven e Spring Boot
- Suporte completo a sistemas de build Gradle (Groovy e Kotlin DSL) e Maven
- Identificação e processamento avançado de variáveis em arquivos de build (Gradle e Maven)
- Análise paralela de múltiplos repositórios e projetos
- Suporte a múltiplos tipos de configuração de dependências (implementation, testImplementation, compile, testCompile, runtimeOnly, compileOnly, annotationProcessor, api)
- Resolução de propriedades Maven e mapeamento automático de scopes

**Visualização e Filtragem**
- Sistema de filtros bidirecionais com atualização dinâmica
- Busca rápida por texto em nomes de dependências e grupos
- Exibição de todos os projetos que utilizam cada dependência
- Visualização organizada por categorias tecnológicas
- Interface totalmente em português
- Exibição das configurações de dependência (implementation, testImplementation, etc.) com destaque visual
- Filtragem inteligente que lida com valores especiais como "NENHUM", null e undefined

**Utilitários**
- Cópia com um clique de dependências em formatos Gradle e Maven
- Ordenação inteligente de diferentes formatos de versão
- Destaque visual para variáveis não resolvidas (marcadas com ⚡)
- Sistema de notificações e modais para feedback de ações
- Design responsivo com animações consistentes para melhor UX
- Histórico de dependências com arquivos timestamp para análise de mudanças ao longo do tempo
- Contagem aprimorada de dependências incluindo configuração na chave única
- Script de limpeza (DoneDep Cleaner) para remoção de arquivos de dependências extraídas

## Como Usar

### Instalação

```bash
# Clone o repositório
git clone https://github.com/thalesonunes/donedep.git
cd donedep

# Torne os scripts executáveis
chmod +x run.sh scripts/*.sh scripts/modules/*.sh

# Instale as dependências necessárias (opcional)
./scripts/install.sh
```

### Modo de Execução Rápida

A forma mais simples de usar o DoneDep é executando o script principal sem argumentos:

```bash
./run.sh
```

Este comando realiza automaticamente:
1. Verificação do ambiente
2. Extração de dependências dos repositórios
3. Inicialização do servidor web para visualização

Ideal para quem deseja um fluxo de trabalho simplificado sem precisar executar comandos separados.

### Comandos Específicos

Para quem precisa de um controle mais granular, é possível executar as etapas individualmente:

#### Extração de Dependências

O DoneDep oferece duas formas de analisar repositórios:

1. **Via arquivo `repos.txt`**:
   
   Adicione os repositórios Git que deseja analisar ao arquivo `repos.txt`, um por linha:
   ```
   https://github.com/user/projeto1.git
   https://github.com/user/projeto2.git
   /caminho/local/para/projeto3
   ```

2. **Via diretório `data/repo_cache`**:
   
   Coloque os repositórios diretamente no diretório `data/repo_cache/`. O DoneDep analisará automaticamente todos os projetos Java/Kotlin encontrados neste diretório.

Execute o script de extração:

```bash
./run.sh extract
```

#### Visualização de Dependências

Para iniciar a interface web:

```bash
./run.sh view
```

Ou manualmente:

```bash
python3 -m http.server 9786
# Acesse http://localhost:9786 no navegador
```

#### Verificação do Sistema

Para verificar se o ambiente possui todas as dependências necessárias:

```bash
./run.sh verify
```

## Arquitetura Técnica

### Sistema de Extração

O DoneDep utiliza uma arquitetura modular baseada em scripts Bash:

1. **Gerenciamento de Repositórios** (`repo_manager.sh`)
   - Clone e atualização de repositórios Git
   - Detecção de caminhos locais vs. URLs remotas

2. **Análise de Projetos** (`project_analyzer.sh`)
   - Detecção da estrutura do projeto (monolito, múltiplos módulos)
   - Identificação de arquivos de build relevantes

3. **Extração de Versões** (`version_extractor.sh`)
   - Identificação de versões Java, Kotlin, Gradle, Maven e Spring Boot
   - Normalização de formatos de versão
   - Suporte a padrões adicionais para detecção robusta de versões
   - Melhoria na extração de versões Java em arquivos Kotlin DSL

4. **Parsing de Dependências** (`dependency_parser.sh`)
   - Suporte completo para formatos Gradle (Groovy e Kotlin DSL) e Maven
   - Extração avançada de grupo, artefato, versão e configuração
   - Resolução inteligente de variáveis e propriedades (Gradle e Maven)
   - Suporte a padrões complexos como property(), ${}, Version Catalogs
   - Mapeamento automático de scopes Maven para configurações equivalentes

5. **Manipulação JSON** (`json_handler.sh`)
   - Formatação dos dados extraídos para JSON
   - Validação de integridade

### Fluxo de Processamento

1. Script principal (`main.sh`) orquestra o processo
2. Repositórios são clonados ou atualizados
3. Estrutura de cada projeto é analisada
4. Versões das tecnologias são extraídas
5. Dependências são identificadas e analisadas
6. Dados são formatados e validados
7. Resultado é salvo em `data/dependencies.json`

### Interface Web

A interface utiliza uma arquitetura modular em JavaScript:

1. **Núcleo da Aplicação**
   - `config.js` - Configurações globais
   - `api.js` - Comunicação com dados
   - `error-handler.js` - Tratamento centralizado de erros
   - `utils.js` - Funções utilitárias

2. **Adaptadores de Dados**
   - `data-adapter.js` - Conversão e normalização de dados

3. **Módulos Funcionais**
   - **Projetos** - Gerenciamento de informações dos projetos
   - **Dependências** - Visualização e manipulação de dependências
   - **Filtros** - Sistema de filtragem bidirecional
   - **UI** - Componentes de interface (modais, notificações)

4. **Fluxo de Dados**
   - Carregamento inicial via `app.js`
   - Filtros bidirecionais atualizam a visualização
   - Interações do usuário disparam atualizações de estado

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
        <scope>compile</scope>
    </dependency>
</dependencies>
```

## Sistemas de Build Suportados

O DoneDep oferece **suporte completo** para os principais sistemas de build do ecossistema Java/Kotlin, tratando cada um com funcionalidades equivalentes.

### Suporte ao Gradle

#### Funcionalidades Gradle Implementadas
- ✅ Extração de dependências de arquivos `build.gradle` e `build.gradle.kts`
- ✅ Suporte completo a Groovy DSL e Kotlin DSL
- ✅ Resolução de variáveis e propriedades (`${variable}`, `property()`)
- ✅ Suporte a Version Catalogs (libs.versions.toml)
- ✅ Detecção de versões do Gradle wrapper
- ✅ Análise de configurações (implementation, api, compileOnly, etc.)
- ✅ Suporte a projetos multi-módulo Gradle

#### Configurações Gradle Suportadas
- `implementation`, `api`, `compileOnly`, `runtimeOnly`
- `testImplementation`, `testCompileOnly`, `testRuntimeOnly`
- `annotationProcessor`, `kapt`

### Suporte ao Maven

#### Funcionalidades Maven Implementadas
- ✅ Extração de dependências de arquivos `pom.xml`
- ✅ Resolução de propriedades Maven (`${property.name}`)
- ✅ Detecção de versões do Spring Boot em projetos Maven
- ✅ Suporte a projetos multi-módulo Maven
- ✅ Detecção automática da versão Maven
- ✅ Análise de scopes Maven

#### Mapeamento de Scopes Maven
O DoneDep mapeia automaticamente os scopes Maven para configurações equivalentes:
- `compile` → `implementation`
- `test` → `testImplementation`
- `provided` → `compileOnly`
- `runtime` → `runtimeOnly`
- `import` → `platform`

### Detecção Automática
- ✅ **Detecção automática** do sistema de build por projeto
- ✅ **Suporte simultâneo** para repositórios com projetos Gradle e Maven
- ✅ **Filtros específicos** para cada sistema de build na interface web

## Formato de Saída JSON

O DoneDep gera um arquivo JSON com a seguinte estrutura:

```json
[
  {
    "project": "nome-do-projeto",
    "javaVersion": "17",
    "kotlinVersion": "1.9.10",
    "gradleVersion": "8.4-bin",
    "mavenVersion": "3.8.1",
    "springBootVersion": "3.0.4",
    "dependencies": [
      {
        "group": "org.springframework.boot",
        "name": "spring-boot-starter-web",
        "version": "3.0.4",
        "configuration": "implementation"
      },
      {
        "group": "com.fasterxml.jackson.module",
        "name": "jackson-module-kotlin",
        "version": "managed",
        "configuration": "implementation"
      }
    ]
  }
]
```

## Como Contribuir

Para contribuir com o DoneDep, siga estas etapas:

1. Faça um fork do repositório
2. Crie uma branch para sua feature: `git checkout -b minha-feature`
3. Implemente suas mudanças seguindo os princípios do projeto:
   - Código claro e legível
   - Comentários claros e descritivos
   - Manter a simplicidade e eficiência
4. Faça commit de suas alterações: `git commit -m 'Implementação: minha feature'`
5. Envie para o seu fork: `git push origin minha-feature`
6. Abra um Pull Request

### Áreas para Contribuição

- Suporte a mais sistemas de build (Ant, SBT, etc.)
- Melhorias na visualização e filtragem
- Otimizações na extração de dependências
- Documentação adicional
- Traduções para outros idiomas
- Correção de bugs e problemas

## Solução de Problemas

### Problemas Comuns

1. **Erro ao extrair dependências**
   - Verifique se os repositórios em `repos.txt` estão acessíveis
   - Confira se os projetos usam estruturas Gradle ou Maven compatíveis
   - Certifique-se de que os arquivos de build (build.gradle, build.gradle.kts, pom.xml) estão presentes

2. **Interface não carrega dependências**
   - Verifique se o arquivo `data/dependencies.json` foi gerado corretamente
   - Confira erros no console do navegador

3. **Variáveis não resolvidas**
   - As variáveis identificadas com ⚡ podem exigir configuração manual no arquivo de build

### Logs e Diagnóstico

O sistema mantém logs detalhados em `data/donedep.log` que podem ajudar a identificar problemas durante a extração.

## Ferramentas Auxiliares

### DoneDep Cleaner

O projeto inclui um script de limpeza (`cleaner.sh`) que permite remover arquivos de dependências extraídas e dados relacionados:

```bash
# Executar o script de limpeza
./cleaner.sh
```

Este script remove:
- Arquivos de dependências com timestamp (`dependencies_*.json`)
- Arquivo de listagem de dependências (`dependency-files-list.json`)
- Logs do sistema (`donedep.log`)
- Mantém o symlink `dependencies.json` apontando para um arquivo vazio

### Histórico de Versões

O sistema mantém automaticamente um histórico de extrações com timestamps, permitindo:
- Análise da evolução das dependências ao longo do tempo
- Comparação entre diferentes momentos de extração
- Seleção de versões específicas na interface web

Para listar todas as versões disponíveis:
```bash
ls -la data/dependencies*.json
```

## Lições Aprendidas

- Código simples é mais fácil de depurar e manter
- Excesso de validações e transformações pode introduzir novos bugs
- A solução mais eficaz é geralmente a mais direta
- Ferramentas devem ser simples e fazer bem sua tarefa principal
- A modularização adequada facilita a manutenção e evolução
- Scripts shell podem ser eficientes para tarefas específicas de análise
- Pair programming com IA requer supervisão ativa e correções frequentes
- O histórico de commits é um reflexo valioso do processo de desenvolvimento
- A qualidade do output da IA varia significativamente entre diferentes modelos e prompts
- A importância da identificação única de dependências incluindo configuração para contagens precisas
- Filtragem robusta deve considerar casos especiais como valores "NENHUM", null e undefined
- A visualização hierárquica (configuração abaixo do nome) melhora significativamente a experiência do usuário
- Melhorias incrementais baseadas em feedback real de uso são mais eficazes que grandes refatorações

## Aspectos Experimentais

Este projeto incorpora aspectos experimentais importantes que exploram novas abordagens de desenvolvimento:

**Uso de Shell Script como Backend**
- Exploração das capacidades do shell para parsing e análise de código
- Implementação de um sistema modular baseado em shell scripts
- Resolução complexa de variáveis e propriedades em diferentes formatos de build

**Desenvolvimento Assistido por IA (Pair Programming)**
- Integração de IA no fluxo de trabalho de desenvolvimento
- Experimentação com diferentes abordagens de prompting
- Avaliação da qualidade do código gerado com assistência de IA
- Iterações baseadas em análise de dados reais e feedback de uso
- Combinação da direção humana com sugestões de IA para desenvolvimento eficiente
- Supervisão humana essencial para manter qualidade e coerência da implementação

O processo de desenvolvimento com IA revelou tanto benefícios quanto desafios desta abordagem, demonstrando que a integração de criatividade humana com sugestões de código por IA pode ser eficaz quando adequadamente supervisionada.

**Melhorias Recentes (Maio 2025)**
- Implementação completa do suporte ao Maven equivalente ao Gradle
- Aprimoramento na exibição hierárquica de configurações de dependência
- Melhoria na lógica de filtragem para casos especiais
- Otimização na extração de versões Java para arquivos Kotlin DSL
- Implementação de contagem única baseada em configuração + dependência
- Adição do sistema de limpeza automática de arquivos extraídos
- Suporte unificado para projetos Gradle e Maven com detecção automática

---

**DoneDep** © 2025 | Desenvolvido para simplificar a gestão de dependências em ambientes de microsserviços
