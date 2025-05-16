<p align="center">
  <img src="assets/jone-dep-logo.svg" alt="JoneDep Logo" width="400"/>
</p>

# JoneDep - Gerenciador de Dependências de Microsserviços

JoneDep é uma ferramenta para extrair e visualizar dependências de projetos Java/Kotlin com Gradle. Ela permite identificar facilmente quais dependências são usadas em diferentes projetos e com quais combinações de tecnologias (Java, Kotlin, Gradle, Spring Boot).

## Estrutura do Projeto

```
├── assets/               # Arquivos de imagem e recursos
│   └── jone-dep-logo.svg # Logo do JoneDep
├── css/                  # Arquivos de estilo
│   └── style.css         # Estilos da aplicação
├── data/                 # Dados da aplicação
│   └── dependencies.json # Arquivo com dependências extraídas
├── js/                   # Arquivos JavaScript
│   └── app.js            # Lógica principal da aplicação
├── extract_dependencies.sh # Script de extração
├── index.html            # Página principal da aplicação
├── README.md             # Este arquivo de documentação
└── repos.txt             # Lista de repositórios para extração
```

## Funcionalidades

- **Extração automatizada de dependências** de múltiplos projetos Git
- **Interface web interativa** para filtrar e visualizar dependências
- **Filtros inteligentes bidirecionais** que se atualizam dinamicamente
- **Cópia fácil** de dependências para uso em novos projetos
- **Detecção automática** de versões Java, Kotlin, Gradle e Spring Boot

## Instalação

### Pré-requisitos

Para o script de extração:
- `bash` (versão 4 ou superior)
- `git`
- `grep`
- `sed`
- `jq` (opcional, para JSON formatado)

Para a interface web:
- Um navegador web moderno
- Python 3 (para o servidor web local) ou qualquer outro servidor HTTP

## Como Usar

### 1. Configuração dos Repositórios

Edite o arquivo `repos.txt` e adicione uma URL de repositório Git por linha:

```
https://github.com/usuario/projeto1.git
https://github.com/usuario/projeto2.git
https://github.com/organizacao/outro-projeto.git
```

### 2. Execução do Script de Extração

Execute o script para extrair as dependências dos repositórios:

```bash
# Dê permissão de execução ao script (apenas na primeira vez)
chmod +x extract_dependencies.sh

# Execute o script passando o arquivo com as URLs
./extract_dependencies.sh repos.txt
```

O script irá:
- Clonar cada repositório especificado
- Analisar arquivos de configuração Gradle
- Extrair versões de Java, Kotlin, Gradle e Spring Boot
- Extrair todas as dependências declaradas
- Gerar o arquivo `dependencies.json` com todas as informações

### 3. Inicializando a Interface Web

Para visualizar as dependências na interface web, você precisa iniciar um servidor HTTP local. É recomendável usar uma porta específica para evitar conflitos com outras aplicações:

```bash
# Opção 1: Usando Python 3 (com porta 9687)
python3 -m http.server 9687

# Opção 2: Usando Python 2 (com porta 9687)
python -m SimpleHTTPServer 9687
```

Depois, abra seu navegador e acesse:
```
http://localhost:9687
```

> **Nota**: Você pode escolher qualquer porta disponível (como 9687, 8080, 3000, etc). Se preferir outra porta, basta alterar o número na linha de comando e na URL do navegador.

### 4. Utilizando a Interface Web

A interface permite:

- **Filtrar** dependências por versão de Java, Kotlin, Gradle e Spring Boot
- **Buscar** dependências por nome ou grupo
- **Copiar** declarações de dependências individuais
- **Copiar todas** as dependências filtradas de uma vez

#### Filtros

Os filtros são bidirecionais - ao selecionar um filtro, os outros filtros serão atualizados para mostrar apenas combinações válidas. Por exemplo, ao selecionar Java 11, apenas as versões de Gradle compatíveis serão exibidas.

Para limpar todos os filtros, clique no botão "X" ao lado dos filtros.

#### Busca

Digite termos de busca na caixa de pesquisa para encontrar dependências específicas. A busca considera tanto o nome quanto o grupo da dependência.

#### Cópia

- Para copiar uma dependência individual, clique no botão de cópia ao lado dela
- Para copiar todas as dependências filtradas atualmente, clique no botão "COPIAR LISTA COMPLETA"

## Atualizando Dependências

Para atualizar as informações quando os repositórios forem modificados, simplesmente execute o script novamente:

```bash
./extract_dependencies.sh repos.txt
```

E recarregue a página no navegador.

## Resolução de Problemas

### O script apresenta erros ao clonar repositórios

- Verifique se as URLs no arquivo `repos.txt` estão corretas
- Confirme se você tem acesso aos repositórios (especialmente se forem privados)
- Verifique se o Git está instalado e configurado corretamente

### A interface web não mostra as dependências

- Certifique-se de que o arquivo `dependencies.json` foi gerado corretamente
- Verifique se o servidor HTTP local está em execução
- Use as ferramentas de desenvolvedor do navegador para verificar erros de console

### Erro "porta já está em uso"

Se ao iniciar o servidor Python você receber um erro como "Address already in use", significa que a porta escolhida já está sendo utilizada por outra aplicação. Nesse caso:

```bash
# Tente com outra porta, por exemplo, 9688
python3 -m http.server 9688
```

E acesse http://localhost:9688 no navegador

### O filtro não mostra todas as combinações esperadas

- O filtro apenas exibe combinações que existem nos dados extraídos
- Se uma combinação não aparece, é porque não existe nenhum projeto com essa configuração específica

## Observações

- O script gera dados de exemplo se nenhum repositório for informado
- A interface foi otimizada para visualização em dispositivos desktop e móveis
