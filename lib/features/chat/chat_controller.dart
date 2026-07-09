import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/config/app_config.dart';
import '../../core/models/image_attachment.dart';
import '../../core/services/anthropic_service.dart';
import '../../core/services/fidelity_checker.dart';
import '../../core/services/fts_service.dart';
import '../../core/services/generation_service.dart';
import '../../core/services/logger_service.dart';
// import '../../core/services/secure_storage_service.dart'; // WEB_SEARCH_DISABLED
// import '../../core/services/web_search_service.dart'; // WEB_SEARCH_DISABLED
import 'models/conversation.dart';
import 'models/message.dart';

/// Resultado do feedback + checagem de fidelidade.
class FeedbackResult {
  const FeedbackResult({
    this.needsConfirmation = false,
    this.ungroundedClaims,
    this.confirmationMessage,
  });

  final bool needsConfirmation;
  final List<String>? ungroundedClaims;
  /// Mensagem exibida no dialog de confirmação (ex: resposta de conhecimento geral).
  final String? confirmationMessage;
}

/// Controller principal do chat.
/// Orquestra: pergunta → recuperação FTS5 → montagem de prompt → geração → persistência.
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

  /// Acesso ao banco para configurações de coleção na UI.
  Database get database => _db;

  /// Exposto para que o chat_screen possa setá-lo como activeGenerationService.
  AnthropicService get anthropicService => _anthropicService;

  /// Motor de geração ativo — sempre setado, nunca null.
  /// Injetado pelo chat_screen. Default: _anthropicService.
  late GenerationService activeGenerationService = _anthropicService;

  Future<Conversation> createConversation({String? title, int? collectionId}) async {
    LoggerService.instance.info(_tag, 'createConversation("$title", collection=$collectionId)');
    final now = DateTime.now();
    final id = await _db.insert('conversations', {
      'title': title,
      'collection_id': collectionId,
      'created_at': now.toIso8601String(),
    });
    return Conversation(id: id, title: title, createdAt: now, collectionId: collectionId);
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
  /// [collectionId] filtra busca FTS por coleção. [collectionInstructions] injeta no prompt.
  Stream<String> askQuestion({
    required int conversationId,
    required String question,
    required String model,
    int? collectionId,
    String? collectionInstructions,
    ImageAttachment? image,
  }) async* {
    LoggerService.instance.info(_tag, 'askQuestion(conv=$conversationId, model=$model, collection=$collectionId, q="${question.length > 50 ? question.substring(0, 50) : question}...")');

    // 0. Info da base de conhecimento
    final docCountRows = collectionId != null
        ? await _db.rawQuery(
            'SELECT COUNT(*) as cnt FROM documents WHERE collection_id = ?',
            [collectionId])
        : await _db.rawQuery('SELECT COUNT(*) as cnt FROM documents');
    final chunkCountRows = collectionId != null
        ? await _db.rawQuery(
            'SELECT COUNT(*) as cnt FROM chunks c '
            'JOIN documents d ON d.id = c.document_id '
            'WHERE d.collection_id = ?',
            [collectionId])
        : await _db.rawQuery('SELECT COUNT(*) as cnt FROM chunks');
    final docCount = docCountRows.first['cnt'] as int;
    final chunkCount = chunkCountRows.first['cnt'] as int;
    LoggerService.instance.info(_tag,
        'Base: $docCount documentos, $chunkCount chunks '
        '(coleção=${collectionId ?? "todas"})');

    // 1. Busca chunks relevantes via FTS5 (filtrado por coleção)
    final ftsResults = await _ftsService.search(question, collectionId: collectionId);
    LoggerService.instance.info(_tag, 'FTS5 retornou ${ftsResults.length} chunks');

    // Log detalhado de cada chunk retornado
    var truncatedCount = 0;
    for (var i = 0; i < ftsResults.length; i++) {
      final r = ftsResults[i];
      final preview = r.content.length > 80
          ? '${r.content.substring(0, 80).replaceAll('\n', ' ')}...'
          : r.content.replaceAll('\n', ' ');
      LoggerService.instance.info(_tag,
          '  chunk #${i + 1} [rank=${r.rank.toStringAsFixed(2)}] '
          'id=${r.chunkId} doc="${r.filename}" p.${r.page ?? "?"} '
          'preview="$preview"');
    }

    // 2. Monta contexto a partir dos chunks recuperados
    //    Trunca chunks grandes conforme limite do motor ativo.
    final maxChars = activeGenerationService.maxContextCharsPerChunk;
    final contextBuffer = StringBuffer();
    // Injeta instructions da coleção antes do contexto RAG
    if (collectionInstructions != null && collectionInstructions.isNotEmpty) {
      contextBuffer.writeln('[Instruções da coleção]: $collectionInstructions');
      contextBuffer.writeln();
    }
    for (final result in ftsResults) {
      final content = result.content;
      final String truncatedContent;
      if (content.length > maxChars) {
        truncatedCount++;
        // Trunca com nota explicativa — chunk indexado permanece íntegro
        final lineCount = '\n'.allMatches(content).length + 1;
        truncatedContent = '${content.substring(0, maxChars)}\n'
            '[... conteúdo truncado. Total: $lineCount linhas / ${content.length} chars. '
            'Consulte o documento completo para a lista integral.]';
      } else {
        truncatedContent = content;
      }
      contextBuffer.writeln(
        '[Fonte: ${result.filename} | p.${result.page ?? "?"} | relevância: ${result.rank.toStringAsFixed(2)}]',
      );
      contextBuffer.writeln(truncatedContent);
      contextBuffer.writeln();
    }
    // 2b. Injeta documentos de trabalho da conversa (context attachments)
    //     Limite: soma total de todos os anexos ≤ maxChars (não por anexo isolado)
    final attachments = await getContextAttachments(conversationId);
    if (attachments.isNotEmpty) {
      contextBuffer.writeln();
      var totalCharsUsed = 0;
      var injectedCount = 0;
      for (final att in attachments) {
        final attContent = att['content'] as String;
        final attFilename = att['filename'] as String;

        final remaining = maxChars - totalCharsUsed;
        if (remaining <= 0) {
          LoggerService.instance.warn(_tag,
              'Doc trabalho "$attFilename" ignorado — limite total atingido');
          break;
        }

        final String injected;
        if (attContent.length > remaining) {
          injected = '${attContent.substring(0, remaining)}\n'
              '[... documento de trabalho truncado. Total: ${attContent.length} chars. '
              'Limite combinado de ${maxChars} chars atingido.]';
          totalCharsUsed = maxChars;
        } else {
          injected = attContent;
          totalCharsUsed += attContent.length;
        }

        contextBuffer.writeln('--- DOCUMENTO DE TRABALHO: $attFilename ---');
        contextBuffer.writeln(injected);
        contextBuffer.writeln('--- FIM DOCUMENTO DE TRABALHO ---');
        contextBuffer.writeln();
        injectedCount++;
      }
      LoggerService.instance.info(_tag,
          'Docs de trabalho: $injectedCount/${attachments.length} anexos injetados '
          '($totalCharsUsed/$maxChars chars)');
    }

    // 2c. Lê toggles da coleção
    bool allowGeneralKnowledge = false;
    // bool webEnabled = false; // WEB_SEARCH_DISABLED
    if (collectionId != null) {
      final colRows = await _db.query('collections', where: 'id = ?', whereArgs: [collectionId]);
      if (colRows.isNotEmpty) {
        allowGeneralKnowledge = (colRows.first['general_knowledge_fallback'] as int?) == 1;
        // webEnabled = (colRows.first['web_search_fallback'] as int?) == 1; // WEB_SEARCH_DISABLED
      }
    }

    // --- WEB_SEARCH_DISABLED: Busca na internet removida — não é conceito do app ---
    // var usedWebSearch = false;
    // if (ftsResults.isEmpty && attachments.isEmpty) {
    //   final isClaudeMotor = !activeGenerationService.modelDisplayName.toLowerCase().contains('qwen');
    //   if (isClaudeMotor && webEnabled) {
    //     final storageService = SecureStorageService();
    //     final braveKey = await storageService.readRaw('brave_api_key');
    //     if (braveKey != null && braveKey.isNotEmpty) {
    //       LoggerService.instance.info(_tag, 'RAG vazio → buscando na web...');
    //       final webResults = await WebSearchService(apiKey: braveKey).search(question);
    //       if (webResults.isNotEmpty) {
    //         usedWebSearch = true;
    //         contextBuffer.writeln();
    //         contextBuffer.writeln('--- CONTEXTO WEB (pesquisa na internet) ---');
    //         for (var i = 0; i < webResults.length; i++) {
    //           final r = webResults[i];
    //           contextBuffer.writeln('[${i + 1}] ${r.title}');
    //           contextBuffer.writeln('    URL: ${r.url}');
    //           contextBuffer.writeln('    ${r.snippet}');
    //           contextBuffer.writeln();
    //         }
    //         contextBuffer.writeln('--- FIM CONTEXTO WEB ---');
    //         LoggerService.instance.info(_tag,
    //             'Web search: ${webResults.length} resultados injetados');
    //       }
    //     }
    //   }
    // }
    // --- FIM WEB_SEARCH_DISABLED ---
    const usedWebSearch = false; // placeholder para lógica de response_source

    final context = contextBuffer.toString();
    LoggerService.instance.info(_tag,
        'Contexto montado: ${(context.length / 1024).toStringAsFixed(1)}KB '
        '(${ftsResults.length} chunks, truncados: $truncatedCount, '
        'docs trabalho: ${attachments.length}, web: $usedWebSearch)');

    // 3. Recupera histórico recente da conversa
    final allMessages = await getMessages(conversationId);
    final recentMessages = allMessages.length > AppConfig.maxHistoryMessages
        ? allMessages.sublist(allMessages.length - AppConfig.maxHistoryMessages)
        : allMessages;
    LoggerService.instance.info(_tag,
        'Histórico: ${recentMessages.length} mensagens (de ${allMessages.length} total)');

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
      'image_path': image?.path,
      'created_at': now.toIso8601String(),
    });

    // 5. Chama motor de geração ativo (injeção pura, sem condicional)
    final responseBuffer = StringBuffer();
    await for (final token in activeGenerationService.streamResponse(
      systemPrompt: context,
      history: history,
      question: question,
      images: image != null ? [image] : null,
      allowGeneralKnowledge: allowGeneralKnowledge,
    )) {
      responseBuffer.write(token);
      yield token;
    }

    // 6. Persiste resposta do assistant com nome do modelo que gerou
    final chunkIds = ftsResults.map((r) => r.chunkId).toList();
    // Determina response_source: 'web' se usou web search, 'general' se RAG vazio
    // e knowledge fallback ligado, 'rag' caso contrário.
    final String responseSource;
    if (usedWebSearch) {
      responseSource = 'web';
    } else if (chunkIds.isEmpty && allowGeneralKnowledge) {
      responseSource = 'general';
    } else {
      responseSource = 'rag';
    }
    await _db.insert('messages', {
      'conversation_id': conversationId,
      'role': 'assistant',
      'content': responseBuffer.toString(),
      'model_used': activeGenerationService.modelDisplayName,
      'chunks_used': jsonEncode(chunkIds),
      'response_source': responseSource,
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

  // --- Feedback (like/dislike) + Promoção RAG ---

  /// Grava, alterna ou remove voto de feedback.
  /// Like → checagem de fidelidade (se Anthropic) → promove resposta.
  /// Remove like / dislike → reverte promoção.
  Future<FeedbackResult> setFeedback(int messageId, String? value) async {
    LoggerService.instance.info(_tag, 'setFeedback(msg=$messageId, value=$value)');

    final existing = await _db.query(
      'message_feedback',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );

    final String? previousValue =
        existing.isNotEmpty ? existing.first['value'] as String : null;

    // Determina se precisa promover nesta chamada
    bool shouldPromote = false;
    bool shouldRevoke = false;

    if (value == null) {
      await _db.delete('message_feedback', where: 'message_id = ?', whereArgs: [messageId]);
      if (previousValue == 'like') shouldRevoke = true;
    } else if (existing.isEmpty) {
      await _db.insert('message_feedback', {
        'message_id': messageId,
        'value': value,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (value == 'like') shouldPromote = true;
    } else {
      final currentValue = existing.first['value'] as String;
      if (currentValue == value) {
        // Toggle off
        await _db.delete('message_feedback', where: 'message_id = ?', whereArgs: [messageId]);
        if (currentValue == 'like') shouldRevoke = true;
      } else {
        await _db.update(
          'message_feedback',
          {'value': value, 'created_at': DateTime.now().toIso8601String()},
          where: 'message_id = ?', whereArgs: [messageId],
        );
        if (currentValue == 'like' && value == 'dislike') shouldRevoke = true;
        if (currentValue == 'dislike' && value == 'like') shouldPromote = true;
      }
    }

    // Reverte promoção se necessário
    if (shouldRevoke) {
      await _revokePromotion(messageId);
    }

    // Checagem de fidelidade + promoção
    if (shouldPromote) {
      final checkResult = await _checkAndPromote(messageId);
      if (checkResult.needsConfirmation) {
        notifyListeners();
        return checkResult;
      }
    }

    notifyListeners();
    return const FeedbackResult();
  }

  /// Força promoção sem checagem (após user confirmar dialog).
  Future<void> forcePromote(int messageId) async {
    await _promoteAnswer(messageId);
    notifyListeners();
  }

  /// Checa fidelidade e promove se grounded. Retorna resultado.
  Future<FeedbackResult> _checkAndPromote(int messageId) async {
    // Busca modelo usado na resposta
    final msgRows = await _db.query('messages', where: 'id = ?', whereArgs: [messageId]);
    if (msgRows.isEmpty) return const FeedbackResult();
    final modelUsed = msgRows.first['model_used'] as String? ?? '';

    // Se Qwen → skip checagem, promove direto
    if (modelUsed.contains('qwen') || modelUsed.contains('Qwen')) {
      LoggerService.instance.info(_tag, 'Skip checagem fidelidade (Qwen)');
      await _promoteAnswer(messageId);
      return const FeedbackResult();
    }

    // Busca collection_id para verificar toggle
    final convId = msgRows.first['conversation_id'] as int;
    final convRows = await _db.query('conversations', where: 'id = ?', whereArgs: [convId]);
    if (convRows.isEmpty) {
      await _promoteAnswer(messageId);
      return const FeedbackResult();
    }
    final collectionId = convRows.first['collection_id'] as int?;

    // Verifica toggle por coleção
    if (collectionId != null) {
      final colRows = await _db.query('collections', where: 'id = ?', whereArgs: [collectionId]);
      if (colRows.isNotEmpty) {
        final verify = (colRows.first['verify_before_promote'] as int?) ?? 1;
        if (verify == 0) {
          LoggerService.instance.info(_tag, 'Skip checagem (toggle desligado na coleção)');
          await _promoteAnswer(messageId);
          return const FeedbackResult();
        }
      }
    }

    // Determina verificador cruzado
    final String verifierModel;
    if (modelUsed.contains('opus') || modelUsed.contains('Opus')) {
      verifierModel = AppConfig.modelSonnet;
    } else {
      verifierModel = AppConfig.modelOpus;
    }

    // Monta contexto dos chunks usados
    final chunksUsed = msgRows.first['chunks_used'] as String?;
    final responseSource = msgRows.first['response_source'] as String?;

    // Resposta de conhecimento geral → exige confirmação antes de promover
    if (responseSource == 'general' || chunksUsed == null || chunksUsed.isEmpty || chunksUsed == '[]') {
      if (responseSource == 'general') {
        return const FeedbackResult(
          needsConfirmation: true,
          confirmationMessage: 'Esta resposta não veio dos seus documentos. '
              'Promover pode inserir informação não verificada na sua base. '
              'Continuar?',
        );
      }
      // Sem chunks e não é general → promove direto (compatibilidade)
      await _promoteAnswer(messageId);
      return const FeedbackResult();
    }

    final chunkIds = (jsonDecode(chunksUsed) as List).cast<int>();
    if (chunkIds.isEmpty) {
      if (responseSource == 'general') {
        return const FeedbackResult(
          needsConfirmation: true,
          confirmationMessage: 'Esta resposta não veio dos seus documentos. '
              'Promover pode inserir informação não verificada na sua base. '
              'Continuar?',
        );
      }
      await _promoteAnswer(messageId);
      return const FeedbackResult();
    }

    final placeholders = chunkIds.map((_) => '?').join(',');
    final chunkRows = await _db.rawQuery(
      'SELECT content FROM chunks WHERE id IN ($placeholders)', chunkIds);
    final chunksContext = chunkRows.map((r) => r['content'] as String).join('\n\n');

    // Chama verificador
    final checker = FidelityChecker(
      headers: _anthropicService.buildHeaders(),
    );
    final result = await checker.check(
      answerText: msgRows.first['content'] as String,
      chunksContext: chunksContext,
      verifierModel: verifierModel,
    );

    if (result.isGrounded) {
      await _promoteAnswer(messageId);
      return const FeedbackResult();
    } else {
      LoggerService.instance.warn(_tag,
          'Resposta não fundamentada: ${result.ungroundedClaims}');
      return FeedbackResult(
        needsConfirmation: true,
        ungroundedClaims: result.ungroundedClaims,
      );
    }
  }

  /// Promove resposta do assistant como chunk pesquisável na coleção.
  Future<void> _promoteAnswer(int messageId) async {
    // Busca a mensagem assistant
    final msgRows = await _db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
    if (msgRows.isEmpty) return;
    final msg = msgRows.first;
    final conversationId = msg['conversation_id'] as int;
    final assistantContent = msg['content'] as String;

    // Busca mensagem user anterior (última antes desta)
    final userRows = await _db.query(
      'messages',
      where: 'conversation_id = ? AND id < ? AND role = ?',
      whereArgs: [conversationId, messageId, 'user'],
      orderBy: 'id DESC',
      limit: 1,
    );
    final userContent = userRows.isNotEmpty
        ? userRows.first['content'] as String
        : '(pergunta não encontrada)';

    // Busca collection_id da conversa
    final convRows = await _db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    if (convRows.isEmpty) return;
    final collectionId = convRows.first['collection_id'] as int?;
    if (collectionId == null) return;

    // Busca nome da coleção
    final colRows = await _db.query(
      'collections',
      where: 'id = ?',
      whereArgs: [collectionId],
    );
    final collectionName = colRows.isNotEmpty
        ? colRows.first['name'] as String
        : 'Desconhecida';

    // Obtém ou cria documento sintético
    final docId = await _getOrCreatePromotedDocument(collectionId);

    // Monta conteúdo do chunk
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
    final chunkContent = '[Resposta aprovada em $dateStr | Coleção: $collectionName]\n'
        'Pergunta: $userContent\n'
        'Resposta: $assistantContent';

    // Insere chunk (trigger FTS5 indexa automaticamente)
    await _db.insert('chunks', {
      'document_id': docId,
      'page': null,
      'content': chunkContent,
      'source_type': 'promoted_answer',
      'original_message_id': messageId,
      'created_at': now.toIso8601String(),
    });

    LoggerService.instance.info(_tag,
        'Resposta promovida: msg=$messageId → chunk na coleção "$collectionName"');
  }

  /// Reverte promoção — remove chunk associado à mensagem.
  Future<void> _revokePromotion(int messageId) async {
    final deleted = await _db.delete(
      'chunks',
      where: 'original_message_id = ?',
      whereArgs: [messageId],
    );
    if (deleted > 0) {
      LoggerService.instance.info(_tag,
          'Promoção revogada: msg=$messageId ($deleted chunks removidos)');
    }
  }

  /// Obtém ou cria documento sintético "Respostas Aprovadas do Oráculo".
  Future<int> _getOrCreatePromotedDocument(int collectionId) async {
    const docName = 'Respostas Aprovadas do Oráculo';
    final existing = await _db.query(
      'documents',
      where: 'filename = ? AND collection_id = ?',
      whereArgs: [docName, collectionId],
    );
    if (existing.isNotEmpty) return existing.first['id'] as int;

    final id = await _db.insert('documents', {
      'filename': docName,
      'collection_id': collectionId,
      'imported_at': DateTime.now().toIso8601String(),
    });
    LoggerService.instance.info(_tag,
        'Documento sintético criado: "$docName" na coleção $collectionId');
    return id;
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

  // --- Context Attachments (documentos de trabalho por conversa) ---

  /// Adiciona um documento de trabalho à conversa.
  Future<void> addContextAttachment(
    int conversationId,
    String filename,
    String content,
  ) async {
    await _db.insert('conversation_context_attachments', {
      'conversation_id': conversationId,
      'filename': filename,
      'content': content,
      'added_at': DateTime.now().toIso8601String(),
    });
    LoggerService.instance.info(_tag,
        'Context attachment adicionado: "$filename" (${content.length} chars) na conv=$conversationId');
    notifyListeners();
  }

  /// Retorna todos os attachments de uma conversa.
  Future<List<Map<String, dynamic>>> getContextAttachments(int conversationId) async {
    return _db.query(
      'conversation_context_attachments',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'added_at ASC',
    );
  }

  /// Remove um attachment específico.
  Future<void> removeContextAttachment(int attachmentId) async {
    await _db.delete(
      'conversation_context_attachments',
      where: 'id = ?',
      whereArgs: [attachmentId],
    );
    LoggerService.instance.info(_tag, 'Context attachment removido: id=$attachmentId');
    notifyListeners();
  }

  /// Deleta todas as mensagens com id > [afterMessageId] na conversa.
  /// Usado para editar mensagem do user e reenviar.
  Future<void> deleteMessagesAfter(int conversationId, int afterMessageId) async {
    await _db.delete(
      'messages',
      where: 'conversation_id = ? AND id > ?',
      whereArgs: [conversationId, afterMessageId],
    );
  }

  // --- Exportação de conversa ---

  /// Exporta conversa completa como markdown formatado.
  Future<String> exportConversationAsMarkdown(int conversationId) async {
    // Busca conversa
    final convRows = await _db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    if (convRows.isEmpty) return '';
    final conv = convRows.first;
    final title = conv['title'] as String? ?? 'Sem título';
    final collectionId = conv['collection_id'] as int?;

    // Busca nome da coleção
    String collectionName = 'Sem coleção';
    if (collectionId != null) {
      final colRows = await _db.query(
        'collections',
        where: 'id = ?',
        whereArgs: [collectionId],
      );
      if (colRows.isNotEmpty) {
        collectionName = colRows.first['name'] as String;
      }
    }

    // Busca mensagens
    final messages = await getMessages(conversationId);

    // Header
    final now = DateTime.now();
    final exportDate = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
    final exportTime = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln('# Conversa: $title');
    buffer.writeln();
    buffer.writeln('*Exportado em $exportDate às $exportTime | Coleção: $collectionName*');
    buffer.writeln();
    buffer.writeln('---');

    // Mensagens
    for (final msg in messages) {
      buffer.writeln();
      final time = '${msg.createdAt.hour.toString().padLeft(2, '0')}:'
          '${msg.createdAt.minute.toString().padLeft(2, '0')}';

      if (msg.role == 'user') {
        buffer.writeln('## 👤 Usuário ($time)');
        buffer.writeln();
        if (msg.imagePath != null) {
          buffer.writeln('📎 *[imagem anexada]*');
          buffer.writeln();
        }
        buffer.writeln(msg.content);
      } else {
        final model = msg.modelUsed ?? 'desconhecido';
        buffer.writeln('## 🤖 Assistente ($time) — $model');
        buffer.writeln();
        buffer.writeln(msg.content);

        // Fontes citadas
        if (msg.chunksUsed != null) {
          try {
            final ids = (jsonDecode(msg.chunksUsed!) as List).cast<int>();
            if (ids.isNotEmpty) {
              final citations = await _buildCitationLabels(ids);
              if (citations.isNotEmpty) {
                buffer.writeln();
                buffer.writeln('**Fontes:** ${citations.join(', ')}');
              }
            }
          } catch (_) {}
        }
      }

      buffer.writeln();
      buffer.writeln('---');
    }

    return buffer.toString();
  }

  /// Monta labels de citação para IDs de chunks.
  Future<List<String>> _buildCitationLabels(List<int> chunkIds) async {
    final placeholders = chunkIds.map((_) => '?').join(',');
    final rows = await _db.rawQuery(
      'SELECT c.id, c.source_type, c.page, c.created_at, d.filename '
      'FROM chunks c JOIN documents d ON d.id = c.document_id '
      'WHERE c.id IN ($placeholders)',
      chunkIds,
    );

    final labels = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      final sourceType = row['source_type'] as String? ?? 'document';
      final String label;
      if (sourceType == 'promoted_answer') {
        final createdAt = row['created_at'] as String?;
        final dt = createdAt != null ? DateTime.tryParse(createdAt) : null;
        final dateStr = dt != null
            ? '${dt.day.toString().padLeft(2, '0')}/'
              '${dt.month.toString().padLeft(2, '0')}/${dt.year}'
            : '?';
        label = 'Resposta aprovada ($dateStr)';
      } else {
        final filename = row['filename'] as String;
        final page = row['page'] as int?;
        label = page != null ? '$filename (p.$page)' : filename;
      }
      if (!seen.contains(label)) {
        seen.add(label);
        labels.add(label);
      }
    }
    return labels;
  }
}
