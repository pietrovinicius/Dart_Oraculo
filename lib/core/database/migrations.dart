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

  /// Executa todas as migrations na ordem correta.
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
}
