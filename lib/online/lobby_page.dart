import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_service.dart';
import 'auth/login_page.dart';
import 'room_detail_page.dart';
import 'room_creator_page.dart';
import 'profile/profile_page.dart';

/// Лобби — список открытых игр + создание + ввод кода
class LobbyPage extends StatefulWidget {
  final BackendService backend;

  const LobbyPage({super.key, required this.backend});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final _nameController = TextEditingController(text: 'Игрок');
  final _codeController = TextEditingController();
  final _avgController = TextEditingController(text: '0');
  List<LobbyRoomInfo> _rooms = [];
  StreamSubscription? _subscription;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscription = widget.backend.events.listen(_handleEvent);
    widget.backend.enterLobby();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _nameController.dispose();
    _codeController.dispose();
    _avgController.dispose();
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
      case RoomCreatedEvent e:
        _openCreatorPage(e.code);
        break;
      case ErrorEvent e:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
        break;
      default:
        break;
    }
  }

  void _createRoom({bool isPrivate = false}) {
    final name = _nameController.text.trim().isEmpty
        ? 'Игрок'
        : _nameController.text.trim();

    widget.backend.createRoom(name,
        isPrivate: isPrivate, gameType: '501', gameParams: {'legs': 5});
  }

  void _openCreatorPage(String code) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomCreatorPage(
          backend: widget.backend,
          roomCode: code,
          playerName: _nameController.text.trim().isEmpty
              ? 'Игрок'
              : _nameController.text.trim(),
        ),
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

    final name = _nameController.text.trim().isEmpty
        ? 'Игрок'
        : _nameController.text.trim();
    final avg = double.tryParse(_avgController.text) ?? 0;

    widget.backend.joinByCode(code, name, avg: avg);
  }

  void _openRoomDetail(LobbyRoomInfo room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomDetailPage(
          backend: widget.backend,
          roomInfo: room,
          playerName: _nameController.text.trim().isEmpty
              ? 'Игрок'
              : _nameController.text.trim(),
          playerAvg: double.tryParse(_avgController.text) ?? 0,
        ),
      ),
    );
  }

  void _logout() {
    widget.backend.clearToken();
    widget.backend.disconnect();
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
        title: const Text('Лобби'),
        actions: [
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Поля ввода
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Ваше имя',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _avgController,
            decoration: const InputDecoration(
              labelText: 'Средний набор',
              prefixIcon: Icon(Icons.trending_up),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // Кнопки создания
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => _createRoom(),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Создать игру'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _createRoom(isPrivate: true),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Создать с кодом'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ввод кода
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Код комнаты',
                    prefixIcon: Icon(Icons.vpn_key),
                    border: OutlineInputBorder(),
                    hintText: 'ABC123',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _joinByCode(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: IconButton.filled(
                  onPressed: _joinByCode,
                  icon: const Icon(Icons.login),
                  tooltip: 'Присоединиться по коду',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Разделитель
          Row(
            children: [
              Text('Открытые игры',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Список комнат
          if (_rooms.isEmpty && !_loading)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.sports_esports_outlined,
                          size: 48, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      Text(
                        'Нет открытых игр',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Создайте игру или введите код',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
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
    );
  }
}
