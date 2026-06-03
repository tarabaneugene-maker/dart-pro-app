import 'package:flutter/material.dart';
import '../data/checkouts.dart';

/// Full-screen страница с таблицей чекаутов
class CheckOutsPage extends StatelessWidget {
  const CheckOutsPage({super.key});

  /// Чекауты >= 60 (без one-dart finishes)
  List<CheckoutEntry> get _filteredCheckouts =>
      allCheckouts.where((e) => e.score >= 60).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CheckOuts'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Заголовки колонок
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    '',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Score',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '1st',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    '2nd',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    '3rd',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // Список чекаутов (показываем только >= 60)
          Expanded(
            child: ListView.separated(
              itemCount: _filteredCheckouts.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final entry = _filteredCheckouts[index];
                final isThreeDart = entry.third != null;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  color: index.isEven
                      ? Colors.transparent
                      : theme.colorScheme.surfaceContainerLow,
                  child: Row(
                    children: [
                      // Иконка типа
                      SizedBox(
                        width: 48,
                        child: Icon(
                          isThreeDart ? Icons.looks_3 : Icons.looks_two,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      // Score
                      Expanded(
                        child: Text(
                          '${entry.score}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // 1st
                      Expanded(
                        child: Text(
                          entry.first,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // 2nd
                      Expanded(
                        child: Text(
                          entry.second ?? '-',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: entry.second == null
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // 3rd
                      Expanded(
                        child: Text(
                          entry.third ?? '-',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: entry.third == null
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Кнопка ОК
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
