import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/config/app_config.dart';
import '../../core/services/anthropic_service.dart';
import '../../core/services/fts_service.dart';
import '../../core/services/logger_service.dart';
import 'models/conversation.dart';
import 'models/message.dart';

/// Controller principal do chat.
/// Orquestra: pergunta → recuperação FTS5 → montagem de prompt → API → persistência.
class ChatController extends ChangeNotifier {
  ChatController({
    required Database database,
    required AnthropicService anthropicService,
    required FtsService ftsService,
  })  : _db = database,
        _anthropicService = anthropicService,
        _ftsService = ftsService;

  static const _tag = 'ChatController';
  final Database _db;
  final AnthropicService _anthropicService;
  final FtsService _ftsService;

  Future<Conversation> createConversation({String? title}) async {
    LoggerService.instance.info(_tag, 'createConversation("$title")');
    final now = DateTime.now();
    final id = await _db.insert('conversations', {
      'title': title,
      'created_at': now.toIso8601String(),
    });
    return Conversation(id: id, title: title, createdAt: now);
  }

  /// Lista todas as conversas — fixadas primeiro, depois por data.
  Future<List<Conversation>> listConversations() async {
    final rows = await _db.query(
      'conversations',
      orderBy: 'pinned DESC, created_at DESC',
    );
    return rows.map(Conversation.fromMap).toList();
  }

  /// Renomeia uma conversa.
  Future<void> renameConversation(int id, String newTitle) async {
    LoggerService.instance.info(_tag, 'renameConversation($id, "$newTitle")');
    await _db.update(
      'conversations',
      {'title': newTitle},
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
  }

  /// Fixa ou desfixa uma conversa.
  Future<void> togglePin(int id, bool pinned) async {
    LoggerService.instance.info(_tag, 'togglePin($id, pinned=$pinned)');
    await _db.update(
      'conversations',
      {'pinned': pinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
  }

  /// Retorna mensagens de uma conversa, em ordem cronológica.
  Future<List<Message>> getMessages(int conversationId) async {
    final rows = await _db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Message.fromMap).toList();
  }

  /// Faz uma pergunta: busca contexto via FTS5, chama API, retorna stream de tokens.
  Stream<String> askQuestion({
    required int conversationId,
    required String question,
    required String model,
  }) async* {
    LoggerService.instance.info(_tag, 'askQuestion(conv=$conversationId, model=$model, q="${question.length > 50 ? question.substring(0, 50) : question}...")');

    // 1. Busca chunks relevantes via FTS5
    final ftsResults = await _ftsService.search(question);
    LoggerService.instance.info(_tag, 'FTS5 retornou ${ftsResults.length} chunks');

    // 2. Monta contexto a partir dos chunks recuperados
    final contextBuffer = StringBuffer();
    for (final result in ftsResults) {
      contextBuffer.writeln(
        '[${result.filename}, p.${result.page ?? "?"}]: ${result.content}',
      );
      contextBuffer.writeln();
    }
    final context = contextBuffer.toString();

    // 3. Recupera histórico recente da conversa
    final allMessages = await getMessages(conversationId);
    final recentMessages = allMessages.length > AppConfig.maxHistoryMessages
        ? allMessages.sublist(allMessages.length - AppConfig.maxHistoryMessages)
        : allMessages;

    final history = recentMessages.map((m) => {
      'role': m.role,
      'content': m.content,
    }).toList();

    // 4. Persiste mensagem do usuário
    final now = DateTime.now();
    await _db.insert('messages', {
      'conversation_id': conversationId,
      'role': 'user',
      'content': question,
      'model_used': null,
      'chunks_used': null,
      'created_at': now.toIso8601String(),
    });

    // 5. Chama API e acumula resposta
    final responseBuffer = StringBuffer();
    await for (final token in _anthropicService.sendMessage(
      userMessage: question,
      context: context,
      history: history,
      model: model,
    )) {
      responseBuffer.write(token);
      yield token;
    }

    // 6. Persiste resposta do assistant
    final chunkIds = ftsResults.map((r) => r.chunkId).toList();
    await _db.insert('messages', {
      'conversation_id': conversationId,
      'role': 'assistant',
      'content': responseBuffer.toString(),
      'model_used': model,
      'chunks_used': jsonEncode(chunkIds),
      'created_at': DateTime.now().toIso8601String(),
    });

    notifyListeners();
  }

  /// Deleta uma conversa e todas suas mensagens.
  Future<void> deleteConversation(int conversationId) async {
    await _db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
    await _db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    notifyListeners();
  }

  // --- Feedback (like/dislike) ---

  /// Grava, alterna ou remove voto de feedback.
  /// value='like'|'dislike' → grava/alterna. null → remove.
  /// Se value igual ao existente → remove (toggle off).
  Future<void> setFeedback(int messageId, String? value) async {
    LoggerService.instance.info(_tag, 'setFeedback(msg=$messageId, value=$value)');

    final existing = await _db.query(
      'message_feedback',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );

    if (value == null) {
      // Remove
      await _db.delete(
        'message_feedback',
        where: 'message_id = ?',
        whereArgs: [messageId],
      );
    } else if (existing.isEmpty) {
      // Insere novo
      await _db.insert('message_feedback', {
        'message_id': messageId,
        'value': value,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      final currentValue = existing.first['value'] as String;
      if (currentValue == value) {
        // Toggle off — mesmo valor = remove
        await _db.delete(
          'message_feedback',
          where: 'message_id = ?',
          whereArgs: [messageId],
        );
      } else {
        // Alterna para outro valor
        await _db.update(
          'message_feedback',
          {'value': value, 'created_at': DateTime.now().toIso8601String()},
          where: 'message_id = ?',
          whereArgs: [messageId],
        );
      }
    }
    notifyListeners();
  }

  /// Retorna 'like', 'dislike', ou null.
  Future<String?> getFeedback(int messageId) async {
    final rows = await _db.query(
      'message_feedback',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  /// Carrega feedback de todas as mensagens de uma conversa.
  Future<Map<int, String?>> getFeedbacksForConversation(int conversationId) async {
    final rows = await _db.rawQuery('''
      SELECT mf.message_id, mf.value
      FROM message_feedback mf
      INNER JOIN messages m ON m.id = mf.message_id
      WHERE m.conversation_id = ?
    ''', [conversationId]);

    final result = <int, String?>{};
    for (final row in rows) {
      result[row['message_id'] as int] = row['value'] as String?;
    }
    return result;
  }
}
