import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Игровые модули
import 'game/local_game_menu_page.dart';

// Тренировочные модули
import 'training/training_page.dart';

// Онлайн модули
import 'online/services/backend_service.dart';
import 'online/services/websocket_backend.dart';
import 'online/auth/login_page.dart';
import 'online/lobby_page.dart';
import 'online/server_url.dart';

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
  StreamSubscription? _backendSub;

  // Для авто-входа: кэшируем страницу онлайн, чтобы не пересоздавать
  Widget? _onlinePage;
  bool _onlinePageBuilt = false;

  static const List<String> _titles = <String>['Тренировка', 'Игра', 'Онлайн'];

  @override
  void initState() {
    super.initState();
    _connectBackend();
    // Слушаем события, чтобы обновлять иконку WiFi в реальном времени
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

  Widget _buildOnlinePage() {
    // LoginPage сама проверит токен и сделает авто-вход
    return LoginPage(backend: _backend);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      const TrainingPage(),
      const LocalGameMenuPage(),
      _buildOnlinePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(_titles[_selectedIndex]),
            if (_selectedIndex == 2) ...[
              const SizedBox(width: 8),
              Icon(
                _backendConnected ? Icons.wifi : Icons.wifi_off,
                color: _backendConnected ? Colors.green : Colors.red,
                size: 18,
              ),
            ],
          ],
        ),
      ),
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
}
