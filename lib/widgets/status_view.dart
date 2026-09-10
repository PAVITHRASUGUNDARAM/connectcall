import 'package:flutter/material.dart';

class StatusView extends StatelessWidget {
  const StatusView.loading({super.key, this.message = 'Loading...'})
      : icon = null,
        retry = null;

  const StatusView.empty({
    super.key,
    required this.message,
    this.icon = Icons.people_outline,
    this.retry,
  });

  const StatusView.error({
    super.key,
    required this.message,
    this.icon = Icons.wifi_off,
    this.retry,
  });

  final String message;
  final IconData? icon;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (retry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: retry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
