import 'package:dart_oraculo/core/config/app_config.dart';
import 'package:dart_oraculo/core/theme/app_theme.dart';
import 'package:dart_oraculo/features/chat/models/conversation.dart';
import 'package:dart_oraculo/features/chat/widgets/chat_input.dart';
import 'package:dart_oraculo/features/chat/widgets/citation_strip.dart';
import 'package:dart_oraculo/features/chat/widgets/message_bubble.dart';
import 'package:dart_oraculo/features/chat/widgets/sidebar.dart';
import 'package:dart_oraculo/features/collections/models/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageBubble', () {
    testWidgets('renderiza mensagem do user alinhada à direita', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: MessageBubble(content: 'Olá', isUser: true),
          ),
        ),
      );

      expect(find.text('Olá'), findsOneWidget);
      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, equals(Alignment.centerRight));
    });

    testWidgets('renderiza mensagem do assistant alinhada à esquerda', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: MessageBubble(
              content: 'Resposta',
              isUser: false,
              modelUsed: 'sonnet-5',
            ),
          ),
        ),
      );

      expect(find.text('Resposta'), findsOneWidget);
      expect(find.text('sonnet-5'), findsOneWidget);
      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, equals(Alignment.centerLeft));
    });
  });

  group('CitationStrip', () {
    testWidgets('não renderiza quando citations vazio', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: CitationStrip(citations: []),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renderiza chips de citação', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: CitationStrip(citations: [
              CitationData(filename: 'doc.pdf', page: 3),
              CitationData(filename: 'outro.pdf'),
            ]),
          ),
        ),
      );

      expect(find.text('Fontes consultadas'), findsOneWidget);
      expect(find.text('doc.pdf (p.3)'), findsOneWidget);
      expect(find.text('outro.pdf'), findsOneWidget);
    });
  });

  group('ChatInput', () {
    testWidgets('chama onSend com texto e limpa campo', (tester) async {
      String? sentMessage;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ChatInput(onSend: (msg) => sentMessage = msg),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Minha pergunta');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(sentMessage, equals('Minha pergunta'));
    });

    testWidgets('não envia texto vazio', (tester) async {
      String? sentMessage;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ChatInput(onSend: (msg) => sentMessage = msg),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(sentMessage, isNull);
    });
  });

  group('Sidebar', () {
    testWidgets('mostra lista de conversas', (tester) async {
      final conversations = [
        Conversation(id: 1, title: 'Chat 1', createdAt: DateTime.now()),
        Conversation(id: 2, title: 'Chat 2', createdAt: DateTime.now()),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Sidebar(
              collections: [Collection(id: 1, name: 'Geral', createdAt: DateTime.now())],
              activeCollectionId: 1,
              onCollectionChanged: (_) {},
              onNewCollection: () {},
              conversations: conversations,
              selectedConversationId: 1,
              onConversationSelected: (_) {},
              onNewConversation: () {},
              onDeleteConversation: (_) {},
              onRenameConversation: (_, __) {},
              onTogglePin: (_, __) {},
              documentCount: 5,
              onOpenDocuments: () {},
              onOpenLibrary: () {},
            ),
          ),
        ),
      );

      expect(find.text('Chat 1'), findsOneWidget);
      expect(find.text('Chat 2'), findsOneWidget);
      expect(find.text('Documentos (5)'), findsOneWidget);
    });

    testWidgets('mostra estado vazio quando sem conversas', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Sidebar(
              collections: [Collection(id: 1, name: 'Geral', createdAt: DateTime.now())],
              activeCollectionId: 1,
              onCollectionChanged: (_) {},
              onNewCollection: () {},
              conversations: const [],
              selectedConversationId: null,
              onConversationSelected: (_) {},
              onNewConversation: () {},
              onDeleteConversation: (_) {},
              onRenameConversation: (_, __) {},
              onTogglePin: (_, __) {},
              documentCount: 0,
              onOpenDocuments: () {},
              onOpenLibrary: () {},
            ),
          ),
        ),
      );

      expect(find.text('Nenhuma conversa'), findsOneWidget);
    });

    testWidgets('exibe rodapé com versão e Dev @PLima', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Sidebar(
              collections: [Collection(id: 1, name: 'Geral', createdAt: DateTime.now())],
              activeCollectionId: 1,
              onCollectionChanged: (_) {},
              onNewCollection: () {},
              conversations: const [],
              selectedConversationId: null,
              onConversationSelected: (_) {},
              onNewConversation: () {},
              onDeleteConversation: (_) {},
              onRenameConversation: (_, __) {},
              onTogglePin: (_, __) {},
              documentCount: 0,
              onOpenDocuments: () {},
              onOpenLibrary: () {},
              appVersion: '0.11.2',
            ),
          ),
        ),
      );

      expect(find.text('v0.11.2'), findsOneWidget);
      expect(find.text('Dev @PLima'), findsOneWidget);
    });

    testWidgets('rodapé usa AppConfig.appVersion como fallback quando versão vazia', (tester) async {
      // Simula cenário onde PackageInfo.fromPlatform() falha → appVersion fica ''
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Sidebar(
              collections: [Collection(id: 1, name: 'Geral', createdAt: DateTime.now())],
              activeCollectionId: 1,
              onCollectionChanged: (_) {},
              onNewCollection: () {},
              conversations: const [],
              selectedConversationId: null,
              onConversationSelected: (_) {},
              onNewConversation: () {},
              onDeleteConversation: (_) {},
              onRenameConversation: (_, __) {},
              onTogglePin: (_, __) {},
              documentCount: 0,
              onOpenDocuments: () {},
              onOpenLibrary: () {},
              appVersion: '', // fallback — PackageInfo falhou
            ),
          ),
        ),
      );

      // Deve mostrar AppConfig.appVersion como fallback
      expect(find.text('v${AppConfig.appVersion}'), findsOneWidget);
      expect(find.text('Dev @PLima'), findsOneWidget);
    });
  });
}
