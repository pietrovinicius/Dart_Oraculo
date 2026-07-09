/// Modelo de mensagem (user ou assistant).
class Message {
  const Message({
    this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.modelUsed,
    this.chunksUsed,
    this.imagePath,
    this.responseSource,
    required this.createdAt,
  });

  final int? id;
  final int conversationId;
  final String role; // 'user' | 'assistant'
  final String content;
  final String? modelUsed;
  final String? chunksUsed; // JSON array de chunk IDs
  final String? imagePath; // caminho local da imagem anexada
  /// Origem da resposta: 'rag' | 'general' | 'web'
  final String? responseSource;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'model_used': modelUsed,
      'chunks_used': chunksUsed,
      'image_path': imagePath,
      'response_source': responseSource,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) => Message(
    id: map['id'] as int?,
    conversationId: map['conversation_id'] as int,
    role: map['role'] as String,
    content: map['content'] as String,
    modelUsed: map['model_used'] as String?,
    chunksUsed: map['chunks_used'] as String?,
    imagePath: map['image_path'] as String?,
    responseSource: map['response_source'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
