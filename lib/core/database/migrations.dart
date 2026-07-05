/// Schema SQL e migrations do Dart Oráculo.
/// Baseado na seção 6 do documento de especificação.
class Migrations {
  Migrations._();

  static const String createDocuments = '''
    CREATE TABLE IF NOT EXISTS documents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      filename TEXT NOT NULL,
      source_path TEXT,
      imported_at TEXT NOT NULL
    );
  ''';

  static const String createChunks = '''
    CREATE TABLE IF NOT EXISTS chunks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id INTEGER NOT NULL REFERENCES documents(id),
      page INTEGER,
      content TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''';

  static const String createChunksFts = '''
    CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
      content,
      content='chunks',
      content_rowid='id'
    );
  ''';

  /// Triggers para manter chunks_fts sincronizado com chunks.
  static const String triggerInsert = '''
    CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON chunks BEGIN
      INSERT INTO chunks_fts(rowid, content) VALUES (new.id, new.content);
    END;
  ''';

  static const String triggerDelete = '''
    CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON chunks BEGIN
      INSERT INTO chunks_fts(chunks_fts, rowid, content)
        VALUES('delete', old.id, old.content);
    END;
  ''';

  static const String triggerUpdate = '''
    CREATE TRIGGER IF NOT EXISTS chunks_au AFTER UPDATE ON chunks BEGIN
      INSERT INTO chunks_fts(chunks_fts, rowid, content)
        VALUES('delete', old.id, old.content);
      INSERT INTO chunks_fts(rowid, content) VALUES (new.id, new.content);
    END;
  ''';

  static const String createConversations = '''
    CREATE TABLE IF NOT EXISTS conversations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      pinned INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
  ''';

  static const String createMessages = '''
    CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      conversation_id INTEGER NOT NULL REFERENCES conversations(id),
      role TEXT NOT NULL CHECK(role IN ('user', 'assistant')),
      content TEXT NOT NULL,
      model_used TEXT,
      chunks_used TEXT,
      created_at TEXT NOT NULL
    );
  ''';

  // --- V2: message_feedback ---

  static const String createMessageFeedback = '''
    CREATE TABLE IF NOT EXISTS message_feedback (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      message_id INTEGER NOT NULL REFERENCES messages(id),
      value TEXT NOT NULL CHECK(value IN ('like', 'dislike')),
      created_at TEXT NOT NULL
    );
  ''';

  /// Executa todas as migrations na ordem correta (fresh install).
  static List<String> get allV1 => [
    createDocuments,
    createChunks,
    createChunksFts,
    triggerInsert,
    triggerDelete,
    triggerUpdate,
    createConversations,
    createMessages,
  ];

  static const String addPinnedToConversations = '''
    ALTER TABLE conversations ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0;
  ''';

  /// Migrations incrementais v1 → v2.
  static List<String> get upgradeV1toV2 => [
    addPinnedToConversations,
    createMessageFeedback,
  ];

  /// Fresh install completo (v2) — schema já inclui pinned em createConversations.
  static List<String> get allV2 => [
    ...allV1,
    createMessageFeedback,
  ];

  // --- V3: collections ---

  static const String createCollections = '''
    CREATE TABLE IF NOT EXISTS collections (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      instructions TEXT,
      created_at TEXT NOT NULL
    );
  ''';

  static const String addCollectionIdToDocuments = '''
    ALTER TABLE documents ADD COLUMN collection_id INTEGER REFERENCES collections(id);
  ''';

  static const String addCollectionIdToConversations = '''
    ALTER TABLE conversations ADD COLUMN collection_id INTEGER REFERENCES collections(id);
  ''';

  /// Migrations incrementais v2 → v3.
  /// Nota: o backfill (criar "Geral" e UPDATE) é feito em código no onUpgrade,
  /// não em SQL estático, porque precisa capturar o ID inserido.
  static List<String> get upgradeV2toV3Schema => [
    createCollections,
    addCollectionIdToDocuments,
    addCollectionIdToConversations,
  ];

  /// Fresh install completo (v3).
  static List<String> get allV3 => [
    ...allV2,
    createCollections,
    addCollectionIdToDocuments,
    addCollectionIdToConversations,
  ];

  // --- V4: document description ---

  static const String addDescriptionToDocuments = '''
    ALTER TABLE documents ADD COLUMN description TEXT;
  ''';

  /// Migrations incrementais v3 → v4.
  static List<String> get upgradeV3toV4 => [
    addDescriptionToDocuments,
  ];

  /// Fresh install completo (v4).
  static List<String> get allV4 => [
    ...allV3,
    addDescriptionToDocuments,
  ];

  // --- V5: image_path em messages ---

  static const String addImagePathToMessages = '''
    ALTER TABLE messages ADD COLUMN image_path TEXT;
  ''';

  /// Migrations incrementais v4 → v5.
  static List<String> get upgradeV4toV5 => [
    addImagePathToMessages,
  ];

  /// Fresh install completo (v5).
  static List<String> get allV5 => [
    ...allV4,
    addImagePathToMessages,
  ];

  // --- V6: promoted answers ---

  static const String addSourceTypeToChunks = '''
    ALTER TABLE chunks ADD COLUMN source_type TEXT NOT NULL DEFAULT 'document';
  ''';

  static const String addOriginalMessageIdToChunks = '''
    ALTER TABLE chunks ADD COLUMN original_message_id INTEGER;
  ''';

  /// Migrations incrementais v5 → v6.
  static List<String> get upgradeV5toV6 => [
    addSourceTypeToChunks,
    addOriginalMessageIdToChunks,
  ];

  /// Fresh install completo (v6).
  static List<String> get allV6 => [
    ...allV5,
    addSourceTypeToChunks,
    addOriginalMessageIdToChunks,
  ];

  // --- V7: verify_before_promote em collections ---

  static const String addVerifyBeforePromoteToCollections = '''
    ALTER TABLE collections ADD COLUMN verify_before_promote INTEGER NOT NULL DEFAULT 1;
  ''';

  /// Migrations incrementais v6 → v7.
  static List<String> get upgradeV6toV7 => [
    addVerifyBeforePromoteToCollections,
  ];

  /// Fresh install completo (v7).
  static List<String> get allV7 => [
    ...allV6,
    addVerifyBeforePromoteToCollections,
  ];
}
