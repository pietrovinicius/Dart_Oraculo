/// Modelo de conversa.
class Conversation {
  const Conversation({
    this.id,
    required this.title,
    required this.createdAt,
    this.pinned = false,
    this.collectionId,
  });

  final int? id;
  final String? title;
  final DateTime createdAt;
  final bool pinned;
  final int? collectionId;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'pinned': pinned ? 1 : 0,
      'collection_id': collectionId,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
    id: map['id'] as int?,
    title: map['title'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    pinned: (map['pinned'] as int? ?? 0) == 1,
    collectionId: map['collection_id'] as int?,
  );

  Conversation copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    bool? pinned,
    int? collectionId,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      pinned: pinned ?? this.pinned,
      collectionId: collectionId ?? this.collectionId,
    );
  }
}
