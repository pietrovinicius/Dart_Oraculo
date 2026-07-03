# Design.md — Dart_Oraculo

Versão 0.1 · Consolida as decisões de design fechadas em conversa, complementa `oraculo-especificacao-dev.md`

## 1. Conceito

Dart_Oraculo é um app de macOS, com expansão planejada para Android e iOS, que funciona como um oráculo de conhecimento pessoal: o usuário carrega PDFs e arquivos markdown, o app monta uma base local de RAG a partir deles, e o usuário conversa com Opus 4.8 ou Sonnet 5 fazendo perguntas sobre o conteúdo carregado. Sem backend. A única dependência externa é a API da Anthropic, com a chave inserida e armazenada pelo próprio usuário no dispositivo.

## 2. Público-alvo

Profissionais de tecnologia da informação e usuários que utilizam o celular de forma intensa. Diferente de uma ferramenta pessoal de uso único, o desenho parte do princípio de que outras pessoas vão de fato usar o app, o que implica mais orientação visual em pontos de entrada (primeiro upload, primeira pergunta) do que um app construído só para o próprio desenvolvedor exigiria.

## 3. Paleta de cores

| Papel | Nome | Hex | Uso | Confiança |
|---|---|---|---|---|
| Fundo principal | Carvão | #141413 | Fundo de app em todas as telas | A confirmar por color picker sobre a instância real do Claude Desktop antes de codificar; o valor documentado da marca é consistente em múltiplas fontes, mas não há confirmação de que seja exatamente o fundo de chat em modo escuro |
| Superfície elevada | Grafite | derivar como um tom 8 a 12% mais claro que o Carvão | Cards de documento, painel de citação, campo de input | A calcular na prototipagem |
| Acento primário | Laranja Claude | #D97757 | Botão de ação primária, indicador de modelo ativo, destaque de trecho citado | Alta, confirmado em múltiplas fontes ligadas à marca |
| Texto principal | Pampas | #FAF9F5 | Texto sobre fundo escuro | Alta |
| Texto secundário | Cinza fumaça | derivar como neutro médio entre Carvão e Pampas | Metadados: nome de arquivo, página de origem, timestamp | A calcular na prototipagem |

## 4. Tipografia

Três famílias, cada uma com um papel único, evitando a fonte default de qualquer app de IA genérico:

- **Display**: serifada com caráter, usada com moderação, para o nome do app na tela de bloqueio e para títulos de seção. Carrega a personalidade do produto.
- **Corpo**: sans geométrica limpa e neutra, para o texto do chat e da interface em geral. Não deve competir com a display.
- **Técnica**: monoespaçada, reservada a metadados: nome de arquivo, número de página, nome do modelo ativo, timestamp. É o elemento que dá textura de ferramenta técnica séria para o público de TI, sem exigir texto explicativo adicional.

## 5. Telas

Três telas reais.

### 5.1 Tela de bloqueio

Porta de entrada do app, resolvida por autenticação local via `local_auth` (Face ID, Touch ID ou senha do sistema operacional no macOS), sem login remoto e sem servidor de autenticação. Função de privacidade no aparelho, não de conta de usuário.

```
┌─────────────────────────────────┐
│                                   │
│                                   │
│           Dart_Oraculo           │
│         (display, laranja)       │
│                                   │
│      [ ícone de biometria ]      │
│                                   │
│    Toque para desbloquear        │
│                                   │
│                                   │
└─────────────────────────────────┘
```

### 5.2 Tela principal

Sidebar retrátil com duas seções internas (conversas e biblioteca de documentos, com o botão de upload no topo da seção de biblioteca) mais o painel de chat central. Cada resposta do oráculo carrega uma faixa de citação mostrando os documentos e trechos consultados para aquela resposta, elemento de assinatura do produto.

```
┌───────────┬───────────────────────────────┐
│ ☰ Sidebar │  Dart_Oraculo    [Sonnet ▾] ⚙ │
│           ├───────────────────────────────┤
│ Conversas │                                │
│  • Chat 1 │   [pergunta do usuário]        │
│  • Chat 2 │                                │
│           │   [resposta do oráculo]        │
│───────────│   ┌─────────────────────────┐  │
│ Biblioteca│   │ fontes: doc.pdf p.4,     │  │
│  + Upload │   │ notas.md                 │  │
│  • doc.pdf│   └─────────────────────────┘  │
│  • notas  │                                │
│           │   [campo de pergunta______] ➤ │
└───────────┴───────────────────────────────┘
```

### 5.3 Tela de configurações

Entrada da chave de API da Anthropic (armazenada via `flutter_secure_storage`, nunca em texto plano) e seleção do modelo padrão entre Sonnet 5 e Opus 4.8.

```
┌─────────────────────────────────┐
│  ← Configurações                 │
├─────────────────────────────────┤
│  Chave de API da Anthropic       │
│  [ ••••••••••••••••••••••• ]     │
│                                   │
│  Modelo padrão                   │
│  ( ) Sonnet 5                    │
│  (•) Opus 4.8                    │
│                                   │
│  Autenticação local               │
│  [x] Exigir Face ID / Touch ID   │
│      ao abrir o app              │
└─────────────────────────────────┘
```

## 6. Elemento de assinatura

A faixa de citação embutida em cada resposta do oráculo é o elemento único do produto. Ela não é decoração: prova ao usuário que a resposta é rastreável à fonte real, e visualmente diferencia o Dart_Oraculo do balão de chat genérico de qualquer outro app de IA.

## 7. Considerações técnicas ligadas ao design

- `local_auth` para a tela de bloqueio, checagem de biometria ou senha do sistema no início da sessão do app.
- `flutter_secure_storage` para a chave de API, tela de configurações.
- A paleta e a tipografia valem para as três telas descritas; telas futuras (grafo de notas, Fase 3 da especificação de desenvolvimento) herdam o mesmo sistema quando forem desenhadas.

## 8. Próximo passo

Com paleta, tipografia, telas e elemento de assinatura fechados aqui, o prompt final para o Claude Design deve referenciar este documento diretamente, telas 5.1 a 5.3 como escopo de geração, seção 3 e 4 como sistema de token fixo, seção 6 como elemento obrigatório em qualquer tela de chat.
