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
    return 'PDF';
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
                  doc.filename.endsWith('.md')
                      ? Icons.description_outlined
                      : Icons.picture_as_pdf_outlined,
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Extrair .md'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentOrange,
                ),
                onPressed: () => _exportDocument(doc),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
