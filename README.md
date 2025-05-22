<p align="center">
  <img src="assets/jone-dep-logo.svg" alt="JoneDep Logo" width="400"/>
</p>

# JoneDep - Gerenciador de Dependências de Microsserviços

JoneDep é uma ferramenta simples e direta para visualizar e gerenciar dependências de projetos Java/Kotlin com Gradle e Maven. Projetada para ambientes com múltiplos microsserviços, ela permite identificar facilmente quais dependências são usadas em diferentes projetos e com quais combinações de tecnologias (Java, Kotlin, Gradle, Spring Boot).

## Filosofia do Projeto

Este projeto foi desenvolvido com foco em simplicidade e funcionalidade objetiva. A ferramenta foi construída para realizar duas tarefas essenciais com máxima eficiência:

1. **Extração de dependências** - através de scripts shell diretos e eficazes
2. **Visualização interativa** - com interface web responsiva e intuitiva

O projeto também serviu como um experimento de **desenvolvimento em pair programming com múltiplos agentes de IA**, demonstrando tanto os benefícios quanto os desafios dessa abordagem. O histórico de commits evidencia tanto avanços rápidos quanto a necessidade de frequentes correções devido às limitações dos diferentes modelos utilizados.

A escolha de scripts shell para o backend foi uma decisão experimental, visando o aprendizado e exploração das capacidades desta tecnologia em cenários de automação de análise de código. Esta decisão também permitiu avaliar como diferentes agentes de IA lidam com tecnologias menos comuns em seus dados de treinamento.

Durante o desenvolvimento, priorizamos a clareza e a manutenibilidade do código, evitando:
- Duplicação de arquivos e funcionalidades
- Validações desnecessárias para casos raros
- Complexidade excessiva em transformações de dados
- Abstrações que dificultam a compreensão do código
- Acúmulo de arquivos temporários ou de backup

## Estrutura do Projeto

```
├── assets/               # Recursos visuais e imagens
│   ├── jone-dep-logo-bk.svg # Logo backup do JoneDep
│   └── jone-dep-logo.svg    # Logo principal do JoneDep
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
│   ├── jone-dep.log      # Arquivo de log
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

O JoneDep oferece um conjunto focado de funcionalidades para facilitar o gerenciamento de dependências:

**Extração de Dados**
- Detecção automática de versões do Java, Kotlin, Gradle e Spring Boot
- Suporte a sistemas de build Gradle (Groovy e Kotlin DSL) e Maven
- Identificação e processamento de variáveis em arquivos de build
- Análise paralela de múltiplos repositórios e projetos

**Visualização e Filtragem**
- Sistema de filtros bidirecionais com atualização dinâmica
- Busca rápida por texto em nomes de dependências e grupos
- Exibição de todos os projetos que utilizam cada dependência
- Visualização organizada por categorias tecnológicas
- Interface totalmente em português

**Utilitários**
- Cópia com um clique de dependências em formatos Gradle e Maven
- Ordenação inteligente de diferentes formatos de versão
- Destaque visual para variáveis não resolvidas
- Sistema de notificações e modais para feedback de ações
- Design responsivo com animações consistentes para melhor UX

## Desenvolvimento com IA

O JoneDep representa um caso de estudo inovador em desenvolvimento colaborativo entre humanos e IA. Todo o projeto foi desenvolvido utilizando uma abordagem de pair programming com assistentes de IA, explorando novas fronteiras em:

- **Colaboração homem-máquina** - Fluxo de trabalho que combina criatividade humana com assistência de IA
- **Resolução de problemas em tempo real** - Uso de IA para superar desafios de implementação
- **Refatoração inteligente** - Otimização de código com sugestões assistidas por IA
- **Documentação aprimorada** - Geração e refinamento colaborativo da documentação

### Desafios e Lições do Desenvolvimento com IA

Durante o processo de desenvolvimento, foram utilizados diversos agentes e modelos de IA, o que trouxe tanto benefícios quanto desafios significativos:

- **Limitações dos diferentes modelos** - Os agentes de IA apresentaram capacidades variadas e limitações específicas
- **Inconsistências de implementação** - O histórico de commits revela numerosas correções necessárias devido a equívocos dos modelos
- **Aprendizado iterativo** - O processo exigiu refinamento contínuo das instruções fornecidas aos agentes de IA
- **Valor da supervisão humana** - A revisão e direcionamento por humanos foram essenciais para manter a qualidade do código

Apesar dos desafios, este método de desenvolvimento permitiu uma implementação relativamente rápida e eficiente. A experiência demonstra tanto o potencial quanto as limitações atuais da programação assistida por IA, oferecendo valiosas lições sobre como integrar estas ferramentas no fluxo de desenvolvimento de software.

## Histórico de Atualizações

**Interface em Português (22/05/2025)**
- Tradução completa de textos e mensagens do sistema
- Padronização das animações de botões em toda a interface
- Melhorias no layout e na responsividade

**Sistema de Filtragem (20/05/2025)**
- Correção na ordenação de diferentes formatos de versões Java
- Preservação do estado dos filtros durante navegação
- Melhoria na exibição das opções de filtragem

**Simplificação do Frontend (20/05/2025)**
- Refatoração do sistema de comparação de versões
- Otimização de funções para melhor desempenho
- Reorganização do código em uma estrutura modular

## Como Usar

### Instalação

```bash
# Clone o repositório
git clone https://github.com/thalesonunes/jone-dep.git
cd jone-dep

