## [0.8.0] - 2026-07-03

### Adicionado
- **test/integration/rag_flow_test.dart**: 3 testes end-to-end cobrindo fluxo RAG completo — ingestão de múltiplos PDFs → busca FTS5 → chat com contexto → persistência de citações. Cobre cenários: com documentos indexados, sem documentos, e múltiplas perguntas com histórico.

### Verificado
- 83 testes passando (unit + widget + integration).
- `flutter analyze` sem issues.
- `flutter build macos --debug` compilando com sucesso.
- Critério de pronto da Fase 1 atendido: fluxo ingestão → busca → resposta rastreável à fonte funcional.
