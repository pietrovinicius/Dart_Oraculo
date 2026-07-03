/// Modelo de conversa.
class Conversation {
  const Conversation({
    this.id,
    required this.title,
    required this.createdAt,
  });

  final int? id;
  final String? title;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
    id: map['id'] as int?,
    title: map['title'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
