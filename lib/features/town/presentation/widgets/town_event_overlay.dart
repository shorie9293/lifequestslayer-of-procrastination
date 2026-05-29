import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/town/domain/random_event.dart';

/// Overlay widget to display a random town event.
class TownEventOverlay extends StatelessWidget {
  final RandomEvent event;
  final VoidCallback onClose;

  const TownEventOverlay({
    super.key,
    required this.event,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      key: AppKeys.townEventOverlay,
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(event.emoji, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    key: AppKeys.townEventTitle,
                    event.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    key: AppKeys.townEventDescription,
                    event.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    key: AppKeys.townEventClose,
                    onPressed: onClose,
                    child: const Text('閉じる'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
