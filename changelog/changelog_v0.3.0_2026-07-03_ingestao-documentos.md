## [0.3.0] - 2026-07-03

### Adicionado
- **lib/core/services/pdf_service.dart**: extração de texto nativo de PDF por página usando syncfusion_flutter_pdf. Retorna lista de PdfPageResult (pageNumber + texto).
- **lib/core/services/chunking_service.dart**: fragmentação de texto em chunks por parágrafo com limite configurável de tokens (~500 default). Parágrafos longos subdivididos por sentença. Ignora conteúdo vazio.
- **lib/features/documents/document_service.dart**: orquestra fluxo completo de ingestão — extração → chunking → persistência em documents/chunks com FTS5 indexado automaticamente via triggers. CRUD de documentos (list, getChunks, delete com cascade).
- **lib/features/documents/models/document.dart**: modelo Document com toMap/fromMap.
- **lib/features/documents/models/chunk.dart**: modelo Chunk com toMap/fromMap.
- **test/unit/services/pdf_service_test.dart**: 4 testes (uma página, múltiplas, sem texto, bytes inválidos).
- **test/unit/services/chunking_service_test.dart**: 6 testes (parágrafos, páginas, subdivisão, vazios).
- **test/unit/features/documents/document_service_test.dart**: 6 testes (ingestão, chunks persistidos, FTS5 indexado, listagem, delete com cascade em banco e FTS).
