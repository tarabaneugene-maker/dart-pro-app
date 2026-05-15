import 'package:flutter/material.dart';
import '../services/backend_service.dart';

/// Страница профиля и статистики
class ProfilePage extends StatefulWidget {
  final BackendService backend;

  const ProfilePage({super.key, required this.backend});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Пока заглушка — данные будут приходить с сервера
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 48,
                child: Icon(Icons.person, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'Статистика',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _statRow('Матчей сыграно', '—'),
                      _statRow('Побед', '—'),
                      _statRow('Поражений', '—'),
                      const Divider(),
                      _statRow('Средний набор', '—'),
                      _statRow('Лучший лег', '—'),
                      _statRow('Рейтинг ELO', '1000'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'История матчей будет доступна после первой игры',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
