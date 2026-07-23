# Plano — descrição de documentos com provider selecionado

## Objetivo

Fazer a descrição automática de documentos respeitar o provider escolhido pelo usuário nas configurações. Se `kimi-k2.6` estiver selecionado e houver `kimi_api_key`, a descrição deve ser gerada via Kimi/Moonshot, não via Anthropic.

## Causa-raiz

`lib/features/chat/chat_screen.dart` inicializa `DocumentService` com `generationService` calculado apenas para Qwen/Ollama ou Anthropic. Não existe branch Kimi para descrição. Depois, `_updateGenerationService()` troca o provider do chat, mas não recria o `DocumentService`, então a ingestão mantém provider antigo.

## Implementação

1. Criar teste RED para resolver de provider de descrição.
2. Criar helper testável `ChatDescriptionGenerationServiceResolver` em `lib/features/chat/chat_description_generation_service_resolver.dart`.
3. Usar resolver em `ChatScreen._initialize()` ao criar `DocumentService`.
4. Recriar `DocumentService` quando o modelo ativo mudar em runtime.
5. Adicionar teste de `DocumentService` com `KimiService` para provar que descrição salva vem de Kimi.
6. Rodar `dart format`, `flutter analyze` e testes focados.
7. Criar changelog fragment em `changelog/`.

## Arquivos

- `lib/features/chat/chat_description_generation_service_resolver.dart`: resolver puro de provider de descrição.
- `lib/features/chat/chat_screen.dart`: injeta resolver e ressincroniza `DocumentService`.
- `test/unit/features/chat/chat_description_generation_service_resolver_test.dart`: testes RED/GREEN do resolver.
- `test/unit/features/documents/document_service_test.dart`: teste de descrição via `KimiService`.
- `changelog/changelog_v0.34.0_2026-07-23_descricao-kimi.md`: fragmento.

## Verificação

```bash
flutter test test/unit/features/chat/chat_description_generation_service_resolver_test.dart
flutter test test/unit/features/documents/document_service_test.dart --plain-name "usa Kimi quando KimiService é o GenerationService configurado"
flutter test test/unit/services/kimi_service_test.dart
flutter analyze
```

## Restrições

- TDD obrigatório.
- Não editar `CHANGELOG.md`.
- Não executar `git push`.
- Sem refatoração fora do fluxo de provider de descrição.
