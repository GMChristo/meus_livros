# Livros App

App para escaneamento de livros via código de barras (ISBN), consulta automática de dados em APIs bibliográficas e persistência dos registros em uma planilha Excel local.

## 🚀 Visão Geral

O **Livros App** permite que o usuário catalogue sua biblioteca pessoal de forma rápida. Ao escanear o código de barras de um livro, a aplicação busca automaticamente informações como título, autor, editora e data de publicação em múltiplas fontes, salvando esses dados em um arquivo `.xlsx` acessível no dispositivo.

## 🛠 Tecnologias

- **Framework**: [Flutter](https://flutter.dev/)
- **Linguagem**: [Dart](https://dart.dev/)
- **Persistência**: [excel](https://pub.dev/packages/excel) (Arquivos .xlsx)
- **API HTTP**: [http](https://pub.dev/packages/http)
- **Scanner**: [mobile_scanner](https://pub.dev/packages/mobile_scanner)
- **Utilitários**:
    - `path_provider`: Localização de pastas no sistema.
    - `permission_handler`: Gestão de permissões de câmera e armazenamento.
    - `open_filex`: Abertura do arquivo gerada no app padrão do sistema.
    - `html`: Parsing de conteúdo HTML (legado/auxiliar).

## 🏗 Arquitetura

A aplicação segue uma arquitetura simples e direta, focada em serviços e telas, sem a utilização de frameworks de gerenciamento de estado complexos.

### Fluxo de Dados
A aplicação opera no seguinte fluxo:
`UI (Screens)` $\rightarrow$ `Services (Business Logic)` $\rightarrow$ `Data Sources (Excel/APIs)`

### Responsabilidades
- **Models**: Definição da estrutura de dados (`Book`).
- **Services**: Lógica de negócio isolada.
    - `IsbnService`: Responsável pela orquestração de buscas em APIs externas.
    - `ExcelService`: Responsável por toda a manipulação do arquivo local.
- **Screens**: Interfaces de usuário e controle de estado local via `setState`.

## 📁 Estrutura do Projeto

```text
lib/
├── main.dart               # Ponto de entrada da aplicação
├── models/
│   └── book.dart           # Modelo de dados do livro e definição de colunas do Excel
├── screens/
│   ├── home_screen.dart     # Lista de livros, gestão de registros e modal de edição
│   └── scanner_screen.dart # Interface de captura do código de barras
└── services/
    ├── excel_service.dart   # Manipulação de arquivos .xlsx e permissões de disco
    └── isbn_service.dart    # Lógica de fallback de busca (CBL $\rightarrow$ Google $\rightarrow$ OpenLibrary)
```

## ⚙️ Fluxo de Inicialização

1. `main()`: Inicia a aplicação e carrega o `LivrosApp`.
2. `HomeScreen`: É a tela inicial. No `initState`, executa o método `_init()`.
3. `_init()`:
    - Solicita permissões de armazenamento via `ExcelService`.
    - Executa `_refresh()` para ler os livros já salvos no arquivo Excel e atualizar a lista na tela.

## 🗺 Navegação

A navegação é realizada de forma direta via `Navigator`:
- **Home $\rightarrow$ Scanner**: Através do `FloatingActionButton` que abre a `ScannerScreen`.
- **Scanner $\rightarrow$ Home**: Retorna o ISBN detectado via `Navigator.pop(context, code)`.
- **Home $\rightarrow$ Modal**: Abre um `AlertDialog` para edição detalhada de cada registro.

## 🔄 Gerenciamento de Estado

O projeto utiliza o gerenciamento de estado nativo do Flutter:
- **`setState`**: Utilizado dentro dos `StatefulWidgets` para atualizar a lista de livros, indicadores de carregamento e status de processamento.
- **Sincronização**: A lista exibida na tela (`_books`) é uma representação invertida (mais recentes primeiro) dos dados lidos do Excel.

## 🌐 Comunicação com APIs

O `IsbnService` implementa uma cadeia de fallback para garantir que o máximo de informações seja recuperado:

1. **CBL Serviços**: API prioritária para livros brasileiros.
2. **Google Books API**: Segunda opção para busca global.
3. **Open Library API**: Terceira opção, focada em livros internacionais e sem limites rígidos de quota.

**Fluxo de Consulta:**
`ISBN` $\rightarrow$ `IsbnService.lookup()` $\rightarrow$ `API Request` $\rightarrow$ `JSON Parsing` $\rightarrow$ `Book Model` $\rightarrow$ `UI`.

## 💾 Persistência

Os dados são salvos em um arquivo chamado `livros.xlsx`.

- **Localização (Android)**: `/storage/emulated/0/Documents/LivrosApp/livros.xlsx` (Pasta pública de Documentos).
- **Localização (Outros)**: Diretório de documentos privado do app via `path_provider`.
- **Operações**:
    - **Leitura**: Lê todas as linhas ignorando o cabeçalho.
    - **Escrita**: Adiciona novas linhas ao final da planilha.
    - **Atualização**: Localiza a linha pelo índice real e atualiza as células individualmente.
    - **Exclusão**: Remove a linha específica do arquivo.

## 📘 Models e Entidades

### Classe `Book`
Representa a entidade principal do sistema. Possui os campos:
- `isbn`, `title`, `subtitle`, `author`, `publisher`, `publishedDate`, `scannedAt`, `obs`.

**Conversões:**
- `toRow()`: Converte o objeto `Book` em uma `List<String>` compatível com as colunas do Excel.
- `headers`: Define os nomes das colunas da planilha.

## 🎨 Tema e Identidade Visual

O app utiliza **Material Design 3** com as seguintes configurações:
- **Cor Principal**: `Colors.teal` (via `colorSchemeSeed`).
- **Estilo**: Interface limpa com `ListTile` para os cards de livros e `AlertDialog` para edições.

## ⚙️ Configurações

- **API Keys**: A chave de API do CBL Serviços está configurada internamente no `IsbnService`.
- **Permissões**: Requer `MANAGE_EXTERNAL_STORAGE` (Android) para salvar arquivos na pasta de Documentos.

## 🚀 Como executar

### Requisitos
- Flutter SDK $\ge$ 3.3.0
- Android SDK / Xcode (dependendo da plataforma)

### Passos
```bash
# Instalar dependências
flutter pub get

# Executar a aplicação
flutter run
```

## 🛠 Como adicionar uma nova funcionalidade

Para implementar novas funcionalidades, siga o padrão existente:

1. **Modelo**: Se a funcionalidade exigir novos dados, adicione o campo em `lib/models/book.dart` e atualize o `toRow()` e `headers`.
2. **Serviço**: Se envolver persistência ou API, crie a lógica em `lib/services/`.
3. **UI**: Adicione a interface em `lib/screens/` ou crie novos widgets.
4. **Integração**: Conecte a UI ao serviço e use `setState` para atualizar a tela.

**Exemplo (Adição do campo 'Obs')**:
`Book model` $\rightarrow$ `ExcelService (updateCell)` $\rightarrow$ `HomeScreen (TextField no modal)` $\rightarrow$ `HomeScreen (Lógica de exibição no card)`.

## 🌟 Funcionalidades Implementadas

- [x] Escaneamento de ISBN via Câmera.
- [x] Busca automática em 3 APIs diferentes com fallback.
- [x] Persistência em arquivo Excel (.xlsx).
- [x] Listagem de livros com ordenação por data (mais recentes primeiro).
- [x] Edição manual de todos os campos do livro via modal.
- [x] Atualização individual e em lote de registros.
- [x] Exclusão de registros com confirmação.
- [x] Abertura do arquivo Excel no app externo.
- [x] Campo de Observações com lógica de exibição condicional no título.

## ⚠️ Pontos de Atenção

- **Índices do Excel**: O app utiliza a lógica `realIndex = (total - 1) - index` para mapear a lista invertida da UI para a linha correta no arquivo Excel.
- **Quota de API**: O Google Books pode retornar erro `429 (Too Many Requests)`, por isso a implementação do fallback é crítica.
- **Permissões Android**: Em versões recentes do Android, a permissão de armazenamento externo é rigorosa; o app solicita `manageExternalStorage`.
