import 'package:flutter/material.dart';

class TrainingModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const TrainingModeCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
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

class TrainingInputMenu extends StatelessWidget {
  final int maxValue;
  final bool disabled;
  final int? pendingInputValue;
  final bool isAutoOkEnabled;
  final Function(int) onValueSelected;
  final VoidCallback onConfirm;
  final VoidCallback onToggleAutoOk;

  const TrainingInputMenu({
    super.key,
    required this.maxValue,
    required this.disabled,
    required this.pendingInputValue,
    required this.isAutoOkEnabled,
    required this.onValueSelected,
    required this.onConfirm,
    required this.onToggleAutoOk,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int cappedMaxValue = maxValue.clamp(1, 9);
    final List<int> keypadValues =
        List<int>.generate(cappedMaxValue, (int index) => index + 1);
    final int totalKeys = keypadValues.length + 1;
    
    final ButtonStyle compactButtonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size(0, 34),
      maximumSize: const Size(double.infinity, 34),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      backgroundColor: colors.secondaryContainer,
      foregroundColor: colors.onSecondaryContainer,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            style: compactButtonStyle,
            onPressed: disabled ? null : onToggleAutoOk,
            child: Text(isAutoOkEnabled ? 'AutoOk: On' : 'AutoOk'),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.primary, width: 1.5),
          ),
          child: Text(
            pendingInputValue == null
                ? 'Набрано: -'
                : 'Набрано: $pendingInputValue',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
          ),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalKeys,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 2.9,
          ),
          itemBuilder: (BuildContext context, int index) {
            if (index < keypadValues.length) {
              final int value = keypadValues[index];
              return ElevatedButton(
                style: compactButtonStyle,
                onPressed: disabled ? null : () => onValueSelected(value),
                child: Text('$value'),
              );
            }
            if (index == keypadValues.length) {
              return ElevatedButton(
                style: compactButtonStyle,
                onPressed: disabled ? null : () {
                  if (pendingInputValue == null) {
                    onValueSelected(0);
                  }
                  onConfirm();
                },
                child: const Text('Ок / 0'),
              );
            }
            return const SizedBox();
          },
        ),
      ],
    );
  }
}