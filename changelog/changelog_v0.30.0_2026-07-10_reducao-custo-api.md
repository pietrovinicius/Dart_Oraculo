## [0.30.0] - 2026-07-10

### Adicionado
- **library_screen.dart**: Botão "Excluir" em cada documento da Biblioteca — remove documento + todos os chunks do FTS5 com confirmação.
- **docs/PLANO_REDUCAO_CUSTO_API.md**: Plano completo com 6 soluções para redução de custo da API Claude.

### Corrigido
- **chat_controller.dart**: Truncagem de contexto RAG agora respeita `chunk_max_tokens` do Settings (user × 4 chars) em vez do permissivo `maxContextCharsPerChunk` do motor (20.000 chars). Reduz custo de ~$0.22 para ~$0.005/consulta com config 300 tokens.

### Comportamento
- Config "Tamanho do chunk = 300" → cada chunk no contexto limitado a 1200 chars máximo.
- 5 chunks × 1200 chars = ~6KB = ~1.500 tokens input (antes: 73.000 tokens com CSVs gigantes).
- Botão excluir remove documento e chunks permanentemente — ação irreversível com confirmação.
