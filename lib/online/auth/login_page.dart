import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend_service.dart';
import '../server_url.dart';
import 'register_page.dart';
import '../lobby_page.dart';
import '../online_game_page_501.dart';

/// Страница входа
class LoginPage extends StatefulWidget {
  final BackendService backend;

  const LoginPage({super.key, required this.backend});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _rememberMe = false;
  String? _error;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _tryAutoLogin();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryAutoLogin() async {
    final token = widget.backend.savedToken;
    if (token == null || token.isEmpty) return;

    setState(() => _connecting = true);

    try {
      await widget.backend.ensureConnected();
    } catch (_) {
      if (!mounted) return;
      setState(() => _connecting = false);
      return;
    }

    final result = await widget.backend.authWithToken(token);
    if (!mounted) return;
    setState(() => _connecting = false);

    if (result.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LobbyPage(
            backend: widget.backend,
            displayName: result.displayName ?? result.login ?? 'Игрок',
          ),
        ),
      );
    }
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLogin = prefs.getString('login') ?? '';
    final savedPassword = prefs.getString('password') ?? '';
    final remember = prefs.getBool('remember_me') ?? false;

    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (remember) {
        _loginController.text = savedLogin;
        _passwordController.text = savedPassword;
      }
    });
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('login', _loginController.text.trim());
      await prefs.setString('password', _passwordController.text);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('login');
      await prefs.remove('password');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _login() async {
    final login = _loginController.text.trim();
    final password = _passwordController.text;

    if (login.isEmpty || password.isEmpty) {
      setState(() => _error = 'Заполните все поля');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.backend.ensureConnected();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Нет связи с сервером. Нажмите «Переподключиться».';
      });
      return;
    }

    final result = await widget.backend.login(login, password);

    if (!mounted) return;

    setState(() => _loading = false);

    if (result.success) {
      await _saveCredentials();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LobbyPage(
            backend: widget.backend,
            displayName: result.displayName ?? result.login ?? 'Игрок',
          ),
        ),
      );
    } else {
      setState(() => _error = result.error ?? 'Ошибка входа');
    }
  }

  Future<void> _reconnect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final serverUrl = resolveServerUrl();
      await widget.backend.connect(serverUrl);
      // connect() сам вызывает _reauthenticateAfterConnect() — не нужно дублировать
      if (mounted) {
        setState(() => _connecting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = 'Не удалось подключиться к серверу';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход'),
        leading: const BackButton(),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_martial_arts, size: 80, color: Colors.teal),
              const SizedBox(height: 16),
              Text(
                'Darts Pro',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _loginController,
                decoration: const InputDecoration(
                  labelText: 'Логин',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                title: const Text('Запомнить меня'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: (_loading || _connecting) ? null : _login,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: _loading || _connecting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Войти', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _connecting ? null : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RegisterPage(backend: widget.backend),
                    ),
                  );
                },
                child: const Text('Нет аккаунта? Зарегистрироваться'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _connecting ? null : _reconnect,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Переподключиться к серверу'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
