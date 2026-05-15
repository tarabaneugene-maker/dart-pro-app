import 'package:flutter/material.dart';
import '../models/game_settings.dart';
import '../models/player_config.dart';
import '../models/game_enums.dart';
import 'game_page_501.dart';

/// Страница настройки игры 501/301
class GameSetupPage extends StatefulWidget {
  const GameSetupPage({super.key});

  @override
  State<GameSetupPage> createState() => _GameSetupPageState();
}

class _GameSetupPageState extends State<GameSetupPage> {
  late GameSettings _settings;
  final int maxPlayers = 4;

  @override
  void initState() {
    super.initState();
    _settings = GameSettings.defaultSettings();
  }

  void _addPlayer() {
    if (_settings.players.length >= maxPlayers) return;
    setState(() {
      final newPlayer = PlayerConfig(
        name: 'Игрок ${_settings.players.length + 1}',
        inputMode: InputMode.threeDarts,
        isBot: false,
      );
      _settings = _settings.copyWith(
        players: [..._settings.players, newPlayer],
      );
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
            ] else ...[
              const SizedBox(height: 4),
              Text('Ввод бросков:',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Сумма', style: TextStyle(fontSize: 13)),
                      selected: player.inputMode == InputMode.threeDarts,
                      onSelected: (_) => _updatePlayer(
                        index,
                        player.copyWith(inputMode: InputMode.threeDarts),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('По броскам', style: TextStyle(fontSize: 13)),
                      selected: player.inputMode == InputMode.oneDart,
                      onSelected: (_) => _updatePlayer(
                        index,
                        player.copyWith(inputMode: InputMode.oneDart),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройка игры')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<GameType>(
              initialValue: _settings.gameType,
              decoration: const InputDecoration(
                labelText: 'Тип игры',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: GameType.d501, child: Text('501')),
                DropdownMenuItem(value: GameType.d301, child: Text('301')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings = _settings.copyWith(gameType: value);
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _settings.sets,
              decoration: const InputDecoration(labelText: 'Сеты (1-6)'),
              items: List.generate(6, (i) => i + 1)
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings = _settings.copyWith(sets: value);
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
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings = _settings.copyWith(legs: value);
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<StartType>(
              initialValue: _settings.startType,
              decoration: const InputDecoration(labelText: 'Начало'),
              items: const [
                DropdownMenuItem(
                  value: StartType.straightIn,
                  child: Text('Straight In'),
                ),
                DropdownMenuItem(
                  value: StartType.doubleIn,
                  child: Text('Double In'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings = _settings.copyWith(startType: value);
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FinishType>(
              initialValue: _settings.finishType,
              decoration: const InputDecoration(labelText: 'Финиш'),
              items: const [
                DropdownMenuItem(
                  value: FinishType.doubleOut,
                  child: Text('Double Out'),
                ),
                DropdownMenuItem(
                  value: FinishType.straightOut,
                  child: Text('Straight Out'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings = _settings.copyWith(finishType: value);
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Игроки', style: theme.textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _settings.players.length < maxPlayers
                      ? _addPlayer
                      : null,
                  tooltip: 'Добавить игрока',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(
              _settings.players.length,
              (index) => _buildPlayerCard(index),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              initialValue: _settings.startingPlayerIndex,
              decoration: const InputDecoration(labelText: 'Начинает игру'),
              items: List.generate(
                _settings.players.length,
                (index) => DropdownMenuItem(
                  value: index,
                  child: Text(_settings.players[index].name),
                ),
              ),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings = _settings.copyWith(startingPlayerIndex: value);
                  });
                }
              },
            ),
            const SizedBox(height: 30),
            Center(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GamePage501(settings: _settings),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Начать игру'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}