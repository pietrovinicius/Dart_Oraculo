## [0.34.0] - 2026-07-15

### Corrigido
- **chat_screen.dart**: RAG dedup retorna agora lista original (nunca `[]`) quando falha — usuário preserva fontes brutas em vez de ver falso "nenhuma fonte encontrada".
- **citation_dedup.dart**: novo utilitário testado para deduplicação de citações com fallback robusto. Garante que erros silenciosos não causam perda de dados.
