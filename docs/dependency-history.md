# Histórico de Dependências no DoneDep

O DoneDep agora mantém um histórico de dependências ao longo do tempo, permitindo visualizar e comparar as dependências extraídas em diferentes momentos.

## Funcionamento

Cada vez que o script de extração de dependências é executado (`run.sh extract` ou `scripts/main.sh`), um novo arquivo JSON é criado com um timestamp no nome:

```
dependencies_YYYYMMDD_HHMMSS.json
```

Por exemplo: `dependencies_20250523_143012.json` para uma extração realizada em 23/05/2025 às 14:30:12.

Um arquivo simbólico (symlink) chamado `dependencies.json` sempre aponta para o arquivo mais recente, garantindo compatibilidade com código existente.

## Visualizando o Histórico

A interface web agora inclui um seletor de versões no canto superior direito que permite escolher entre diferentes extrações de dependências. O seletor mostra a data e hora completa no formato YYYY-MM-DD HH:MM:SS para identificação precisa do momento da extração.

Ao selecionar uma versão diferente, a visualização será atualizada imediatamente para mostrar os dados desse momento específico, permitindo a análise de como as dependências evoluíram ao longo do tempo.

## Administração

O sistema mantém automaticamente apenas os 10 arquivos mais recentes para evitar ocupar muito espaço em disco.

Para listar todos os arquivos de dependência disponíveis:

```bash
ls -la data/dependencies*.json
```

Para verificar para qual arquivo aponta o symlink:

```bash
ls -la data/dependencies.json
```

## Arquivos e Sistema

A listagem dos arquivos de dependência é feita diretamente pela interface web, que busca os arquivos no diretório `data/`. O formato do nome dos arquivos (`dependencies_YYYYMMDD_HHMMSS.json`) permite identificar facilmente a data e hora de cada extração.

Cada arquivo contém:
- path: Caminho relativo para o arquivo (ex: `data/dependencies_20250523_170643.json`)
- name: Nome do arquivo com timestamp
- date: Data da extração no formato YYYY-MM-DD HH:MM:SS

## Implementação

A implementação inclui:
1. Geração de nomes de arquivo baseados em timestamp
2. Criação de symlink para o arquivo mais recente
3. Interface para seleção do arquivo histórico
4. Limpeza automática de arquivos antigos (mantendo apenas os 10 mais recentes)
5. Sistema de listagem direta dos arquivos da pasta data/

O script `update_file_list.sh` é responsável por manter o symlink `dependencies.json` sempre apontando para o arquivo mais recente.

Esta funcionalidade permite acompanhar a evolução das dependências dos projetos ao longo do tempo, facilitando análises de tendências e identificação de mudanças.
