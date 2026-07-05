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
  const CitationStrip({super.key, required this.citations});

  final List<CitationData> citations;

  @override
  Widget build(BuildContext context) {
    if (citations.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
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
            children: citations.map((c) => _buildChip(c)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(CitationData citation) {
    final String label;
    if (citation.sourceType == 'promoted_answer') {
      label = 'Resposta aprovada (${citation.promotedDate ?? "?"})';
    } else {
      label = citation.page != null
          ? '${citation.filename} (p.${citation.page})'
          : citation.filename;
    }

    return Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: citation.sourceType == 'promoted_answer'
          ? AppColors.accentOrange.withValues(alpha: 0.1)
          : AppColors.surface,
      side: BorderSide(
        color: citation.sourceType == 'promoted_answer'
            ? AppColors.accentOrange.withValues(alpha: 0.4)
            : AppColors.divider,
      ),
      label: Text(label, style: AppTextStyles.techSmall),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