# Torne os scripts executáveis
chmod +x run.sh scripts/*.sh scripts/modules/*.sh

# Instale as dependências necessárias (opcional)
./scripts/install.sh
```

### Extração de Dependências

O JoneDep oferece duas formas de analisar repositórios:

1. **Via arquivo `repos.txt`**:
   
   Adicione os repositórios Git que deseja analisar ao arquivo `repos.txt`, um por linha:
   ```
   https://github.com/user/projeto1.git
   https://github.com/user/projeto2.git
   /caminho/local/para/projeto3
   ```

2. **Via diretório `data/repo_cache`**:
   
   Coloque os repositórios diretamente no diretório `data/repo_cache/`. O JoneDep analisará automaticamente todos os projetos Java/Kotlin encontrados neste diretório.

Execute o script de extração:

```bash
./run.sh extract
```

### Visualização de Dependências

Para iniciar a interface web:

```bash
./run.sh view
```

Ou manualmente:

```bash
python3 -m http.server 9786
# Acesse http://localhost:9786 no navegador
```

### Verificação do Sistema

Para verificar se o ambiente possui todas as dependências necessárias:

```bash
./run.sh verify
```

## Arquitetura Técnica

### Sistema de Extração

O JoneDep utiliza uma arquitetura modular baseada em scripts Bash:

1. **Gerenciamento de Repositórios** (`repo_manager.sh`)
   - Clone e atualização de repositórios Git
   - Detecção de caminhos locais vs. URLs remotas

2. **Análise de Projetos** (`project_analyzer.sh`)
   - Detecção da estrutura do projeto (monolito, múltiplos módulos)
   - Identificação de arquivos de build relevantes

3. **Extração de Versões** (`version_extractor.sh`)
   - Identificação de versões Java, Kotlin, Gradle e Spring Boot
   - Normalização de formatos de versão

4. **Parsing de Dependências** (`dependency_parser.sh`)
   - Suporte para formatos Gradle (Groovy e Kotlin DSL) e Maven
   - Extração de grupo, artefato, versão e configuração

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
    </dependency>
</dependencies>
```

## Formato de Saída JSON

O JoneDep gera um arquivo JSON com a seguinte estrutura:

```json
[
  {
    "project": "nome-do-projeto",
    "path": "/caminho/para/o/projeto",
    "javaVersion": "17",
    "kotlinVersion": "1.8.0",
    "gradleVersion": "8.0.1",
    "springBootVersion": "3.0.4",
    "modules": ["módulo1", "módulo2"],
    "dependencies": [
      {
        "group": "org.springframework.boot",
        "name": "spring-boot-starter-web",
        "version": "3.0.4",
        "configuration": "implementation"
      }
    ]
  }
]
```

## Como Contribuir

Para contribuir com o JoneDep, siga estas etapas:

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

2. **Interface não carrega dependências**
   - Verifique se o arquivo `data/dependencies.json` foi gerado corretamente
   - Confira erros no console do navegador

3. **Variáveis não resolvidas**
   - As variáveis identificadas com ⚡ podem exigir configuração manual no arquivo de build

### Logs e Diagnóstico

O sistema mantém logs detalhados em `data/jone-dep.log` que podem ajudar a identificar problemas durante a extração.

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

## Aspectos Experimentais

Este projeto incorpora diversos aspectos experimentais que serviram como oportunidades de aprendizado:

**Uso de Shell Script como Backend**
- Exploração das capacidades do shell para parsing e análise de código
- Avaliação da eficiência de scripts shell para extração de metadados de projetos
- Implementação de um sistema modular baseado em shell scripts

**Desenvolvimento Assistido por IA**
- Análise do impacto da IA no fluxo de trabalho de desenvolvimento
- Experimentação com diferentes abordagens de prompting
- Avaliação da qualidade e eficiência do código gerado com assistência de IA
- Identificação de padrões de erro comuns em diferentes modelos de IA
- Documentação das limitações e pontos fortes de diferentes agentes de IA

---

**JoneDep** © 2025 | Desenvolvido para simplificar a gestão de dependências em ambientes de microsserviços
