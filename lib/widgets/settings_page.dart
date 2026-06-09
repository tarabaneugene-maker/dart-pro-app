import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ключ для хранения отображаемого имени
const String displayNameKey = 'display_name';

/// Загружает сохранённое отображаемое имя
Future<String> loadDisplayName() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(displayNameKey) ?? '';
  } catch (_) {
    return '';
  }
}

/// Сохраняет отображаемое имя
Future<void> saveDisplayName(String name) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(displayNameKey, name);
  } catch (_) {}
}

/// Страница настроек
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await loadDisplayName();
    if (!mounted) return;
    setState(() {
      _nameController.text = name;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    await saveDisplayName(_nameController.text.trim());
    if (!mounted) return;
    setState(() => _hasChanges = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Имя сохранено')),
    );
  }

  bool get _isNameEmpty => _nameController.text.trim().isEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Отображаемое имя',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Будет использоваться в тренировках и локальных играх',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Ваше имя',
                      hintText: 'Введите имя',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline),
                      suffixIcon: _isNameEmpty
                          ? const Icon(Icons.warning_amber_rounded,
                              color: Colors.red)
                          : null,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: _isNameEmpty ? Colors.red : colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      labelStyle: TextStyle(
                        color: _isNameEmpty ? Colors.red : null,
                      ),
                    ),
                    onChanged: (_) {
                      setState(() => _hasChanges = true);
                    },
                  ),
                  if (_isNameEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: Colors.red.shade300),
                        const SizedBox(width: 4),
                        Text(
                          'Имя не задано',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _hasChanges ? _save : null,
                      icon: _isNameEmpty
                          ? const Icon(Icons.warning_amber_rounded)
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isNameEmpty ? 'Укажите имя' : 'Сохранить',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
