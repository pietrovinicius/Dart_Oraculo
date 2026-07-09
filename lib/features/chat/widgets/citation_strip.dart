import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Dados de citação para exibição.
class CitationData {
  const CitationData({
    required this.filename,
    this.page,
    this.snippet,
    this.sourceType,
    this.promotedDate,
  });

  final String filename;
  final int? page;
  final String? snippet;
  final String? sourceType; // 'document' | 'promoted_answer'
  final String? promotedDate; // DD/MM/YYYY quando promoted_answer
}

/// Faixa de citação exibida abaixo de cada resposta do assistant.
/// Mostra documentos e trechos consultados.
class CitationStrip extends StatelessWidget {
  const CitationStrip({
    super.key,
    required this.citations,
    this.responseSource,
  });

  final List<CitationData> citations;
  /// Origem da resposta: 'rag' | 'general' | 'web'
  final String? responseSource;

  @override
  Widget build(BuildContext context) {
    // Indicador de conhecimento geral quando sem citações
    if (responseSource == 'general' && citations.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Resposta baseada no conhecimento geral do modelo — sem fonte nos seus documentos',
                style: AppTextStyles.techSmall.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    if (citations.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fontes consultadas',
            style: AppTextStyles.techSmall.copyWith(
              color: AppColors.accentOrange,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: citations.map((c) => _buildChip(context, c)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, CitationData citation) {
    final String label;
    if (citation.sourceType == 'promoted_answer') {
      label = 'Resposta aprovada (${citation.promotedDate ?? "?"})';
    } else {
      label = citation.page != null
          ? '${citation.filename} (p.${citation.page})'
          : citation.filename;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: citation.sourceType == 'promoted_answer'
            ? AppColors.accentOrange.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: citation.sourceType == 'promoted_answer'
              ? AppColors.accentOrange.withValues(alpha: 0.4)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Text(label, style: AppTextStyles.techSmall),
    );
  }
}
