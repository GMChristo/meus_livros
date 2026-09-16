import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/book.dart';

/// Serviço de consulta ISBN com múltiplas fontes de fallback.
/// Ordem de busca: CBL (Brasil) -> Google Books -> Open Library (Internacional).
class IsbnService {
  static const String _googleBaseUrl = 'https://www.googleapis.com/books/v1/volumes';
  static const String _openLibraryBaseUrl = 'https://openlibrary.org/api/books';
  static const String _cblApiUrl = 'https://isbn-search-br.search.windows.net/indexes/isbn-index/docs/search?api-version=2016-09-01';
  static const String _cblApiKey = '100216A23C5AEE390338BBD19EA86D29';

  Future<Book> lookup(String isbn) async {
    final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    debugPrint('[IsbnService] --- INICIANDO BUSCA PARA ISBN: $cleanIsbn ---');

    // Tentativa 1: CBL Serviços (API Direta - Melhor para livros brasileiros)
    try {
      final cblBook = await _lookupCblServicos(cleanIsbn);
      if (cblBook.title != 'Título não encontrado' &&
          cblBook.title != '-' &&
          cblBook.author != '-') {
        debugPrint('[IsbnService] ✅ SUCESSO: Encontrado no CBL Serviços');
        return cblBook;
      }
    } catch (e) {
      debugPrint('[IsbnService] ❌ Erro no CBL: $e');
    }

    // Tentativa 2: Google Books API (Pode dar erro 429 de quota)
    try {
      final googleBook = await _lookupGoogleBooks(cleanIsbn);
      if (googleBook.title != 'Título não encontrado' &&
          googleBook.title != '-' &&
          googleBook.author != '-') {
        debugPrint('[IsbnService] ✅ SUCESSO: Encontrado no Google Books');
        return googleBook;
      }
    } catch (e) {
      debugPrint('[IsbnService] ❌ Erro no Google Books: $e');
    }

    // Tentativa 3: Open Library API (Internacional, gratuito e sem quota)
    try {
      final olBook = await _lookupOpenLibrary(cleanIsbn);
      if (olBook.title != 'Título não encontrado' &&
          olBook.title != '-' &&
          olBook.author != '-') {
        debugPrint('[IsbnService] ✅ SUCESSO: Encontrado no Open Library');
        return olBook;
      }
    } catch (e) {
      debugPrint('[IsbnService] ❌ Erro no Open Library: $e');
    }

    debugPrint('[IsbnService] ⚠️ Nenhuma fonte encontrou dados para $cleanIsbn');
    return Book.isbnOnly(cleanIsbn);
  }

  Future<Book> _lookupCblServicos(String isbn) async {
    final uri = Uri.parse(_cblApiUrl);
    debugPrint('[IsbnService] Consultando API Interna CBL...');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'api-key': _cblApiKey,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36',
        },
        body: jsonEncode({
          "searchMode": "any",
          "searchFields": "FormattedKey,RowKey,Authors,Title,Imprint",
          "queryType": "full",
          "search": isbn,
          "top": 1,
          "select": "Authors,Imprint,Title,Ano,Subtitle",
          "skip": 0,
          "count": true,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[IsbnService] Erro HTTP CBL: ${response.statusCode}');
        return Book.isbnOnly(isbn);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final value = data['value'] as List<dynamic>?;

      if (value == null || value.isEmpty) {
        debugPrint('[IsbnService] CBL: Nenhum resultado para este ISBN');
        return Book.isbnOnly(isbn);
      }

      final bookData = value.first as Map<String, dynamic>;

      // Função auxiliar para tratar campos que podem vir como String ou List
      String formatField(dynamic field) {
        if (field == null) return '-';
        if (field is List) return field.join(', ');
        return field.toString();
      }

      final titleRaw = formatField(bookData['Title']);
      final authorRaw = formatField(bookData['Authors']);
      final publisherRaw = formatField(bookData['Imprint']);
      final publishedDateRaw = formatField(bookData['Ano']);
      final subtitleRaw = formatField(bookData['Subtitle']);
      final title = titleRaw == '-' ? 'Título não encontrado' : titleRaw;

      return Book(
        isbn: isbn,
        title: title,
        subtitle: subtitleRaw,
        author: authorRaw,
        publisher: publisherRaw,
        publishedDate: publishedDateRaw,
        scannedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[IsbnService] Erro na requisição CBL: $e');
      return Book.isbnOnly(isbn);
    }
  }

  Future<Book> _lookupGoogleBooks(String isbn) async {
    final uri = Uri.parse('$_googleBaseUrl?q=isbn:$isbn');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return Book.isbnOnly(isbn);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return Book.isbnOnly(isbn);

      final volumeInfo = items.first['volumeInfo'] as Map<String, dynamic>? ?? {};
      final authorsList = volumeInfo['authors'] as List<dynamic>?;

      final title = volumeInfo['title'] as String? ?? 'Título não encontrado';
      final author = authorsList != null ? authorsList.join(', ') : '-';
      final publisher = volumeInfo['publisher'] as String? ?? '-';
      final publishedDate = volumeInfo['publishedDate'] as String? ?? '-';
      final subtitle = volumeInfo['subtitle'] as String? ?? '-';

      return Book(
        isbn: isbn,
        title: title,
        subtitle: subtitle,
        author: author,
        publisher: publisher,
        publishedDate: publishedDate,
        scannedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[IsbnService] Erro Google Books: $e');
      return Book.isbnOnly(isbn);
    }
  }

  Future<Book> _lookupOpenLibrary(String isbn) async {
    final uri = Uri.parse('$_openLibraryBaseUrl?bibkeys=ISBN:$isbn&format=json&jscmd=data');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return Book.isbnOnly(isbn);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final bookData = data['ISBN:$isbn'] as Map<String, dynamic>?;
      if (bookData == null) return Book.isbnOnly(isbn);

      String author = '-';
      final authorsData = bookData['authors'] as List<dynamic>?;
      if (authorsData != null && authorsData.isNotEmpty) {
        author = authorsData.map((a) => a['name']).where((n) => n != null).join(', ');
      }

      String publisher = '-';
      final publishersData = bookData['publishers'] as List<dynamic>?;
      if (publishersData != null && publishersData.isNotEmpty) {
        publisher = publishersData.map((p) => p['name']).where((n) => n != null).join(', ');
      }

      final title = bookData['title'] as String? ?? 'Título não encontrado';
      final publishedDate = bookData['publish_date'] as String? ?? '-';
      final subtitle = '-'; // Open Library usually doesn't have a separate subtitle field in this API call

      return Book(
        isbn: isbn,
        title: title,
        subtitle: subtitle,
        author: author,
        publisher: publisher,
        publishedDate: publishedDate,
        scannedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[IsbnService] Erro Open Library: $e');
      return Book.isbnOnly(isbn);
    }
  }
}