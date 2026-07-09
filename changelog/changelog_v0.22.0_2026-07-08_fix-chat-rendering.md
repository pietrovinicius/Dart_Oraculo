## [0.22.0] - 2026-07-08

### Corrigido
- **message_bubble.dart**: Removido botão "Copiar" redundante do footer — mantém apenas copiar por code block (padrão Claude Desktop).
- **message_bubble.dart**: `blockSpacing: 6` no MarkdownStyleSheet — reduz espaçamento excessivo entre parágrafos.
- **message_bubble.dart**: Code block margin reduzida de 8px para 4px vertical.
- **message_bubble.dart**: Newlines triplos (`\n\n\n+`) colapsados para `\n\n` antes do render.
- **message_bubble.dart**: Ícones like/dislike aumentados de 16px para 20px + cor dinâmica do tema.
- **chat_screen.dart**: Citações deduplicadas por (filename + page + sourceType) — não repete "Oracle.pdf (p.1)" 10 vezes.
