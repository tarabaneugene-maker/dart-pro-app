import 'package:flutter/foundation.dart' show kIsWeb;

/// Единая функция определения URL сервера
String resolveServerUrl() {
  const envUrl = String.fromEnvironment('SERVER_URL');
  if (envUrl.isNotEmpty) return envUrl;
  if (kIsWeb) {
    final hostname = Uri.base.host;
    final scheme = Uri.base.scheme;
    // Если страница загружена по HTTPS — используем WSS (production)
    if (scheme == 'https') {
      return 'wss://$hostname/ws';
    }
    // Для локального dev-сервера (HTTP) — Dart-сервер всегда на 8080
    // Uri.base.port — это порт dev-сервера (например 5173), а не Dart-сервера
    return 'ws://$hostname:8080/ws';
  }
  return 'ws://localhost:8080/ws';
}
