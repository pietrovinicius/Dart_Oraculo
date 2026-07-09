# Graph Report - .  (2026-07-08)

## Corpus Check
- 169 files · ~132,617 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 670 nodes · 868 edges · 73 communities (50 shown, 23 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 31 edges (avg confidence: 0.89)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Chat Controller & Core Services|Chat Controller & Core Services]]
- [[_COMMUNITY_RAG Pipeline & Search|RAG Pipeline & Search]]
- [[_COMMUNITY_App Config & Theme|App Config & Theme]]
- [[_COMMUNITY_UX Improvements & Accessibility|UX Improvements & Accessibility]]
- [[_COMMUNITY_Widget Rendering & Markdown|Widget Rendering & Markdown]]
- [[_COMMUNITY_App Initialization & Generation|App Initialization & Generation]]
- [[_COMMUNITY_Document Ingestion & PDF|Document Ingestion & PDF]]
- [[_COMMUNITY_Secure Storage & Auth|Secure Storage & Auth]]
- [[_COMMUNITY_API Integration & Fidelity|API Integration & Fidelity]]
- [[_COMMUNITY_Chat Input & Speech|Chat Input & Speech]]
- [[_COMMUNITY_Database Migrations & Tests|Database Migrations & Tests]]
- [[_COMMUNITY_Core Services Layer|Core Services Layer]]
- [[_COMMUNITY_Chunking & Normalization|Chunking & Normalization]]
- [[_COMMUNITY_Image Processing & Clipboard|Image Processing & Clipboard]]
- [[_COMMUNITY_Document Library & UI|Document Library & UI]]
- [[_COMMUNITY_Module 15|Module 15]]
- [[_COMMUNITY_Module 16|Module 16]]
- [[_COMMUNITY_Module 17|Module 17]]
- [[_COMMUNITY_Module 18|Module 18]]
- [[_COMMUNITY_Module 19|Module 19]]
- [[_COMMUNITY_Module 20|Module 20]]
- [[_COMMUNITY_Module 21|Module 21]]
- [[_COMMUNITY_Module 22|Module 22]]
- [[_COMMUNITY_Module 23|Module 23]]
- [[_COMMUNITY_Module 24|Module 24]]
- [[_COMMUNITY_Module 25|Module 25]]
- [[_COMMUNITY_Module 26|Module 26]]
- [[_COMMUNITY_Module 27|Module 27]]
- [[_COMMUNITY_Module 28|Module 28]]
- [[_COMMUNITY_Module 29|Module 29]]
- [[_COMMUNITY_Module 30|Module 30]]
- [[_COMMUNITY_Module 31|Module 31]]
- [[_COMMUNITY_Module 32|Module 32]]
- [[_COMMUNITY_Module 33|Module 33]]
- [[_COMMUNITY_Module 34|Module 34]]
- [[_COMMUNITY_Module 35|Module 35]]
- [[_COMMUNITY_Module 36|Module 36]]
- [[_COMMUNITY_Module 37|Module 37]]
- [[_COMMUNITY_Module 38|Module 38]]
- [[_COMMUNITY_Module 39|Module 39]]
- [[_COMMUNITY_Module 40|Module 40]]
- [[_COMMUNITY_Module 41|Module 41]]
- [[_COMMUNITY_Module 42|Module 42]]
- [[_COMMUNITY_Module 43|Module 43]]
- [[_COMMUNITY_Module 44|Module 44]]
- [[_COMMUNITY_Module 45|Module 45]]
- [[_COMMUNITY_Module 46|Module 46]]
- [[_COMMUNITY_Module 47|Module 47]]
- [[_COMMUNITY_Module 48|Module 48]]
- [[_COMMUNITY_Module 49|Module 49]]
- [[_COMMUNITY_Module 50|Module 50]]
- [[_COMMUNITY_Module 51|Module 51]]
- [[_COMMUNITY_Module 52|Module 52]]
- [[_COMMUNITY_Module 53|Module 53]]
- [[_COMMUNITY_Module 54|Module 54]]
- [[_COMMUNITY_Module 55|Module 55]]
- [[_COMMUNITY_Module 56|Module 56]]
- [[_COMMUNITY_Module 57|Module 57]]
- [[_COMMUNITY_Module 58|Module 58]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter_test/flutter_test.dart` - 36 edges
2. `package:flutter/material.dart` - 24 edges
3. `package:sqflite_common_ffi/sqflite_ffi.dart` - 18 edges
4. `dart:convert` - 16 edges
5. `package:http/http.dart` - 14 edges
6. `dart:typed_data` - 14 edges
7. `package:dart_oraculo/core/database/migrations.dart` - 12 edges
8. `Plano Imagem no Chat` - 12 edges
9. `Plano Implementação UX Chat` - 12 edges
10. `package:http/testing.dart` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Screenshot: Chat Active Conversation` --demonstrates--> `MessageBubble Widget`  [INFERRED]
  design/screenshots/Captura de Tela 2026-07-03 às 19.10.11.png → docs/PLANO_IMPLEMENTACAO_UX_CHAT.md
- `Screenshot: Chat Active Conversation` --demonstrates--> `ChatInput Widget`  [INFERRED]
  design/screenshots/Captura de Tela 2026-07-03 às 19.10.11.png → docs/PLANO_IMPLEMENTACAO_UX_CHAT.md
- `Screenshot: Sidebar with Collections` --demonstrates--> `Sidebar Widget`  [INFERRED]
  design/screenshots/Captura de Tela 2026-07-03 às 19.10.48.png → docs/PLANO_IMPLEMENTACAO_UX_CHAT.md
- `Sidebar Conversations List` --renders--> `Sidebar Widget`  [INFERRED]
  design/screenshots/Captura de Tela 2026-07-03 às 19.10.11.png → docs/PLANO_IMPLEMENTACAO_UX_CHAT.md
- `Screenshot: Settings Screen` --demonstrates_ui_for--> `SecureStorageService`  [INFERRED]
  design/screenshots/Captura de Tela 2026-07-03 às 19.10.34.png → docs/PLANO_SEGURANCA_E_CHANGELOG.md

## Communities (73 total, 23 thin omitted)

### Community 0 - "Chat Controller & Core Services"
Cohesion: 0.04
Nodes (55): chat_controller.dart, ../collections/collection_service.dart, ../../core/database/database_helper.dart, ../../core/services/image_resize_service.dart, ../../core/services/ollama_service.dart, ../documents/document_service.dart, ../documents/library_screen.dart, package:package_info_plus/package_info_plus.dart (+47 more)

### Community 1 - "RAG Pipeline & Search"
Cohesion: 0.05
Nodes (52): AnthropicService, Auditoria v0.13.2 (2026-07-04), Brave Search API, Cascade Fallback Search Strategy, ChatController, Bug: Citação mostra chunk #ID vs filename, ClipboardImageService, conversation_context_attachments Table (+44 more)

### Community 2 - "App Config & Theme"
Cohesion: 0.05
Nodes (41): ../../core/config/app_routes.dart, ../../core/services/logger_service.dart, ../../core/services/secure_storage_service.dart, core/theme/app_theme.dart, ../../core/theme/theme_notifier.dart, features/auth/lock_screen.dart, features/chat/chat_screen.dart, features/settings/settings_screen.dart (+33 more)

### Community 3 - "UX Improvements & Accessibility"
Cohesion: 0.07
Nodes (40): Accessibility Semantics Labels, Biometric Authentication (local_auth), ChatInput Widget, ChatScreen Widget, Citação Clicável, B2: Code block detecção linguagem, Code Block com Detecção de Linguagem, Collapse/Expand Respostas Longas (+32 more)

### Community 4 - "Widget Rendering & Markdown"
Cohesion: 0.06
Nodes (31): dart:io, package:flutter_markdown/flutter_markdown.dart, package:markdown/markdown.dart, package:speech_to_text/speech_to_text.dart, error, info, init, _log (+23 more)

### Community 5 - "App Initialization & Generation"
Cohesion: 0.07
Nodes (27): app.dart, ../config/app_config.dart, generation_service.dart, logger_service.dart, migrations.dart, ../models/image_attachment.dart, package:path/path.dart, package:path_provider/path_provider.dart (+19 more)

### Community 6 - "Document Ingestion & PDF"
Cohesion: 0.11
Nodes (18): package:dart_oraculo/core/services/chunking_service.dart, package:dart_oraculo/core/services/markdown_normalizer.dart, package:dart_oraculo/core/services/pdf_service.dart, package:dart_oraculo/features/documents/document_service.dart, package:syncfusion_flutter_pdf/pdf.dart, Function, PdfPageResult, PdfService (+10 more)

### Community 7 - "Secure Storage & Auth"
Cohesion: 0.09
Nodes (19): ../constants/storage_keys.dart, package:dart_oraculo/core/services/secure_storage_service.dart, package:dart_oraculo/features/auth/auth_service.dart, package:dart_oraculo/features/settings/settings_controller.dart, package:flutter_secure_storage/flutter_secure_storage.dart, FlutterSecureStorage, SecureStorageException, SecureStorageService (+11 more)

### Community 8 - "API Integration & Fidelity"
Cohesion: 0.16
Nodes (14): dart:convert, package:dart_oraculo/core/config/app_config.dart, package:dart_oraculo/core/models/image_attachment.dart, package:dart_oraculo/core/services/fidelity_checker.dart, package:dart_oraculo/core/services/ollama_service.dart, package:http/http.dart, package:http/testing.dart, WebSearchResult (+6 more)

### Community 9 - "Chat Input & Speech"
Cohesion: 0.11
Nodes (18): ../../../core/services/clipboard_image_service.dart, ../../../core/services/speech_service.dart, build, ChatInput, _ChatInputState, Container, dispose, Function (+10 more)

### Community 10 - "Database Migrations & Tests"
Cohesion: 0.18
Nodes (11): package:dart_oraculo/core/database/migrations.dart, package:dart_oraculo/core/services/structured_data_chunker.dart, package:flutter_test/flutter_test.dart, package:sqflite_common_ffi/sqflite_ffi.dart, main, main, main, main (+3 more)

### Community 11 - "Core Services Layer"
Cohesion: 0.12
Nodes (15): ../../../core/config/app_config.dart, ../../core/models/image_attachment.dart, ../../core/services/anthropic_service.dart, ../../core/services/fidelity_checker.dart, ../../core/services/fts_service.dart, ../../core/services/generation_service.dart, ../../core/services/web_search_service.dart, models/message.dart (+7 more)

### Community 12 - "Chunking & Normalization"
Cohesion: 0.12
Nodes (16): ../../core/services/chunking_service.dart, ../../core/services/markdown_normalizer.dart, ../../core/services/pdf_service.dart, ../../core/services/structured_data_chunker.dart, models/chunk.dart, package:csv/csv.dart, ArgumentError, compute (+8 more)

### Community 13 - "Image Processing & Clipboard"
Cohesion: 0.13
Nodes (11): dart:typed_data, package:dart_oraculo/core/services/image_resize_service.dart, package:image/image.dart, package:pasteboard/pasteboard.dart, ImageAttachment, ClipboardImageService, ImageResizeService, main (+3 more)

### Community 14 - "Document Library & UI"
Cohesion: 0.12
Nodes (15): document_service.dart, models/document.dart, package:file_picker/file_picker.dart, package:intl/intl.dart, build, _buildDocumentCard, Card, _docIcon (+7 more)

### Community 15 - "Module 15"
Cohesion: 0.13
Nodes (14): ../../collections/models/collection.dart, ../models/conversation.dart, build, _buildCollectionSelector, Container, Function, Icon, ListTile (+6 more)

### Community 16 - "Module 16"
Cohesion: 0.21
Nodes (8): package:dart_oraculo/core/services/anthropic_service.dart, package:dart_oraculo/core/services/fts_service.dart, package:dart_oraculo/features/chat/chat_controller.dart, main, main, main, main, main

### Community 17 - "Module 17"
Cohesion: 0.17
Nodes (8): app_colors.dart, app_text_styles.dart, package:dart_oraculo/app.dart, package:flutter/material.dart, AppColors, AppTextStyles, AppTheme, main

### Community 18 - "Module 18"
Cohesion: 0.17
Nodes (11): CHECK, chunks, chunks_fts, collections, conversation_context_attachments, conversations, documents, fts5 (+3 more)

### Community 19 - "Module 19"
Cohesion: 0.17
Nodes (11): auth_service.dart, build, CircularProgressIndicator, IconButton, initState, LockScreen, _LockScreenState, _navigateHome (+3 more)

### Community 20 - "Module 20"
Cohesion: 0.18
Nodes (9): package:dart_oraculo/core/services/speech_service.dart, FakeSpeechService, Function, main, simulateResult, FakeSpeechService, Function, main (+1 more)

### Community 21 - "Module 21"
Cohesion: 0.18
Nodes (9): pdf_service.dart, ChunkingService, _estimateTokens, TextChunk, _endsWithPunctuation, MarkdownNormalizer, normalize, _normalizeLine (+1 more)

### Community 22 - "Module 22"
Cohesion: 0.2
Nodes (8): package:dart_oraculo/features/chat/models/conversation.dart, package:dart_oraculo/features/chat/widgets/citation_strip.dart, package:dart_oraculo/features/chat/widgets/message_bubble.dart, package:dart_oraculo/features/chat/widgets/sidebar.dart, package:dart_oraculo/features/collections/models/collection.dart, main, main, _minimalPng

### Community 23 - "Module 23"
Cohesion: 0.31
Nodes (6): CustomNSError, catchExceptionAsError(), catchReturnTypeConverter(), ExceptionError, NSException, Sendable

### Community 24 - "Module 24"
Cohesion: 0.22
Nodes (8): ../../core/theme/app_text_styles.dart, build, _buildChip, Chip, CitationData, CitationStrip, Container, SizedBox

### Community 25 - "Module 25"
Cohesion: 0.25
Nodes (7): ../../core/theme/app_colors.dart, Align, build, Icon, RetryBubble, SizedBox, Text

### Community 26 - "Module 26"
Cohesion: 0.29
Nodes (5): package:dart_oraculo/core/theme/app_theme.dart, package:dart_oraculo/features/chat/widgets/retry_bubble.dart, main, Text, main

### Community 27 - "Module 27"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), NSWindow, MainFlutterWindow

### Community 28 - "Module 28"
Cohesion: 0.33
Nodes (5): package:dart_oraculo/core/services/clipboard_image_service.dart, package:flutter/services.dart, FakeClipboardImageService, main, _minimalPng

### Community 29 - "Module 29"
Cohesion: 0.33
Nodes (5): ../services/logger_service.dart, ../services/secure_storage_service.dart, _fromString, ThemeNotifier, _toString

### Community 31 - "Module 31"
Cohesion: 0.4
Nodes (4): package:dart_oraculo/features/chat/chat_screen.dart, package:desktop_drop/desktop_drop.dart, main, MaterialApp

### Community 32 - "Module 32"
Cohesion: 0.4
Nodes (4): ../services/chunking_service.dart, ArgumentError, StructuredDataChunker, TextChunk

### Community 33 - "Module 33"
Cohesion: 0.6
Nodes (5): Auditoria Inicialização 2026-07-05, Biometric Toggle UX Misleading, Code Signing Issue (dev builds), flutter_secure_storage (Keychain), macOS Keychain Password Prompt

### Community 34 - "Module 34"
Cohesion: 0.7
Nodes (5): Tasy Oracle Database Schema, Tasy OBTER Functions/Procedures, TASY (Oracle Schema Owner), Tasy Database Triggers, Tasy Database Views

### Community 36 - "Module 36"
Cohesion: 0.5
Nodes (3): package:dart_oraculo/core/theme/app_colors.dart, package:dart_oraculo/features/chat/widgets/chat_input.dart, main

### Community 38 - "Module 38"
Cohesion: 0.67
Nodes (3): OBTER_DESC_PROCEDIMENTO Function, SUS_FPO_REGRA Table, AACD_REL_SUS_FPO_V View

## Knowledge Gaps
- **411 isolated node(s):** `PodsDummy_pasteboard`, `PodsDummy_speech_to_text`, `PodsDummy_sqflite_darwin`, `PodsDummy_flutter_secure_storage_macos`, `PodsDummy_package_info_plus` (+406 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **23 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Module 17` to `Chat Controller & Core Services`, `App Config & Theme`, `Module 36`, `App Initialization & Generation`, `Widget Rendering & Markdown`, `Chat Input & Speech`, `Document Library & UI`, `Module 15`, `Module 19`, `Module 20`, `Module 22`, `Module 24`, `Module 25`, `Module 26`, `Module 28`, `Module 29`, `Module 31`?**
  _High betweenness centrality (0.153) - this node is a cross-community bridge._
- **Why does `package:flutter_test/flutter_test.dart` connect `Database Migrations & Tests` to `Module 36`, `Document Ingestion & PDF`, `Secure Storage & Auth`, `API Integration & Fidelity`, `Image Processing & Clipboard`, `Module 16`, `Module 17`, `Module 20`, `Module 22`, `Module 26`, `Module 28`, `Module 31`?**
  _High betweenness centrality (0.117) - this node is a cross-community bridge._
- **Why does `dart:convert` connect `API Integration & Fidelity` to `Chat Controller & Core Services`, `App Initialization & Generation`, `Document Ingestion & PDF`, `Core Services Layer`, `Chunking & Normalization`, `Module 16`?**
  _High betweenness centrality (0.070) - this node is a cross-community bridge._
- **What connects `PodsDummy_pasteboard`, `PodsDummy_speech_to_text`, `PodsDummy_sqflite_darwin` to the rest of the system?**
  _411 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Chat Controller & Core Services` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `RAG Pipeline & Search` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `App Config & Theme` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._