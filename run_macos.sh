#!/bin/bash
# Dart Oráculo — Script de execução para macOS

set -e

echo "🔮 Dart Oráculo — Iniciando no macOS..."
echo ""

# Verifica se Flutter está no PATH
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter não encontrado no PATH."
    echo "   Instale: https://docs.flutter.dev/get-started/install/macos"
    exit 1
fi

# Verifica dependências
echo "📦 Verificando dependências..."
flutter pub get

# Roda o app
echo ""
echo "🚀 Executando app..."
flutter run -d macos
