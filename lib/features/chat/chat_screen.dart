import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_routes.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/image_attachment.dart';
import '../../core/services/anthropic_service.dart';
import '../../core/services/chunking_service.dart';
import '../../core/services/fts_service.dart';
import '../../core/services/generation_service.dart';
import '../../core/services/image_resize_service.dart';
import '../../core/services/kimi_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/ollama_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/app_settings_cache.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../collections/collection_service.dart';
import '../collections/models/collection.dart';
import '../documents/document_service.dart';
import '../documents/library_screen.dart';
import 'chat_controller.dart';
import 'models/conversation.dart';
import 'models/message.dart';
import 'utils/citation_dedup.dart';
import 'widgets/chat_input.dart';
import 'widgets/citation_strip.dart';
import 'widgets/message_bubble.dart';
import 'widgets/retry_bubble.dart';
import 'widgets/sidebar.dart';

/// Tela principal — sidebar + painel de chat.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.themeNotifier});

  final dynamic themeNotifier; // ThemeNotifier (optional, for passing to settings)

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChatController? _chatController;
  DocumentService? _documentService;
  CollectionService? _collectionService;
  final _storageService = SecureStorageService();

  List<Collection> _collections = [];
  int? _activeCollectionId;
  Collection? _activeCollection;
  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  Map<int, String?> _feedbacks = {};
  int? _activeConversationId;
  int _documentCount = 0;
  bool _isLoading = false;
  bool _sidebarVisible = true;
  String _selectedModel = AppConfig.defaultModel;
  String _appVersion = '';
  final _scrollController = ScrollController();
  bool _stopRequested = false;
  String? _lastFailedQuestion;
  String? _lastError;
  bool _showScrollToBottom = false;
  bool _isDragOver = false;
  double _textScale = 1.0; // Zoom de texto: 0.5 → 2.0
  int _chunkMaxTokens = AppConfig.chunkMaxTokens;

  @override
  void initState() {
    super.initState();
    _loadTextScale();
    _loadChunkMaxTokens();
    _initialize();
  }

  void _loadChunkMaxTokens() {
    final saved = AppSettingsCache().get('chunk_max_tokens');
    if (saved != null) {
      final parsed = int.tryParse(saved);
      if (parsed != null && mounted) {
        setState(() => _chunkMaxTokens = parsed);
      }
    }
  }

  void _loadTextScale() {
    final saved = AppSettingsCache().get('text_scale');
    if (saved != null) {
      final parsed = double.tryParse(saved);
      if (parsed != null && mounted) {
        setState(() => _textScale = parsed.clamp(0.5, 2.0));
      }
    }
  }

  Future<void> _saveTextScale() async {
    final persist = AppSettingsCache().get('persist_zoom');
    if (persist != 'false') {
      await _storageService.writeRaw('text_scale', _textScale.toStringAsFixed(1));
      AppSettingsCache().invalidate('text_scale');
    }
  }

  Future<void> _initialize() async {
    final db = await DatabaseHelper.instance.database;
    final ftsService = FtsService(database: db);

    final cache = AppSettingsCache();
    final apiKey = cache.get('anthropic_api_key');
    final model = cache.get('default_model');

    if (model != null) {
      _selectedModel = model;
    }

    final anthropicService = AnthropicService(
      apiKey: apiKey ?? '',
      httpClient: null,
    );

    _chatController = ChatController(
      database: db,
      anthropicService: anthropicService,
      ftsService: ftsService,
    );

    // Resolve GenerationService para geração de descrição
    GenerationService? descriptionService;
    if (_selectedModel == AppConfig.modelQwen) {
      descriptionService = OllamaService();
    } else if (apiKey != null && apiKey.isNotEmpty) {
      descriptionService = anthropicService;
    }

    _documentService = DocumentService(
      database: db,
      pdfService: PdfService(),
      chunkingService: ChunkingService(maxTokensPerChunk: _chunkMaxTokens),
      anthropicService: apiKey != null && apiKey.isNotEmpty
          ? anthropicService
          : null,
      generationService: descriptionService,
      defaultModel: _selectedModel,
    );

    _collectionService = CollectionService(database: db);

    // Configura motor de geração baseado no modelo padrão
    _updateGenerationService(_selectedModel);

    // Versão dinâmica via package_info_plus
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = packageInfo.version);
    } catch (_) {
      // Fallback: usa AppConfig.appVersion
    }

    await _refreshCollections();
    await _refreshConversations();
    await _refreshDocumentCount();
  }

  Future<void> _refreshCollections() async {
    final cols = await _collectionService?.listCollections() ?? [];
    if (mounted) {
      setState(() {
        _collections = cols;
        if (_activeCollectionId == null && cols.isNotEmpty) {
          _activeCollectionId = cols.first.id;
          _activeCollection = cols.first;
        }
      });
    }
  }

  void _onCollectionChanged(int id) {
    final col = _collections.firstWhere((c) => c.id == id);
    setState(() {
      _activeCollectionId = id;
      _activeCollection = col;
      _activeConversationId = null;
      _messages = [];
      _feedbacks = {};
    });
    _refreshConversations();
    _refreshDocumentCount();
  }

  Future<void> _createNewCollection() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Nova coleção', style: AppTextStyles.bodyLarge),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTextStyles.bodyLarge,
          decoration: const InputDecoration(hintText: 'Nome da coleção'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Criar', style: TextStyle(color: AppColors.accentOrange)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final col = await _collectionService?.createCollection(name: result);
      if (col != null) {
        await _refreshCollections();
        _onCollectionChanged(col.id!);
      }
    }
  }

  Future<void> _showCollectionSettings() async {
    if (_activeCollectionId == null) return;
    final db = _chatController?.database;
    if (db == null) return;

    final rows = await db.query('collections', where: 'id = ?', whereArgs: [_activeCollectionId]);
    if (rows.isEmpty) return;

    // Todos os toggles migrados para Settings global (v0.24.0+)
    // Dialog de coleção preservado apenas para instruções customizadas.

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Configurações — ${_activeCollection?.name ?? ""}',
            style: AppTextStyles.bodyLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Toggles de comportamento foram movidos para Configurações (menu principal).',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar', style: TextStyle(color: AppColors.accentOrange)),
            ),
          ],
      ),
    );
  }

  Future<void> _refreshConversations() async {
    final convs = await _chatController?.listConversations() ?? [];
    // Filtra por coleção ativa
    final filtered = _activeCollectionId == null
        ? convs
        : convs.where((c) => c.collectionId == _activeCollectionId).toList();
    if (mounted) {
      setState(() => _conversations = filtered);
    }
  }

  Future<void> _refreshDocumentCount() async {
    final docs = await _documentService?.listDocuments() ?? [];
    // Filtra por coleção ativa
    final filtered = _activeCollectionId == null
        ? docs
        : docs.where((d) => d.collectionId == _activeCollectionId).toList();
    if (mounted) {
      setState(() => _documentCount = filtered.length);
    }
  }

  Future<void> _loadMessages(int conversationId) async {
    final msgs = await _chatController?.getMessages(conversationId) ?? [];
    final feedbacks = await _chatController?.getFeedbacksForConversation(conversationId) ?? {};

    // Carrega citações reais (chunk_id → filename, page)
    await _loadCitationCache(msgs);

    if (mounted) {
      setState(() {
        _activeConversationId = conversationId;
        _messages = msgs;
        _feedbacks = feedbacks;
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadCitationCache(List<Message> messages) async {
    final db = await DatabaseHelper.instance.database;
    final allChunkIds = <int>{};
    for (final msg in messages) {
      if (msg.chunksUsed != null) {
        try {
          final ids = jsonDecode(msg.chunksUsed!) as List;
          allChunkIds.addAll(ids.cast<int>());
        } catch (_) {}
      }
    }
    if (allChunkIds.isEmpty) return;

    final placeholders = allChunkIds.map((_) => '?').join(',');
    final rows = await db.rawQuery(
      'SELECT c.id, d.filename, c.page, c.source_type, c.created_at FROM chunks c '
      'JOIN documents d ON d.id = c.document_id '
      'WHERE c.id IN ($placeholders)',
      allChunkIds.toList(),
    );

    _citationCache = {};
    for (final row in rows) {
      final id = row['id'] as int;
      final filename = row['filename'] as String;
      final page = row['page'] as int?;
      final sourceType = row['source_type'] as String?;
      final createdAt = row['created_at'] as String?;

      String? promotedDate;
      if (sourceType == 'promoted_answer' && createdAt != null) {
        final dt = DateTime.tryParse(createdAt);
        if (dt != null) {
          promotedDate = '${dt.day.toString().padLeft(2, '0')}/'
              '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        }
      }

      _citationCache[id] = CitationData(
        filename: filename,
        page: page,
        sourceType: sourceType,
        promotedDate: promotedDate,
      );
    }
  }

  Future<void> _createNewConversation() async {
    final conv = await _chatController?.createConversation(
      title: 'Nova conversa',
      collectionId: _activeCollectionId,
    );
    if (conv != null) {
      await _refreshConversations();
      await _loadMessages(conv.id!);
    }
  }

  Future<void> _deleteConversation(int id) async {
    final conv = _conversations.where((c) => c.id == id).firstOrNull;
    final title = conv?.title ?? 'esta conversa';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Excluir conversa', style: AppTextStyles.bodyLarge),
        content: Text(
          'Excluir "$title"? Esta ação não pode ser desfeita.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _chatController?.deleteConversation(id);
    await _refreshConversations();
    if (_activeConversationId == id) {
      setState(() {
        _activeConversationId = null;
        _messages = [];
      });
    }
  }

  Future<void> _renameConversation(int id, String newTitle) async {
    await _chatController?.renameConversation(id, newTitle);
    await _refreshConversations();
  }

  Future<void> _togglePin(int id, bool pinned) async {
    await _chatController?.togglePin(id, pinned);
    await _refreshConversations();
  }

  Future<void> _exportConversation(int id) async {
    if (_chatController == null) return;
    try {
      final markdown = await _chatController!.exportConversationAsMarkdown(id);
      if (markdown.isEmpty) return;

      // Busca título para nome do arquivo
      final conv = _conversations.where((c) => c.id == id).firstOrNull;
      final title = conv?.title ?? 'conversa';
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final filename = '${safeTitle}_$dateStr.md';

      // Salva via file picker
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar conversa',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['md'],
      );

      if (result != null) {
        await io.File(result).writeAsString(markdown);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversa exportada com sucesso'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openLibrary() {
    if (_documentService == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryScreen(
          documentService: _documentService!,
          collectionId: _activeCollectionId,
        ),
      ),
    );
  }

  /// Dialog para selecionar coluna de agrupamento em CSV/JSON.
  Future<String?> _showGroupByDialog(Uint8List bytes, String filename) async {
    // Detecta colunas disponíveis
    final content = utf8.decode(bytes);
    List<String> columns;

    try {
      if (filename.endsWith('.csv')) {
        final parsed = const CsvToListConverter(eol: '\n').convert(content);
        if (parsed.isEmpty) return null;
        columns = parsed.first.map((h) => h.toString()).toList();
      } else {
        final decoded = jsonDecode(content);
        if (decoded is! List || decoded.isEmpty) return null;
        columns = (decoded.first as Map<String, dynamic>).keys.toList();
      }
    } catch (_) {
      return null;
    }

    if (columns.isEmpty) return null;

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Agrupar por qual coluna?', style: AppTextStyles.bodyLarge),
        content: SizedBox(
          width: 300,
          height: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Arquivo: $filename',
                style: AppTextStyles.techSmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: columns.map((col) => ListTile(
                    title: Text(col, style: AppTextStyles.bodyMedium),
                    dense: true,
                    onTap: () => Navigator.pop(ctx, col),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  String _streamingResponse = '';
  bool _isStreaming = false;
  final _thinkingStopwatch = Stopwatch();

  Future<void> _onDropDone(DropDoneDetails details) async {
    setState(() => _isDragOver = false);

    if (details.files.isEmpty) return;
    final file = details.files.first;
    final ext = file.name.split('.').last.toLowerCase();

    // Markdown / texto plano → diálogo de destino
    if (ext == 'md' || ext == 'txt') {
      final bytes = await file.readAsBytes();
      final content = String.fromCharCodes(bytes);
      _showMdDestinationDialog(file.name, content);
      return;
    }

    // Imagens
    const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
    if (!imageExts.contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Formato inválido: .$ext — aceito: JPG, PNG, GIF, WebP, MD, TXT'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final bytes = await file.readAsBytes();
    final mediaType = ext == 'jpg' || ext == 'jpeg'
        ? 'image/jpeg'
        : ext == 'gif'
            ? 'image/gif'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/png';

    _sendMessageWithImage('', Uint8List.fromList(bytes), mediaType);
  }

  Future<void> _showMdDestinationDialog(String filename, String content) async {
    if (!mounted || _activeConversationId == null) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Destino do arquivo', style: AppTextStyles.bodyLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(filename, style: AppTextStyles.techMedium.copyWith(
              color: AppColors.accentOrange)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('📚', style: TextStyle(fontSize: 24)),
              title: const Text('Adicionar à biblioteca', style: AppTextStyles.bodyMedium),
              subtitle: const Text('Indexa permanentemente na coleção.\nDisponível em todas as conversas.',
                  style: AppTextStyles.techSmall),
              onTap: () => Navigator.pop(ctx, 'library'),
            ),
            Divider(color: Theme.of(context).dividerColor),
            ListTile(
              leading: const Text('📎', style: TextStyle(fontSize: 24)),
              title: const Text('Usar nesta conversa', style: AppTextStyles.bodyMedium),
              subtitle: const Text('Contexto de trabalho temporário.\nSó nesta conversa.',
                  style: AppTextStyles.techSmall),
              onTap: () => Navigator.pop(ctx, 'conversation'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'library') {
      // Fluxo existente de ingestão
      await _documentService?.ingestMarkdown(
        bytes: Uint8List.fromList(content.codeUnits),
        filename: filename,
        collectionId: _activeCollectionId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento adicionado à biblioteca'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await _refreshDocumentCount();
    } else if (choice == 'conversation') {
      await _chatController?.addContextAttachment(
        _activeConversationId!,
        filename,
        content,
      );
      if (mounted) {
        setState(() {}); // Refresh indicador
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento de trabalho anexado à conversa'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _sendMessageWithImage(
    String text,
    Uint8List bytes,
    String mediaType,
  ) async {
    // Redimensiona
    final resized = await ImageResizeService.resize(bytes);

    // Salva em disco
    final appDir = await getApplicationSupportDirectory();
    final imagesDir = io.Directory('${appDir.path}/chat_images');
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }
    final filename = '${const Uuid().v4()}.png';
    final filePath = '${imagesDir.path}/$filename';
    await io.File(filePath).writeAsBytes(resized);

    // Texto default se vazio
    final question = text.isEmpty ? 'descreva e analise esta imagem' : text;

    final attachment = ImageAttachment(
      bytes: resized,
      mediaType: mediaType,
      path: filePath,
    );

    _sendMessageInternal(question, image: attachment);
  }

  Future<void> _sendMessage(String text) =>
      _sendMessageInternal(text);

  Future<void> _sendMessageInternal(String text, {ImageAttachment? image}) async {
    if (_activeConversationId == null || _chatController == null) return;

    final apiKey = AppSettingsCache().get('anthropic_api_key');
    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configure sua chave de API nas Configurações.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // 1. Mostra mensagem do usuário imediatamente
    setState(() {
      _lastFailedQuestion = null;
      _lastError = null;
      _messages = [
        ..._messages,
        Message(
          conversationId: _activeConversationId!,
          role: 'user',
          content: text,
          imagePath: image?.path,
          createdAt: DateTime.now(),
        ),
      ];
      _isLoading = true;
      _isStreaming = true;
      _streamingResponse = '';
      _stopRequested = false;
    });
    _thinkingStopwatch.reset();
    _thinkingStopwatch.start();
    _startThinkingTimer();
    _scrollToBottom();

    try {
      // 2. Streaming da resposta token a token
      await for (final token in _chatController!.askQuestion(
        conversationId: _activeConversationId!,
        question: text,
        model: _selectedModel,
        collectionId: _activeCollectionId,
        collectionInstructions: _activeCollection?.instructions,
        image: image,
      )) {
        if (_stopRequested) break;
        _streamingResponse += token;
        if (mounted) {
          setState(() {});
          _scrollToBottom();
        }
      }

      // 3. Carrega mensagens reais do banco (substitui as temporárias)
      await _loadMessages(_activeConversationId!);
    } on AnthropicException catch (e) {
      if (mounted) {
        setState(() {
          _lastFailedQuestion = text;
          _lastError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastFailedQuestion = text;
          _lastError = e.toString();
        });
      }
    } finally {
      _thinkingStopwatch.stop();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isStreaming = false;
        });
      }
    }
  }

  // --- Estado de importação ---
  double _importProgress = 0.0;
  String _importStatus = '';
  bool _isImporting = false;

  Future<void> _importDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'md', 'txt', 'csv', 'json'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    // Validação: máximo 10 arquivos por lote
    if (result.files.length > 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione no máximo 10 arquivos por vez.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _importStatus = '';
    });

    final totalFiles = result.files.length;
    var successCount = 0;
    final errors = <String>[];

    for (var i = 0; i < totalFiles; i++) {
      final file = result.files[i];
      if (file.bytes == null && file.path == null) continue;

      setState(() {
        _importStatus = 'Processando ${i + 1} de $totalFiles: ${file.name}';
      });

      try {
        final bytes = file.bytes ?? await _readFileBytes(file.path!);
        final isStructured = file.name.endsWith('.csv') || file.name.endsWith('.json');

        if (isStructured) {
          // Dialog para selecionar coluna de agrupamento
          final groupByColumn = await _showGroupByDialog(bytes, file.name);
          if (groupByColumn == null) continue; // Cancelado

          await _documentService?.ingestStructuredData(
            bytes: bytes,
            filename: file.name,
            groupByColumn: groupByColumn,
            sourcePath: file.path,
            collectionId: _activeCollectionId,
            onProgress: (progress) {
              if (mounted) {
                setState(() {
                  _importProgress = (i + progress) / totalFiles;
                });
              }
            },
          );
        } else if (file.name.endsWith('.md') || file.name.endsWith('.txt')) {
          await _documentService?.ingestMarkdown(
            bytes: bytes,
            filename: file.name,
            sourcePath: file.path,
            collectionId: _activeCollectionId,
            onProgress: (progress) {
              if (mounted) {
                setState(() {
                  _importProgress = (i + progress) / totalFiles;
                });
              }
            },
          );
        } else {
          await _documentService?.ingestPdf(
            bytes: bytes,
            filename: file.name,
            sourcePath: file.path,
            collectionId: _activeCollectionId,
            onProgress: (progress) {
              if (mounted) {
                setState(() {
                  _importProgress = (i + progress) / totalFiles;
                });
              }
            },
          );
        }
        successCount++;
      } catch (e) {
        errors.add(file.name);
      }
    }

    await _refreshDocumentCount();

    if (mounted) {
      setState(() {
        _isImporting = false;
        _importProgress = 0.0;
        _importStatus = '';
      });

      if (errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount arquivo(s) importado(s) com sucesso.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$successCount de $totalFiles importado(s). '
              'Falha em: ${errors.join(", ")}',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<Uint8List> _readFileBytes(String path) async {
    return io.File(path).readAsBytes();
  }

  // Cache de chunk_id → {filename, page} para citações
  Map<int, CitationData> _citationCache = {};

  List<CitationData> _parseCitations(Message message) {
    if (message.chunksUsed == null) return [];
    try {
      final ids = jsonDecode(message.chunksUsed!) as List;
      final all = ids
          .map((id) => _citationCache[id as int] ?? CitationData(filename: 'doc #$id'))
          .toList();
      // Deduplicar por filename+page+sourceType via utilitário testado.
      // Em caso de falha no dedup, o utilitário retorna `all` intacto
      // (nunca []) — usuário preserva as fontes brutas.
      return dedupeCitations(all);
    } catch (e, stack) {
      LoggerService.instance.error(
        'chat_screen',
        'Falha ao parsear chunksUsed — sem citações nesta mensagem',
        e,
        stack,
      );
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final showSidebar = _sidebarVisible && screenWidth >= 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // Sidebar com animação de retrair/expandir
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: showSidebar ? 260 : 0,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: showSidebar ? Sidebar(
              collections: _collections,
              activeCollectionId: _activeCollectionId,
              onCollectionChanged: _onCollectionChanged,
              onNewCollection: _createNewCollection,
              conversations: _conversations,
              selectedConversationId: _activeConversationId,
              onConversationSelected: _loadMessages,
              onNewConversation: _createNewConversation,
              onDeleteConversation: _deleteConversation,
              onRenameConversation: _renameConversation,
              onTogglePin: _togglePin,
              onExportConversation: _exportConversation,
              documentCount: _documentCount,
              onOpenDocuments: _importDocument,
              onOpenLibrary: _openLibrary,
              onCollectionSettings: _showCollectionSettings,
              appVersion: _appVersion,
            ) : const SizedBox.shrink(),
          ),

          // Divider
          if (showSidebar)
            VerticalDivider(
              width: 1,
              color: Theme.of(context).dividerColor,
            ),

          // Painel principal
          Expanded(
            child: DropTarget(
              onDragDone: _onDropDone,
              onDragEntered: (_) => setState(() => _isDragOver = true),
              onDragExited: (_) => setState(() => _isDragOver = false),
              child: Stack(
                children: [
                  Column(
              children: [
                // Toolbar
                _buildToolbar(),

                // Barra de progresso de importação
                if (_isImporting) _buildImportProgress(),

                // Mensagens
                Expanded(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(_textScale),
                    ),
                    child: _activeConversationId == null
                      ? _buildEmptyState()
                      : Stack(
                          children: [
                            NotificationListener<ScrollNotification>(
                              onNotification: _handleScrollNotification,
                              child: _buildMessageList(),
                            ),
                            if (_showScrollToBottom)
                              Positioned(
                                right: 16,
                                bottom: 80,
                                child: FloatingActionButton.small(
                                  onPressed: _scrollToBottom,
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  foregroundColor: AppColors.accentOrange,
                                  elevation: 4,
                                  child: const Icon(Icons.keyboard_arrow_down),
                                ),
                              ),
                          ],
                        ),
                  ),
                ),

                // Input
                ChatInput(
                  onSend: _sendMessage,
                  onSendWithImage: _sendMessageWithImage,
                  enabled: !_isLoading && !_isImporting && _activeConversationId != null,
                  isStreaming: _isStreaming,
                  onStop: () => setState(() => _stopRequested = true),
                  selectedModel: _selectedModel,
                  onModelChanged: (model) {
                    setState(() => _selectedModel = model);
                    _updateGenerationService(model);
                  },
                ),
              ],
            ),
                  // Overlay visual durante drag (faixa inferior sutil)
                  if (_isDragOver)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 120,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.accentOrange.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppColors.accentOrange.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined,
                                size: 32,
                                color: AppColors.accentOrange.withValues(alpha: 0.7)),
                            const SizedBox(width: 12),
                            Text('Solte a imagem, .md ou .txt aqui',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.accentOrange)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _sidebarVisible ? Icons.menu_open : Icons.menu,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
          ),
          // Indicador de docs de trabalho
          if (_activeConversationId != null)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _chatController?.getContextAttachments(_activeConversationId!) ??
                  Future.value([]),
              builder: (context, snapshot) {
                final atts = snapshot.data ?? [];
                if (atts.isEmpty) return const SizedBox.shrink();
                return PopupMenuButton<int>(
                  tooltip: 'Documentos de trabalho',
                  child: Chip(
                    avatar: const Icon(Icons.attach_file, size: 14,
                        color: AppColors.accentOrange),
                    label: Text('${atts.length} doc${atts.length > 1 ? 's' : ''}',
                        style: AppTextStyles.techSmall),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  itemBuilder: (_) => atts.map((att) => PopupMenuItem<int>(
                    value: att['id'] as int,
                    child: Row(
                      children: [
                        Expanded(child: Text(
                          att['filename'] as String,
                          style: AppTextStyles.bodySmall,
                        )),
                        const SizedBox(width: 8),
                        const Icon(Icons.close, size: 14, color: AppColors.error),
                      ],
                    ),
                  )).toList(),
                  onSelected: (attId) async {
                    await _chatController?.removeContextAttachment(attId);
                    if (mounted) setState(() {});
                  },
                );
              },
            ),
          const Spacer(),
          // Zoom controls
          IconButton(
            icon: Icon(Icons.remove, size: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            tooltip: 'Diminuir fonte',
            onPressed: () {
              setState(() => _textScale = (_textScale - 0.1).clamp(0.5, 2.0));
              _saveTextScale();
            },
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          Text(
            '${(_textScale * 100).round()}%',
            style: AppTextStyles.techSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, size: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            tooltip: 'Aumentar fonte',
            onPressed: () {
              setState(() => _textScale = (_textScale + 0.1).clamp(0.5, 2.0));
              _saveTextScale();
            },
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            onPressed: () async {
              await Navigator.pushNamed(context, AppRoutes.settings);
              // Recarrega modelo ao voltar de Settings (pode ter sido alterado)
              final savedModel = await SecureStorageService().getDefaultModel();
              if (savedModel != null && savedModel != _selectedModel && mounted) {
                setState(() => _selectedModel = savedModel);
                _updateGenerationService(savedModel);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 64,
            color: AppColors.accentOrange.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Selecione ou crie uma conversa',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Importe documentos e pergunte ao Dart Oráculo',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 24),
          // Prompt starters
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildPromptChip('Resuma meus documentos'),
              _buildPromptChip('O que diz sobre...?'),
              _buildPromptChip('Compare os conceitos de...'),
              _buildPromptChip('Quais os pontos principais?'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversationEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 56,
            color: AppColors.accentOrange.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nova conversa',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Pergunte algo sobre seus documentos',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildPromptChip('Resuma meus documentos'),
              _buildPromptChip('O que diz sobre...?'),
              _buildPromptChip('Compare os conceitos de...'),
              _buildPromptChip('Quais os pontos principais?'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromptChip(String text) {
    return ActionChip(
      label: Text(text, style: AppTextStyles.bodySmall),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      side: BorderSide(color: Theme.of(context).dividerColor),
      onPressed: () async {
        if (_activeConversationId == null) {
          await _createNewConversation();
        }
        if (_activeConversationId != null) {
          _sendMessage(text);
        }
      },
    );
  }

  void _updateGenerationService(String model) {
    if (_chatController == null) return;
    if (model == AppConfig.modelQwen) {
      _chatController!.activeGenerationService = OllamaService();
    } else if (model == AppConfig.modelKimi) {
      _updateKimiService();
    } else {
      // Anthropic com o modelo selecionado
      _chatController!.activeGenerationService = _chatController!.anthropicService;
    }
  }

  Future<void> _updateKimiService() async {
    final cache = AppSettingsCache();
    final kimiKey = cache.get('kimi_api_key');
    if (kimiKey == null || kimiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configure a chave Kimi nas Configurações.'),
            backgroundColor: AppColors.error,
          ),
        );
        // Reverte para Sonnet
        setState(() => _selectedModel = AppConfig.defaultModel);
        _chatController!.activeGenerationService = _chatController!.anthropicService;
      }
      return;
    }

    // Aviso de API externa (primeira vez)
    final dismissed = cache.get(StorageKeys.kimiWarningDismissed);
    if (dismissed != 'true' && mounted) {
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.accentOrange),
              SizedBox(width: 8),
              Text('API Externa'),
            ],
          ),
          content: const Text(
            'A Kimi é uma API externa (Moonshot AI). Não há garantia de que '
            'seus dados não serão usados para treinamento ou estudos pela provedora.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                await SecureStorageService().writeRaw(
                  StorageKeys.kimiWarningDismissed, 'true',
                );
                Navigator.pop(context, true);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.accentOrange),
              child: const Text('Entendi, continuar'),
            ),
          ],
        ),
      );

      if (accepted != true) {
        // Usuário cancelou — reverte
        setState(() => _selectedModel = AppConfig.defaultModel);
        _chatController!.activeGenerationService = _chatController!.anthropicService;
        return;
      }
    }

    _chatController!.activeGenerationService = KimiService(apiKey: kimiKey);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final atBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100;
      if (_showScrollToBottom == atBottom) {
        setState(() => _showScrollToBottom = !atBottom);
      }
    }
    return false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.positions.length == 1) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildImportProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_importStatus, style: AppTextStyles.techSmall),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: _importProgress,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentOrange),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    // Empty state para conversa recém-criada
    if (_messages.isEmpty && !_isStreaming && _lastFailedQuestion == null) {
      return _buildConversationEmptyState();
    }

    // Conta itens: mensagens + streaming bubble (se ativo) + retry bubble (se erro)
    final hasRetry = _lastFailedQuestion != null && !_isStreaming;
    final itemCount =
        _messages.length + (_isStreaming ? 1 : 0) + (hasRetry ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Streaming bubble no final
        if (_isStreaming && index == _messages.length) {
          return _buildStreamingBubble();
        }

        // Retry bubble após todas as mensagens
        if (hasRetry && index == _messages.length) {
          return RetryBubble(
            onRetry: () => _sendMessage(_lastFailedQuestion!),
            errorMessage: _lastError,
          );
        }

        // Guard: index pode exceder se estado mudou durante rebuild
        if (index >= _messages.length) return const SizedBox.shrink();

        final message = _messages[index];
        final isUser = message.role == 'user';

        // Separador de data entre mensagens de dias diferentes
        Widget? dateSeparator;
        if (index == 0 ||
            !_isSameDay(message.createdAt, _messages[index - 1].createdAt)) {
          dateSeparator = _buildDateSeparator(message.createdAt);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (dateSeparator != null) dateSeparator,
            MessageBubble(
              content: message.content,
              isUser: isUser,
              modelUsed: isUser ? null : message.modelUsed,
              feedback: isUser ? null : _feedbacks[message.id],
              isVerifying: !isUser && message.id != null &&
                  _feedbackInProgress.contains(message.id),
              onFeedbackChanged: (isUser || message.id == null)
                  ? null
                  : (value) => _onFeedbackChanged(message.id!, value),
              timestamp: message.createdAt,
              imagePath: message.imagePath,
            ),
            if (!isUser && message.id != null)
              CitationStrip(
                citations: _parseCitations(message),
                responseSource: message.responseSource,
              ),
          ],
        );
      },
    );
  }

  void _startThinkingTimer() {
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!_isStreaming || !mounted) return false;
      setState(() {}); // Rebuild para atualizar cronômetro
      return true;
    });
  }

  String _formatElapsed(Duration d) {
    final seconds = d.inSeconds;
    if (seconds < 60) return '${seconds}s';
    return '${seconds ~/ 60}m ${seconds % 60}s';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Hoje';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(date, yesterday)) return 'Ontem';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 48),
      child: Row(
        children: [
          Expanded(child: Divider(color: Theme.of(context).dividerColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDateLabel(date),
              style: AppTextStyles.techSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(child: Divider(color: Theme.of(context).dividerColor)),
        ],
      ),
    );
  }

  Widget _buildStreamingBubble() {
    if (_streamingResponse.isEmpty) {
      final elapsed = _thinkingStopwatch.elapsed;
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomLeft: const Radius.circular(4),
            ),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentOrange.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Pensando... ${_formatElapsed(elapsed)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Resposta parcial em streaming
    return MessageBubble(
      content: _streamingResponse,
      isUser: false,
      modelUsed: _selectedModel,
    );
  }

  // Lock para impedir cliques múltiplos durante verificação
  final _feedbackInProgress = <int>{};

  Future<void> _onFeedbackChanged(int messageId, String? value) async {
    // Debounce — ignora se já está processando este messageId
    if (_feedbackInProgress.contains(messageId)) return;
    _feedbackInProgress.add(messageId);

    // Mostra estado "verificando" no botão
    setState(() => _feedbacks[messageId] = value);

    try {
      final result = await _chatController?.setFeedback(messageId, value);

      // Se checagem de fidelidade ou conhecimento geral pede confirmação
      if (result != null && result.needsConfirmation && mounted) {
        final dialogMessage = result.confirmationMessage ??
            'Esta resposta contém afirmações que não foram encontradas '
            'nos documentos consultados. Deseja promovê-la mesmo assim?';
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text('Confirmação de promoção',
                style: AppTextStyles.bodyLarge),
            content: Text(
              dialogMessage,
              style: AppTextStyles.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                ),
                child: const Text('Promover'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await _chatController?.forcePromote(messageId);
        } else {
          // Cancela o like
          await _chatController?.setFeedback(messageId, null);
        }
      }
    } finally {
      _feedbackInProgress.remove(messageId);
    }

    if (mounted) {
      // Recarregar estado real do feedback
      final actual = await _chatController?.getFeedback(messageId);
      setState(() => _feedbacks[messageId] = actual);
    }
  }
}
