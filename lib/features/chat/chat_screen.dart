import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_routes.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/anthropic_service.dart';
import '../../core/services/chunking_service.dart';
import '../../core/services/fts_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../collections/collection_service.dart';
import '../collections/models/collection.dart';
import '../documents/document_service.dart';
import 'chat_controller.dart';
import 'models/conversation.dart';
import 'models/message.dart';
import 'widgets/chat_input.dart';
import 'widgets/citation_strip.dart';
import 'widgets/message_bubble.dart';
import 'widgets/sidebar.dart';

/// Tela principal — sidebar + painel de chat.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final db = await DatabaseHelper.instance.database;
    final ftsService = FtsService(database: db);

    final apiKey = await _storageService.getApiKey();
    final model = await _storageService.getDefaultModel();

    if (model != null) {
      _selectedModel = model;
    }

    _chatController = ChatController(
      database: db,
      anthropicService: AnthropicService(
        apiKey: apiKey ?? '',
        httpClient: null,
      ),
      ftsService: ftsService,
    );

    _documentService = DocumentService(
      database: db,
      pdfService: PdfService(),
      chunkingService: ChunkingService(),
    );

    _collectionService = CollectionService(database: db);

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
        backgroundColor: AppColors.surface,
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
    if (mounted) {
      setState(() {
        _activeConversationId = conversationId;
        _messages = msgs;
        _feedbacks = feedbacks;
      });
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

  Future<void> _sendMessage(String text) async {
    if (_activeConversationId == null || _chatController == null) return;

    final apiKey = await _storageService.getApiKey();
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

    setState(() => _isLoading = true);

    try {
      final responseBuffer = StringBuffer();
      await for (final token in _chatController!.askQuestion(
        conversationId: _activeConversationId!,
        question: text,
        model: _selectedModel,
        collectionId: _activeCollectionId,
        collectionInstructions: _activeCollection?.instructions,
      )) {
        responseBuffer.write(token);
        // Atualiza UI incrementalmente
        if (mounted) setState(() {});
      }

      await _loadMessages(_activeConversationId!);
    } on AnthropicException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro da API: ${e.message}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro inesperado: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Estado de importação ---
  double _importProgress = 0.0;
  String _importStatus = '';
  bool _isImporting = false;

  Future<void> _importDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'md'],
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
        if (file.name.endsWith('.md')) {
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

  List<CitationData> _parseCitations(Message message) {
    if (message.chunksUsed == null) return [];
    try {
      final ids = jsonDecode(message.chunksUsed!) as List;
      // Citações simplificadas — em produção faria lookup no banco
      return ids
          .map((id) => CitationData(filename: 'chunk #$id'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar
          if (_sidebarVisible)
            Sidebar(
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
              documentCount: _documentCount,
              onOpenDocuments: _importDocument,
            ),

          // Divider
          if (_sidebarVisible)
            const VerticalDivider(
              width: 1,
              color: AppColors.divider,
            ),

          // Painel principal
          Expanded(
            child: Column(
              children: [
                // Toolbar
                _buildToolbar(),

                // Barra de progresso de importação
                if (_isImporting) _buildImportProgress(),

                // Mensagens
                Expanded(
                  child: _activeConversationId == null
                      ? _buildEmptyState()
                      : _buildMessageList(),
                ),

                // Input
                ChatInput(
                  onSend: _sendMessage,
                  enabled: !_isLoading && !_isImporting && _activeConversationId != null,
                ),
              ],
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _sidebarVisible ? Icons.menu_open : Icons.menu,
              color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
          ),
          const Spacer(),
          // Seletor de modelo
          DropdownButton<String>(
            value: _selectedModel,
            dropdownColor: AppColors.surface,
            style: AppTextStyles.techMedium,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(
                value: AppConfig.modelSonnet,
                child: Text('Sonnet'),
              ),
              DropdownMenuItem(
                value: AppConfig.modelOpus,
                child: Text('Opus'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedModel = value);
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textSecondary),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
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
            'Importe documentos e pergunte ao Oráculo',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildImportProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_importStatus, style: AppTextStyles.techSmall),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: _importProgress,
            backgroundColor: AppColors.surfaceLight,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentOrange),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isUser = message.role == 'user';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MessageBubble(
              content: message.content,
              isUser: isUser,
              modelUsed: isUser ? null : message.modelUsed,
              feedback: isUser ? null : _feedbacks[message.id],
              onFeedbackChanged: isUser
                  ? null
                  : (value) => _onFeedbackChanged(message.id!, value),
            ),
            if (!isUser)
              CitationStrip(citations: _parseCitations(message)),
          ],
        );
      },
    );
  }

  Future<void> _onFeedbackChanged(int messageId, String? value) async {
    await _chatController?.setFeedback(messageId, value);
    if (mounted) {
      setState(() {
        _feedbacks[messageId] = value;
        // Se foi toggle-off (mesmo valor), remove do mapa
        if (value != null && _feedbacks[messageId] == value) {
          // Recarregar para garantir estado correto
        }
      });
      // Recarregar estado real do feedback
      final actual = await _chatController?.getFeedback(messageId);
      if (mounted) setState(() => _feedbacks[messageId] = actual);
    }
  }
}
