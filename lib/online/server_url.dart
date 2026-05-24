import 'package:flutter/foundation.dart' show kIsWeb;

/// Единая функция определения URL сервера
String resolveServerUrl() {
  const envUrl = String.fromEnvironment('SERVER_URL');
  if (envUrl.isNotEmpty) return envUrl;
  if (kIsWeb) {
    // Для production web нужно передавать SERVER_URL через --dart-define
    // flutter build web --dart-define=SERVER_URL=wss://your-app.up.railway.app/ws
    final hostname = Uri.base.host;
    final scheme = Uri.base.scheme;
    // Если страница загружена по HTTPS — используем WSS (production)
    // Если по HTTP (тест со смартфона по локальной сети) — WS на порт 8080
    if (scheme == 'https') {
      return 'wss://$hostname/ws';
    }
    return 'ws://$hostname:8080/ws';
  }
  return 'ws://localhost:8080/ws';
}
