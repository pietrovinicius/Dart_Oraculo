## [0.17.1] - 2026-07-05

### Segurança
- **secure_storage_service.dart**: REMOVIDO fallback silencioso para arquivo JSON em texto plano (.secure_store.json). Existia desde v0.8.2 — quando Keychain falhava (erro -34018 em dev sem code signing), a API key era gravada sem criptografia em Application Support. Agora falha de Keychain surfaça como SecureStorageException com mensagem clara ao usuário. Nenhum dado sensível é mais gravado fora do Keychain.

### Removido
- **secure_storage_service.dart**: Toda infraestrutura de file-based fallback (_useFileFallback, _fileCache, _getFallbackFile, _loadFileStore, _saveFileStore, _readFromFile, _writeToFile, _deleteFromFile).
- Imports não mais necessários: dart:convert, dart:io, path_provider.
