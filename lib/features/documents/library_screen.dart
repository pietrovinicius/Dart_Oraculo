import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'document_service.dart';
import 'models/document.dart';

/// Tela de biblioteca — lista todos os documentos da coleção ativa.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.documentService,
    this.collectionId,
  });

  final DocumentService documentService;
  final int? collectionId;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Document> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final docs = await widget.documentService.listDocuments();
    final filtered = widget.collectionId == null
        ? docs
        : docs.where((d) => d.collectionId == widget.collectionId).toList();
    if (mounted) {
      setState(() {
        _documents = filtered;
        _isLoading = false;
      });
    }
  }

  String _docType(String filename) {
    if (filename.endsWith('.md')) return 'Markdown';
    if (filename.endsWith('.csv')) return 'CSV';
    if (filename.endsWith('.json')) return 'JSON';
    return 'PDF';
  }

  IconData _docIcon(String filename) {
    if (filename.endsWith('.md')) return Icons.description_outlined;
    if (filename.endsWith('.csv')) return Icons.table_chart_outlined;
    if (filename.endsWith('.json')) return Icons.data_object_outlined;
    return Icons.picture_as_pdf_outlined;
  }

  Future<void> _confirmDelete(Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Excluir documento'),
        content: Text(
          'Excluir "${doc.filename}" e todos os seus chunks indexados?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.documentService.deleteDocument(doc.id!);
      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${doc.filename}" excluído.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportDocument(Document doc) async {
    try {
      final exportPath = await widget.documentService.exportAsMarkdown(doc.id!);

      if (!mounted) return;

      // Oferece salvar em local escolhido pelo usuário
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar markdown exportado',
        fileName: '${doc.filename.replaceAll(RegExp(r'\.[^.]+\$'), '')}.md',
      );

      if (savePath != null) {
        await File(exportPath).copy(savePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exportado para: $savePath'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Biblioteca de Documentos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentOrange),
            )
          : _documents.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum documento na coleção',
                    style: AppTextStyles.bodyMedium,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) =>
                      _buildDocumentCard(_documents[index]),
                ),
    );
  }

  Widget _buildDocumentCard(Document doc) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _docIcon(doc.filename),
                  color: AppColors.accentOrange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    doc.filename,
                    style: AppTextStyles.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text(_docType(doc.filename), style: AppTextStyles.techSmall),
                  backgroundColor: AppColors.surfaceLight,
                  side: const BorderSide(color: AppColors.divider),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              dateFormat.format(doc.importedAt),
              style: AppTextStyles.techSmall,
            ),
            if (doc.description != null && doc.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                doc.description!,
                style: AppTextStyles.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Excluir'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  onPressed: () => _confirmDelete(doc),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Extrair .md'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentOrange,
                  ),
                  onPressed: () => _exportDocument(doc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
