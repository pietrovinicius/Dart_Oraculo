## [0.8.0] - 2026-07-03

### Adicionado
- **lib/core/services/markdown_normalizer.dart**: normalização de texto bruto de PDF para markdown estruturado. Heurísticas calibradas com Oracle.pdf real: títulos de capítulo (dígito+maiúscula), seções numeradas, ALL CAPS, linhas de sumário como lista, remoção de watermark, marcação de quebra de página.
- **lib/features/documents/document_service.dart (ingestMarkdown)**: método para ingestão direta de arquivos .md — chunking sem extração de PDF, page null no schema.
- **test/unit/services/markdown_normalizer_test.dart**: 9 testes cobrindo todos os padrões heurísticos.
- **test/unit/features/documents/document_service_test.dart**: 3 novos testes para ingestão de markdown (criação, FTS5, page null).
- **AGENTS.md**: ADR-012 (conformidade Syncfusion Community License — registerLicense deprecated na v25.x), ADR-013 (normalização PDF→markdown), ADR-014 (markdown como formato de entrada).

### Alterado
- **lib/features/documents/document_service.dart**: pipeline de PDF agora normaliza para markdown antes do chunking (conforme seção 7 da especificação).
- **lib/features/chat/chat_screen.dart**: file_picker aceita extensões .pdf e .md, despacha para método correto.
