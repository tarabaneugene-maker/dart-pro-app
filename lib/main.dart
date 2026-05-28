import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Игровые модули
import 'game/local_game_menu_page.dart';

// Тренировочные модули
import 'training/training_page.dart';

// Онлайн модули
import 'online/services/backend_service.dart';
import 'online/services/websocket_backend.dart';
import 'online/auth/login_page.dart';
import 'online/profile/profile_page.dart';
import 'online/server_url.dart';

// Виджеты
import 'widgets/stub_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const DartsApp());
}

class DartsApp extends StatelessWidget {
  const DartsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Darts Pro',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// Главная страница с меню
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final WebSocketBackend _backend = WebSocketBackend();
  bool _backendConnected = false;
  StreamSubscription? _backendSub;

  @override
  void initState() {
    super.initState();
    _connectBackend();
    _backendSub = _backend.events.listen((event) {
      if (event is PongEvent || event is AuthOkEvent) {
        if (mounted) setState(() => _backendConnected = _backend.isConnected);
      }
    });
  }

  @override
  void dispose() {
    _backendSub?.cancel();
    _backend.dispose();
    super.dispose();
  }

  Future<void> _connectBackend() async {
    final serverUrl = resolveServerUrl();
    debugPrint('Подключаюсь к серверу: $serverUrl');
    try {
      await _backend.connect(serverUrl);
      if (mounted) {
        setState(() => _backendConnected = _backend.isConnected);
      }
    } catch (e) {
      debugPrint('Не удалось подключиться к серверу: $e');
      if (mounted) {
        setState(() => _backendConnected = _backend.isConnected);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Darts Pro'),
            const Spacer(),
            Icon(
              _backendConnected ? Icons.wifi : Icons.wifi_off,
              color: _backendConnected ? Colors.green : Colors.red,
              size: 18,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              _MenuTile(
                icon: Icons.sports_martial_arts,
                title: 'Локальная игра',
                subtitle: '501, Cricket с ботами',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LocalGameMenuPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.fitness_center,
                title: 'Тренировка',
                subtitle: 'Сектор, Around the Clock',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TrainingPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.language,
                title: 'Онлайн',
                subtitle: _backendConnected
                    ? 'Подключено к серверу'
                    : 'Нет подключения к серверу',
                trailing: _backendConnected
                    ? null
                    : Icon(Icons.wifi_off, size: 18, color: Colors.red.shade300),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LoginPage(backend: _backend),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.bar_chart,
                title: 'Статистика',
                subtitle: 'История матчей, рейтинг',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(backend: _backend),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.settings,
                title: 'Настройки',
                subtitle: 'Язык, звук, оформление',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StubPage(
                        icon: Icons.settings,
                        title: 'Настройки',
                        description: 'Страница в разработке',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Прямоугольная плитка меню с иконкой слева и названием
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 28, color: colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
