#!/bin/bash
# Duplo-clique para abrir o Dart Oráculo
# macOS abre arquivos .command no Terminal automaticamente

cd "$(dirname "$0")"

echo "🔮 Iniciando Dart Oráculo..."

# Verifica se já tem build recente (menos de 1h)
APP="build/macos/Build/Products/Debug/dart_oraculo.app"
if [ -f "$APP/Contents/MacOS/dart_oraculo" ] && [ $(find "$APP" -maxdepth 0 -mmin -60 | wc -l) -gt 0 ]; then
    echo "Abrindo build existente..."
    open "$APP"
else
    echo "Compilando..."
    /Users/pietrodapenhadelima/Projetos/Caminhos_da_Saude/flutter/bin/flutter build macos --debug 2>&1 | tail -3
    echo "Abrindo app..."
    open "$APP"
fi
