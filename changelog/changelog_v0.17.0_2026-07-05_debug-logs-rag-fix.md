## [0.17.0] - 2026-07-05

### Corrigido
- **fts_service.dart**: Bug crítico — `words.join(' OR ')` retornava chunks irrelevantes. Agora usa AND implícito (FTS5 default).
- **fts_service.dart**: Stopwords pt-BR/en removidas da query ("o", "que", "da", "the", "is", etc.).
- **fts_service.dart**: Termos com underscore (ADEP_V) preservados como phrase match exata.

### Adicionado
- **chat_controller.dart**: Logs detalhados — cada chunk retornado com rank + preview 80 chars, tamanho contexto em KB, contagem de truncados.
- **fts_service.dart**: Log da query sanitizada + warning quando query vira vazia.
- **anthropic_service.dart**: Prompt RAG melhorado com 5 instruções claras (citar fonte, não inventar, informação parcial).
- **chat_controller.dart**: Contexto formatado com metadados (fonte, página, relevância) por chunk.
- **fts_service_test.dart**: 4 testes novos — stopwords, underscore, AND implícito, query vazia.
