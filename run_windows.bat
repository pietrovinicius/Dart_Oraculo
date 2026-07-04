@echo off
REM Dart Oráculo — Script de execução para Windows

echo.
echo  ============================================
echo   Dart Oráculo — Iniciando no Windows...
echo  ============================================
echo.

REM Verifica se Flutter está no PATH
where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo  [ERRO] Flutter não encontrado no PATH.
    echo         Instale: https://docs.flutter.dev/get-started/install/windows
    pause
    exit /b 1
)

REM Verifica dependências
echo  [1/2] Verificando dependências...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo  [ERRO] Falha ao resolver dependências.
    pause
    exit /b 1
)

REM Roda o app
echo.
echo  [2/2] Executando app...
call flutter run -d windows

pause
