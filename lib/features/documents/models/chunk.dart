/// Modelo de chunk (fragmento de texto indexado).
class Chunk {
  const Chunk({
    this.id,
    required this.documentId,
    this.page,
    required this.content,
    required this.createdAt,
  });

  final int? id;
  final int documentId;
  final int? page;
  final String content;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'document_id': documentId,
      'page': page,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Chunk.fromMap(Map<String, dynamic> map) => Chunk(
    id: map['id'] as int?,
    documentId: map['document_id'] as int,
    page: map['page'] as int?,
    content: map['content'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
