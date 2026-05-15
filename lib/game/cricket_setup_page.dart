import 'package:flutter/material.dart';
import '../models/cricket_settings.dart';
import '../models/player_config.dart';
import '../models/game_enums.dart';

/// Страница настройки игры Cricket
class CricketSetupPage extends StatefulWidget {
  const CricketSetupPage({super.key});

  @override
  State<CricketSetupPage> createState() => _CricketSetupPageState();
}

class _CricketSetupPageState extends State<CricketSetupPage> {
  late CricketSettings _settings;
  final int maxPlayers = 4;

  @override
  void initState() {
    super.initState();
    _settings = CricketSettings.defaultSettings();
  }

  void _addPlayer() {
    if (_settings.players.length >= maxPlayers) return;
    setState(() {
      final newPlayers = List<PlayerConfig>.from(_settings.players);
      newPlayers.add(
        PlayerConfig(
          name: 'Игрок ${newPlayers.length + 1}',
          inputMode: InputMode.threeDarts,
          isBot: false,
        ),
      );
      _settings = _settings.copyWith(players: newPlayers);
    });
  }

  void _removePlayer(int index) {
    if (_settings.players.length <= 2) return;
    setState(() {
      final newPlayers = List<PlayerConfig>.from(_settings.players);
      newPlayers.removeAt(index);
      
      int newStartingIndex = _settings.startingPlayerIndex;
      if (_settings.startingPlayerIndex >= newPlayers.length) {
        newStartingIndex = 0;
      }
      
      _settings = _settings.copyWith(
        players: newPlayers,
        startingPlayerIndex: newStartingIndex,
      );
    });
  }

  void _updatePlayer(int index, PlayerConfig updated) {
    setState(() {
      final newPlayers = List<PlayerConfig>.from(_settings.players);
      newPlayers[index] = updated;
      _settings = _settings.copyWith(players: newPlayers);
    });
  }

  Widget _buildPlayerCard(int index) {
    final player = _settings.players[index];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: player.name,
                    decoration: const InputDecoration(
                      labelText: 'Имя игрока',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        _updatePlayer(index, player.copyWith(name: value)),
                  ),
                ),
                if (_settings.players.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removePlayer(index),
                    tooltip: 'Удалить игрока',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Бот'),
              value: player.isBot,
              onChanged: (value) {
                _updatePlayer(
                  index,
                  player.copyWith(
                    isBot: value,
                    botLevel: value ? BotLevel.amateur45_55 : null,
                  ),
                );
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (player.isBot) ...[
              DropdownButtonFormField<BotLevel>(
                initialValue: player.botLevel ?? BotLevel.amateur45_55,
                decoration: const InputDecoration(labelText: 'Уровень бота'),
                items: BotLevel.values
                    .map((level) => DropdownMenuItem(
                          value: level,
                          child: Text(level.description),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _updatePlayer(index, player.copyWith(botLevel: value));
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройка Cricket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              initialValue: _settings.sets,
              decoration: const InputDecoration(labelText: 'Сеты (1-6)'),
              items: List.generate(6, (i) => i + 1)
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _settings = _settings.copyWith(sets: v);
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _settings.legs,
              decoration: const InputDecoration(labelText: 'Леги (1-6)'),
              items: List.generate(6, (i) => i + 1)
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _settings = _settings.copyWith(legs: v);
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Игроки', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _settings.players.length < maxPlayers
                      ? _addPlayer
                      : null,
                  tooltip: 'Добавить игрока',
                ),
              ],
            ),
            ...List.generate(
              _settings.players.length,
              (i) => _buildPlayerCard(i),
            ),
            DropdownButtonFormField<int>(
              initialValue: _settings.startingPlayerIndex,
              decoration: const InputDecoration(labelText: 'Начинает игру'),
              items: List.generate(
                _settings.players.length,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(_settings.players[i].name),
                ),
              ),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _settings = _settings.copyWith(startingPlayerIndex: v);
                  });
                }
              },
            ),
            const SizedBox(height: 30),
            FilledButton.icon(
              onPressed: () {
                // TODO: переход на страницу Cricket
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Режим Cricket в разработке')),
                );
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Начать игру'),
            ),
          ],
        ),
      ),
    );
  }
}