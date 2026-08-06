import 'package:flutter/material.dart';

import 'update_checker.dart';

Future<void> maybePromptSelfUpdate(BuildContext context) async {
  final checker = UpdateChecker();
  if (!checker.isConfigured) return;

  AppUpdateInfo info;
  try {
    info = await checker.check();
  } catch (_) {
    return;
  }
  if (!info.updateAvailable || !context.mounted) return;

  final shouldUpdate = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nieuwe versie beschikbaar'),
      content: Text(
        'Er is een nieuwere versie van ${info.label} '
        '(build ${info.latestVersionCode}; geïnstalleerd: ${info.installedVersionCode}). '
        'Nu bijwerken?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Bijwerken'),
        ),
      ],
    ),
  );
  if (shouldUpdate != true || !context.mounted) return;

  try {
    await checker.update(info);
  } on UpdatePermissionRequiredException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sta installeren vanuit deze app toe en kies daarna opnieuw Bijwerken.',
          ),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bijwerken mislukt: $error')));
    }
  }
}
