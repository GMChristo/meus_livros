import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/book.dart';

/// Gerencia o arquivo livros.xlsx salvo localmente no dispositivo:
/// cria o arquivo se não existir, adiciona novas linhas e lê os
/// registros já salvos.
class ExcelService {
  static const String fileName = 'livros.xlsx';
  static const String sheetName = 'Livros';

  /// Pasta acessível/visível ao usuário (facilita depois sincronizar
  /// com Drive, transferir para o PC, etc).
  Future<Directory> _getStorageDirectory() async {
    if (Platform.isAndroid) {
      // Pasta pública de Documentos, visível no explorador de arquivos.
      final dir = Directory('/storage/emulated/0/Documents/LivrosApp');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    // iOS e outras plataformas: usa o diretório de documentos do app.
    return getApplicationDocumentsDirectory();
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return true;
      // Fallback para versões mais antigas do Android.
      final legacy = await Permission.storage.request();
      return legacy.isGranted;
    }
    return true;
  }

  Future<File> _getFile() async {
    final dir = await _getStorageDirectory();
    return File('${dir.path}/$fileName');
  }

  /// Garante que o arquivo existe com o cabeçalho correto e retorna o Excel.
  Future<Excel> _loadOrCreateWorkbook() async {
    final file = await _getFile();

    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      return Excel.decodeBytes(bytes);
    }

    final excel = Excel.createExcel();
    // Remove a aba padrão "Sheet1" e cria a nossa.
    excel.rename(excel.getDefaultSheet()!, sheetName);
    final sheet = excel[sheetName];
    sheet.appendRow(Book.headers.map((h) => TextCellValue(h)).toList());
    return excel;
  }

  /// Adiciona um livro ao final da planilha e salva no disco.
  /// Retorna o caminho completo do arquivo salvo.
  Future<String> addBook(Book book) async {
    final excel = await _loadOrCreateWorkbook();
    final sheet = excel[sheetName];

    sheet.appendRow(
      book.toRow().map((value) => TextCellValue(value)).toList(),
    );

    final file = await _getFile();
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Falha ao gerar o arquivo Excel.');
    }
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Lê todos os livros já salvos (ignora a linha de cabeçalho).
  Future<List<List<String>>> readAllBooks() async {
    final file = await _getFile();
    if (!await file.exists()) return [];

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel[sheetName];

    final rows = <List<String>>[];
    for (var i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      rows.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
    }
    return rows;
  }

  Future<String> getFilePath() async {
    final file = await _getFile();
    return file.path;
  }

  Future<bool> fileExists() async {
    final file = await _getFile();
    return file.exists();
  }

  /// Atualiza múltiplos livros de uma vez e salva o arquivo apenas no final.
  /// [updates] deve ser uma lista de pares (índice, livro).
  Future<void> updateBooksBatch(List<MapEntry<int, Book>> updates) async {
    final file = await _getFile();
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel[sheetName];

    for (var entry in updates) {
      final index = entry.key;
      final book = entry.value;
      final rowIndex = index + 1;

      if (rowIndex < sheet.maxRows) {
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex), TextCellValue(book.isbn));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex), TextCellValue(book.title));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex), TextCellValue(book.subtitle));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex), TextCellValue(book.author));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex), TextCellValue(book.publisher));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex), TextCellValue(book.publishedDate));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex), TextCellValue(book.scannedAt.toIso8601String()));
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex), TextCellValue(book.obs));
      }
    }

    final updatedBytes = excel.encode();
    if (updatedBytes == null) {
      throw Exception('Falha ao gerar o arquivo Excel.');
    }
    await file.writeAsBytes(updatedBytes, flush: true);
  }

  /// Remove uma linha pelo índice (0-based, sem contar cabeçalho) e salva.
  Future<void> deleteBookAt(int index) async {
    final file = await _getFile();
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel[sheetName];

    // index+1 porque a linha 0 é o cabeçalho
    final rowIndex = index + 1;
    if (rowIndex < sheet.maxRows) {
      sheet.removeRow(rowIndex);
    }

    final updatedBytes = excel.encode();
    if (updatedBytes == null) {
      throw Exception('Falha ao gerar o arquivo Excel.');
    }
    await file.writeAsBytes(updatedBytes, flush: true);
  }

  /// Atualiza uma linha pelo índice (0-based, sem contar cabeçalho) com os dados do livro fornecido.
  Future<void> updateBookAt(int index, Book book) async {
    final file = await _getFile();
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel[sheetName];

    // index+1 porque a linha 0 é o cabeçalho
    final rowIndex = index + 1;
    if (rowIndex < sheet.maxRows) {
      // Atualiza cada célula da linha
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex), TextCellValue(book.isbn));
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex), TextCellValue(book.title));
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex), TextCellValue(book.subtitle));
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex), TextCellValue(book.author));
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex), TextCellValue(book.publisher));
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex), TextCellValue(book.publishedDate));
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex), TextCellValue(book.scannedAt.toIso8601String()));
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex), TextCellValue(book.obs));
    }

    final updatedBytes = excel.encode();
    if (updatedBytes == null) {
      throw Exception('Falha ao gerar o arquivo Excel.');
    }
    await file.writeAsBytes(updatedBytes, flush: true);
  }
}
