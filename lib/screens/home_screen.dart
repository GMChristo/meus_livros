import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/book.dart';
import '../services/excel_service.dart';
import '../services/isbn_service.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ExcelService _excelService = ExcelService();
  final IsbnService _isbnService = IsbnService();

  List<List<String>> _books = [];
  bool _loading = true;
  bool _processingScan = false;
  bool _updatingAll = false;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _excelService.requestPermissions();
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final books = await _excelService.readAllBooks();
    final path = await _excelService.getFilePath();
    setState(() {
      _books = books.reversed.toList(); // mais recentes primeiro
      _filePath = path;
      _loading = false;
    });
  }

  Future<void> _updateAllBooks() async {
    if (_books.isEmpty) return;

    setState(() => _updatingAll = true);
    try {
      final n = _books.length;
      final List<MapEntry<int, Book>> updates = [];

      for (int i = 0; i < n; i++) {
        final row = _books[i];
        final isbn = row.isNotEmpty ? row[0] : null;
        if (isbn == null || isbn.isEmpty) continue;
        final existingObs = row.length > 7 ? row[7] : '-';

        try {
          var updatedBook = await _isbnService.lookup(isbn);
          // Preserva a observação manual existente
          updatedBook = updatedBook.copyWith(obs: existingObs);

          // Atualiza a lista na UI (para feedback imediato)
          setState(() {
            _books[i] = [
              updatedBook.isbn,
              updatedBook.title,
              updatedBook.subtitle,
              updatedBook.author,
              updatedBook.publisher,
              updatedBook.publishedDate,
              row.length > 6 ? row[6] : DateTime.now().toIso8601String(),
              updatedBook.obs,
            ];
          });

          final realIndex = n - 1 - i;
          updates.add(MapEntry(realIndex, updatedBook));
        } catch (e) {
          debugPrint('Erro ao atualizar livro ${row[0]}: $e');
        }
      }

      if (updates.isNotEmpty) {
        await _excelService.updateBooksBatch(updates);
      }

      await _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos os registros foram atualizados!')),
      );
    } finally {
      setState(() => _updatingAll = false);
    }
  }

  Future<void> _updateSingleBook(int index) async {
    final row = _books[index];
    final isbn = row.isNotEmpty ? row[0] : null;
    if (isbn == null || isbn.isEmpty) return;
    final existingObs = row.length > 7 ? row[7] : '-';

    try {
      var updatedBook = await _isbnService.lookup(isbn);
      // Preserva a observação manual existente
      updatedBook = updatedBook.copyWith(obs: existingObs);

      final n = _books.length;
      final realIndex = (n - 1) - index;

      setState(() {
        _books[index] = [
          updatedBook.isbn,
          updatedBook.title,
          updatedBook.subtitle,
          updatedBook.author,
          updatedBook.publisher,
          updatedBook.publishedDate,
          row.length > 6 ? row[6] : DateTime.now().toIso8601String(),
          updatedBook.obs,
        ];
      });

      await _excelService.updateBookAt(realIndex, updatedBook);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Livro atualizado: ${updatedBook.title}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar livro: $e')),
        );
      }
    }
  }

  Future<void> _showBookDetailsDialog(int index) async {
    final row = _books[index];
    final n = _books.length;
    final realIndex = (n - 1) - index;

    final isbnController = TextEditingController(text: row.isNotEmpty ? row[0] : '');
    final titleController = TextEditingController(text: row.length > 1 ? row[1] : '');
    final subtitleController = TextEditingController(text: row.length > 2 ? row[2] : '');
    final authorController = TextEditingController(text: row.length > 3 ? row[3] : '');
    final publisherController = TextEditingController(text: row.length > 4 ? row[4] : '');
    final dateController = TextEditingController(text: row.length > 5 ? row[5] : '');
    final obsController = TextEditingController(text: row.length > 7 ? row[7] : '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detalhes do Livro'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: isbnController,
                decoration: const InputDecoration(labelText: 'ISBN'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: subtitleController,
                decoration: const InputDecoration(labelText: 'Subtítulo'),
              ),
              TextField(
                controller: authorController,
                decoration: const InputDecoration(labelText: 'Autor'),
              ),
              TextField(
                controller: publisherController,
                decoration: const InputDecoration(labelText: 'Editora'),
              ),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'Ano de Publicação'),
              ),
              TextField(
                controller: obsController,
                decoration: const InputDecoration(labelText: 'Observações'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedBook = Book(
                isbn: isbnController.text,
                title: titleController.text,
                subtitle: subtitleController.text,
                author: authorController.text,
                publisher: publisherController.text,
                publishedDate: dateController.text,
                scannedAt: DateTime.now(),
                obs: obsController.text,
              );

              try {
                await _excelService.updateBookAt(realIndex, updatedBook);
                if (context.mounted) {
                  setState(() {
                    _books[index] = updatedBook.toRow();
                  });
                  Navigator.pop(ctx);
                  await _updateSingleBook(index);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao atualizar: $e')),
                  );
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBook(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover livro'),
        content: Text('Deseja realmente remover este livro da sua lista?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // _books está invertido, então o índice real no Excel é diferente
        // Lista original: [0, 1, 2, 3]
        // _books (invertido): [3, 2, 1, 0]
        // Se deletamos index 0 de _books, deletamos index 3 do original.
        final realIndex = (_books.length - 1) - index;
        await _excelService.deleteBookAt(realIndex);
        await _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Livro removido com sucesso')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover: $e')),
        );
      }
    }
  }

  Future<void> _scanAndSave() async {
    final isbn = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );

    if (isbn == null || !mounted) return;

    setState(() => _processingScan = true);

    try {
      final book = await _isbnService.lookup(isbn);
      await _excelService.addBook(book);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adicionado: ${book.title}')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) setState(() => _processingScan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meus Livros (${_books.length})'),
        actions: [
          IconButton(
            icon: _updatingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Atualizar todos os registros',
            onPressed: _updatingAll ? null : _updateAllBooks,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Abrir arquivo Excel',
            onPressed: _filePath == null
                ? null
                : () => OpenFilex.open(_filePath!),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _books.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'Nenhum livro escaneado ainda.\nToque no botão abaixo para começar.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: _books.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = _books[index];
                      final isbn = row.isNotEmpty ? row[0] : '-';
                      var title = row.length > 1 ? row[1] : '-';
                      final subtitle = row.length > 2 ? row[2] : '-';
                      final obs = row.length > 7 ? row[7] : '-';

                      // Lógica de exibição do título com Observações
                      if (title == 'Título não encontrado') {
                        if (obs != '-' && obs.isNotEmpty) {
                          title = obs;
                        }
                      } else if (obs != '-' && obs.isNotEmpty) {
                        title = '$title - $obs';
                      }

                      return ListTile(
                        leading: const Icon(Icons.menu_book),
                        title: Text(title),
                        subtitle: Text('$subtitle\nISBN $isbn'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.blue),
                              onPressed: () => _updateSingleBook(index),
                              tooltip: 'Atualizar este livro',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteBook(index),
                            ),
                          ],
                        ),
                        onTap: () => _showBookDetailsDialog(index),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _processingScan ? null : _scanAndSave,
        icon: _processingScan
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.qr_code_scanner),
        label: Text(_processingScan ? 'Salvando...' : 'Escanear livro'),
      ),
    );
  }
}
