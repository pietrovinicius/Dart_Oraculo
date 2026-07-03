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
  final _storageService = SecureStorageService();

  List<Conversation> _conversations = [];
  List<Message> _messages = [];
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

    await _refreshConversations();
    await _refreshDocumentCount();
  }

  Future<void> _refreshConversations() async {
    final convs = await _chatController?.listConversations() ?? [];
    if (mounted) {
      setState(() => _conversations = convs);
    }
  }

  Future<void> _refreshDocumentCount() async {
    final docs = await _documentService?.listDocuments() ?? [];
    if (mounted) {
      setState(() => _documentCount = docs.length);
    }
  }

  Future<void> _loadMessages(int conversationId) async {
    final msgs = await _chatController?.getMessages(conversationId) ?? [];
    if (mounted) {
      setState(() {
        _activeConversationId = conversationId;
        _messages = msgs;
      });
    }
  }

  Future<void> _createNewConversation() async {
    final conv = await _chatController?.createConversation(
      title: 'Nova conversa',
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
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null && file.path == null) return;

    setState(() => _isLoading = true);

    try {
      final bytes = file.bytes ?? await _readFileBytes(file.path!);
      await _documentService?.ingestPdf(
        bytes: bytes,
        filename: file.name,
        sourcePath: file.path,
      );
      await _refreshDocumentCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${file.name}" importado com sucesso.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              conversations: _conversations,
              selectedConversationId: _activeConversationId,
              onConversationSelected: _loadMessages,
              onNewConversation: _createNewConversation,
              onDeleteConversation: _deleteConversation,
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

                // Mensagens
                Expanded(
                  child: _activeConversationId == null
                      ? _buildEmptyState()
                      : _buildMessageList(),
                ),

                // Input
                ChatInput(
                  onSend: _sendMessage,
                  enabled: !_isLoading && _activeConversationId != null,
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
                child: Text('Sonnet 5'),
              ),
              DropdownMenuItem(
                value: AppConfig.modelOpus,
                child: Text('Opus 4.8'),
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
            ),
            if (!isUser)
              CitationStrip(citations: _parseCitations(message)),
          ],
        );
      },
    );
  }
}
