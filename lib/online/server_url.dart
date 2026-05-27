import 'package:flutter/foundation.dart' show kIsWeb;

/// Единая функция определения URL сервера
String resolveServerUrl() {
  const envUrl = String.fromEnvironment('SERVER_URL');
  if (envUrl.isNotEmpty) return envUrl;
  if (kIsWeb) {
    final hostname = Uri.base.host;
    final scheme = Uri.base.scheme;
    final port = Uri.base.port;
    // Если страница загружена по HTTPS — используем WSS (production)
    if (scheme == 'https') {
      return 'wss://$hostname/ws';
    }
    // Для HTTP — используем тот же порт, что и страница (например 9090)
    return 'ws://$hostname:$port/ws';
  }
  return 'ws://localhost:8080/ws';
}
