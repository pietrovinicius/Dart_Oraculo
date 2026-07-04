/// Modelo de coleção — agrupa documentos e conversas por assunto.
class Collection {
  const Collection({
    this.id,
    required this.name,
    this.instructions,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String? instructions; // max 500 chars
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'instructions': instructions,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Collection.fromMap(Map<String, dynamic> map) => Collection(
    id: map['id'] as int?,
    name: map['name'] as String,
    instructions: map['instructions'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
