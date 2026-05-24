import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_service.dart';
import 'auth/login_page.dart';
import 'room_detail_page.dart';
import 'room_creator_page.dart';
import 'profile/profile_page.dart';
import '../main.dart';

/// Лобби — список открытых игр + кнопки создания и входа по коду
class LobbyPage extends StatefulWidget {
  final BackendService backend;
  final String displayName;

  const LobbyPage({super.key, required this.backend, required this.displayName});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final _codeController = TextEditingController();
  List<LobbyRoomInfo> _rooms = [];
  StreamSubscription? _subscription;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscription = widget.backend.events.listen(_handleEvent);
    // E1: ждём соединения перед входом в лобби
    _enterLobbyWhenReady();
  }

  Future<void> _enterLobbyWhenReady() async {
    await widget.backend.waitForConnection();
    widget.backend.enterLobby();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _codeController.dispose();
    widget.backend.leaveLobby();
    super.dispose();
  }

  void _handleEvent(ServerEvent event) {
    if (!mounted) return;
    switch (event) {
      case LobbyUpdateEvent e:
        setState(() {
          _rooms = e.rooms;
          _loading = false;
        });
        break;
      case ErrorEvent e:
        if (mounted) {
          // E2: если «Не авторизован» — предложить перелогиниться
          if (e.message.contains('Не авторизован') || e.message.contains('не авторизован')) {
            _showReauthSnackBar();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message)),
            );
          }
        }
        break;
      default:
        break;
    }
  }

  void _showReauthSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Сессия сброшена. Выйдите и войдите снова'),
        action: SnackBarAction(
          label: 'Выйти',
          onPressed: _logout,
        ),
      ),
    );
  }

  void _createRoom({bool isPrivate = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomCreatorPage(
          backend: widget.backend,
          playerName: widget.displayName,
          isPrivate: isPrivate,
        ),
      ),
    );
  }

  void _showJoinDialog() {
    _codeController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вступить по коду'),
        content: TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: 'Код комнаты',
            hintText: 'ABC123',
            prefixIcon: Icon(Icons.vpn_key),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _joinByCode();
            },
            child: const Text('Присоединиться'),
          ),
        ],
      ),
    );
  }

  void _joinByCode() {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите код комнаты')),
      );
      return;
    }

    widget.backend.joinByCode(code, widget.displayName);
  }

  void _openRoomDetail(LobbyRoomInfo room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomDetailPage(
          backend: widget.backend,
          roomInfo: room,
          playerName: widget.displayName,
          playerAvg: 0,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    widget.backend.clearToken();
    widget.backend.disconnect();
    // Сразу поднимаем сокет снова — иначе вход/регистрация ждут мёртвое соединение
    try {
      await widget.backend.ensureConnected();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(backend: widget.backend),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Лобби — ${widget.displayName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'На главную',
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const HomePage(),
              ),
              (route) => false,
            );
          },
        ),
        actions: [
          // Индикатор подключения
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              widget.backend.isConnected ? Icons.wifi : Icons.wifi_off,
              color: widget.backend.isConnected ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.vpn_key),
            tooltip: 'Вступить по коду',
            onPressed: _showJoinDialog,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Профиль',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfilePage(backend: widget.backend),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Список игр
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                widget.backend.getLobby();
              },
              child: _rooms.isEmpty && !_loading
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.sports_esports_outlined,
                                  size: 64, color: Colors.grey.shade500),
                              const SizedBox(height: 16),
                              Text(
                                'Нет открытых игр',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Нажмите "Создать игру" чтобы начать',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ..._rooms.map((room) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(room.creatorName[0].toUpperCase()),
                                ),
                                title: Text(room.creatorName),
                                subtitle: Text(
                                  'Средний: ${room.creatorAvg.toStringAsFixed(1)} | '
                                  '${room.gameType} | '
                                  'Best of ${room.gameParams['legs'] ?? 5}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openRoomDetail(room),
                              ),
                            )),
                      ],
                    ),
            ),
          ),
          // Нижняя панель с кнопками
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _createRoom(isPrivate: true),
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Приватная'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () => _createRoom(),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Создать игру'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
