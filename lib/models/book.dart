class Book {
  final String isbn;
  final String title;
  final String subtitle;
  final String author;
  final String publisher;
  final String publishedDate;
  final DateTime scannedAt;
  final String obs;

  Book({
    required this.isbn,
    required this.title,
    required this.subtitle,
    required this.author,
    required this.publisher,
    required this.publishedDate,
    required this.scannedAt,
    this.obs = '-',
  });

  Book copyWith({
    String? isbn,
    String? title,
    String? subtitle,
    String? author,
    String? publisher,
    String? publishedDate,
    DateTime? scannedAt,
    String? obs,
  }) {
    return Book(
      isbn: isbn ?? this.isbn,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      publishedDate: publishedDate ?? this.publishedDate,
      scannedAt: scannedAt ?? this.scannedAt,
      obs: obs ?? this.obs,
    );
  }

  /// Usado quando a consulta na API do Google Books não encontra o livro.
  factory Book.isbnOnly(String isbn) {
    return Book(
      isbn: isbn,
      title: 'Título não encontrado',
      subtitle: '-',
      author: '-',
      publisher: '-',
      publishedDate: '-',
      scannedAt: DateTime.now(),
      obs: '-',
    );
  }

  List<String> toRow() {
    return [
      isbn,
      title,
      subtitle,
      author,
      publisher,
      publishedDate,
      scannedAt.toIso8601String(),
      obs,
    ];
  }

  static const List<String> headers = [
    'ISBN',
    'Título',
    'Subtitle',
    'Autor',
    'Editora',
    'Ano de Publicação',
    'Data de Escaneamento',
    'Observações',
  ];
}
