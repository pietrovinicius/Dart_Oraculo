# Design — Higiene conservadora do repositório e sincronização de versão

## Contexto

O projeto Dart Oráculo está em fase de hardening. A linha recente de commits corrigiu falhas silenciosas em reindexação, deduplicação de chunks, verificação de fidelidade, feedback de erro e integração com Keychain.

O estado atual mostra:

- `main` alinhada com `origin/main`.
- `pubspec.yaml` ainda em `0.31.0+1`.
- changelog fragments já em `0.34.0`.
- working tree suja por artefatos de análise e dados locais (`graphify-out/`, `.superpowers/`, `csv/`, `dicionario_tasy/`, `sql/`, `.DS_Store`).

## Objetivo

Executar uma higiene conservadora que prepare o repositório para novas tarefas sem apagar dados locais e sem alterar lógica de produção.

## Escopo aprovado

1. Não remover arquivos nem pastas.
2. Atualizar `.gitignore` para evitar rastreamento futuro de artefatos óbvios.
3. Preservar `csv/`, `dicionario_tasy/` e `sql/` no disco.
4. Sincronizar `pubspec.yaml` com a versão mais recente observada nos fragments: `0.34.0+1`.
5. Criar changelog fragment para a tarefa.
6. Rodar `flutter analyze`.
7. Rodar `flutter test`.
8. Se validações passarem, commitar arquivos alterados sem `git push`.

## Fora de escopo

- Alterar lógica Dart/Flutter.
- Corrigir testes falhando que não tenham relação direta com a higiene.
- Apagar caches, outputs ou dados locais.
- Editar `CHANGELOG.md` principal.
- Executar `git push`.

## Abordagem escolhida

Abordagem conservadora.

### `.gitignore`

Adicionar entradas para artefatos gerados e dados locais que hoje aparecem no `git status`:

- `graphify-out/`
- `.superpowers/`
- `csv/`
- `dicionario_tasy/`
- `sql/`

`.DS_Store` já está ignorado, mas permanece modificado porque já foi rastreado anteriormente. Como a limpeza aprovada não remove nada, ele não será apagado.

### Versão

Atualizar `pubspec.yaml`:

```yaml
version: 0.34.0+1
```

Motivo: alinhar versão declarada do app com os fragments e commits mais recentes (`v0.34.0`).

### Changelog fragment

Criar:

```text
changelog/changelog_v0.34.0_2026-07-22_sync-version-ignore-artifacts.md
```

Conteúdo: seção `Alterado`, mencionando `.gitignore` e `pubspec.yaml`.

### Validação

Rodar na raiz do projeto:

```bash
flutter analyze
flutter test
```

Se `flutter` do PATH falhar por ambiente, tentar somente se necessário o SDK local documentado pelo projeto.

## Critério de conclusão

A tarefa só será marcada como concluída se:

- `.gitignore`, `pubspec.yaml` e changelog fragment forem atualizados.
- `flutter analyze` concluir sem erro.
- `flutter test` concluir sem erro.
- commit local for criado com mensagem em português.
- nenhum `git push` for executado.

## Riscos

- `.DS_Store` já rastreado continuará aparecendo no working tree se não for removido do índice.
- `graphify-out/` já rastreado pode continuar aparecendo como modificado mesmo após `.gitignore`, pois `.gitignore` não afeta arquivos já rastreados.
- Testes podem falhar por ambiente local, dependências ou problemas preexistentes.

## Tratamento de falhas

- Se validação falhar, reportar a saída relevante e parar antes do commit final da tarefa.
- Se houver conflito entre versão declarada e tags futuras, manter `0.34.0+1` porque é a versão mais alta documentada nos fragments atuais.
