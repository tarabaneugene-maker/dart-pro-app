import 'package:flutter/material.dart';
import 'cricket_setup_page.dart';
import 'game_setup_page.dart';

/// Меню локальных игр
class LocalGameMenuPage extends StatelessWidget {
  const LocalGameMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Локальные игры')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              _GameModeTile(
                icon: Icons.track_changes_outlined,
                title: 'Cricket',
                subtitle: 'Классический Cricket с ботами',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CricketSetupPage()),
                  );
                },
              ),
              const SizedBox(height: 8),
              _GameModeTile(
                icon: Icons.looks_5_outlined,
                title: '501',
                subtitle: 'Стандартный режим 501 с ботами',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GameSetupPage()),
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

/// Прямоугольная плитка режима игры в стиле главной страницы
class _GameModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GameModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
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
