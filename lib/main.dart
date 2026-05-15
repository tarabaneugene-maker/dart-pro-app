import 'package:flutter/material.dart';

// Игровые модули
import 'game/local_game_menu_page.dart';

// Тренировочные модули
import 'training/training_page.dart';

// Онлайн модули
import 'online/services/websocket_backend.dart';
import 'online/auth/login_page.dart';

void main() {
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

/// Главная страница с навигацией
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final WebSocketBackend _backend = WebSocketBackend();
  bool _backendConnected = false;

  static const List<String> _titles = <String>['Тренировка', 'Игра', 'Онлайн'];

  @override
  void initState() {
    super.initState();
    _connectBackend();
  }

  @override
  void dispose() {
    _backend.dispose();
    super.dispose();
  }

  Future<void> _connectBackend() async {
    // URL сервера: по умолчанию localhost, но можно переопределить через флаг
    // Для продакшена задаётся через --dart-define=SERVER_URL=ws://...
    const serverUrl = String.fromEnvironment(
      'SERVER_URL',
      defaultValue: 'ws://localhost:8080/ws',
    );
    try {
      await _backend.connect(serverUrl);
      if (mounted) {
        setState(() => _backendConnected = true);
      }
    } catch (e) {
      debugPrint('Не удалось подключиться к серверу: $e');
      // Продолжаем работу — пользователь увидит страницу логина
      // и сможет переподключиться
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      const TrainingPage(),
      const LocalGameMenuPage(),
      // Если бэкенд подключён — показываем логин, иначе заглушку
      _backendConnected
          ? LoginPage(backend: _backend)
          : _buildConnectionError(),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Тренировка',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_martial_arts_outlined),
            selectedIcon: Icon(Icons.sports_martial_arts),
            label: 'Игра',
          ),
          NavigationDestination(
            icon: Icon(Icons.language_outlined),
            selectedIcon: Icon(Icons.language),
            label: 'Онлайн',
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Не удалось подключиться к серверу',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Убедитесь, что сервер запущен на localhost:8080',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() => _backendConnected = false);
                _connectBackend();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить подключение'),
            ),
          ],
        ),
      ),
    );
  }
}
