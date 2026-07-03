/// Modelo de documento importado.
class Document {
  const Document({
    this.id,
    required this.filename,
    this.sourcePath,
    required this.importedAt,
  });

  final int? id;
  final String filename;
  final String? sourcePath;
  final DateTime importedAt;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'filename': filename,
      'source_path': sourcePath,
      'imported_at': importedAt.toIso8601String(),
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) => Document(
    id: map['id'] as int?,
    filename: map['filename'] as String,
    sourcePath: map['source_path'] as String?,
    importedAt: DateTime.parse(map['imported_at'] as String),
  );
}
