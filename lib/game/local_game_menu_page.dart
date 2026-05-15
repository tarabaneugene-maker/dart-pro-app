import 'package:flutter/material.dart';
import 'cricket_setup_page.dart';
import 'game_setup_page.dart';

/// Меню локальных игр
class LocalGameMenuPage extends StatelessWidget {
  const LocalGameMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Локальные игры', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        GameModeTile(
          icon: Icons.track_changes_outlined,
          title: 'Cricket',
          description: 'Классический Cricket с ботами',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CricketSetupPage()),
            );
          },
        ),
        const SizedBox(height: 10),
        GameModeTile(
          icon: Icons.looks_5_outlined,
          title: '501',
          description: 'Стандартный режим 501 с ботами',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GameSetupPage()),
            );
          },
        ),
      ],
    );
  }
}

class GameModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const GameModeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}