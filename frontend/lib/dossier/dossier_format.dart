import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_style.dart';

/// Foutmelding voor de gebruiker, zonder het `Bad state:`-voorvoegsel van StateError.
String errorText(Object error) =>
    error.toString().replaceFirst('Bad state: ', '');

/// Datum en tijd zoals in de rest van de app: "Vandaag 14:05" of "12-9-2026 14:05".
String formatDateTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (sameDay) return 'Vandaag $time';
  return '${local.day}-${local.month}-${local.year} $time';
}

/// Toont een foutmelding als SnackBar, als de context nog bestaat.
void showError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(errorText(error))));
}

/// Bevestigingsdialoog; geeft true terug als de gebruiker bevestigt.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Verwijderen',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      title: title,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Server-side gerenderde HTML (feitenlijst, artikel) met klikbare bronlinks.
class RenderedHtml extends StatelessWidget {
  const RenderedHtml(this.html, {super.key});

  final String html;

  @override
  Widget build(BuildContext context) => HtmlWidget(
    html,
    onTapUrl: (url) =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    textStyle: Theme.of(context).textTheme.bodyLarge,
  );
}

/// Kleine kaart met een melding, bijvoorbeeld voor lege staten of beperkte rechten.
class InfoCard extends StatelessWidget {
  const InfoCard({required this.text, this.icon, super.key});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, color: appGreen),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(text, style: const TextStyle(color: appMutedText)),
        ),
      ],
    ),
  );
}
