import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../content/content_models.dart';
import '../content/generated_content.dart';
import '../content/site_structure.dart';
import '../theme/app_style.dart';
import 'activity_widgets.dart';
import 'date_format.dart';
import 'site_widgets.dart';

/// Agenda: komende activiteiten per maand, met filter op soort.
/// Met [past] de afgelopen activiteiten, meest recente eerst.
class AgendaPage extends StatefulWidget {
  const AgendaPage({this.past = false, this.now, super.key});
  final bool past;
  final DateTime? now;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  ActivityKind? _kind;
  bool _partnersOnly = false;

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    var activities = widget.past ? pastActivities(now) : upcomingActivities(now);
    if (_kind != null) {
      activities = activities.where((a) => a.kind == _kind).toList();
    }
    if (_partnersOnly) {
      activities = activities.where((a) => a.partner).toList();
    }
    final byMonth = <String, List<Activity>>{};
    for (final activity in activities) {
      byMonth.putIfAbsent(formatMonthYear(activity.start), () => []).add(activity);
    }
    final kinds = ActivityKind.values
        .where((k) => generatedActivities.any((a) => a.kind == k))
        .toList();
    return SitePage(
      title: widget.past ? 'Eerdere activiteiten' : 'Agenda',
      children: [
        PageHeading(
          title: widget.past ? 'Eerdere activiteiten' : 'Agenda',
          crumbs: widget.past ? const [('Agenda', '/agenda')] : const [],
          intro: widget.past
              ? 'Lezingen, filmmiddagen, wandelingen en exposities van de afgelopen tijd.'
              : 'Lezingen, filmmiddagen, wandelingen en exposities. Inschrijven kan direct op de pagina van de activiteit; is een activiteit vol, dan kunt u op de wachtlijst.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Alles'),
              selected: _kind == null && !_partnersOnly,
              onSelected: (_) => setState(() {
                _kind = null;
                _partnersOnly = false;
              }),
            ),
            for (final kind in kinds)
              ChoiceChip(
                key: Key('agenda-filter-${kind.name}'),
                label: Text(kind.plural),
                selected: _kind == kind,
                onSelected: (_) => setState(() {
                  _kind = _kind == kind ? null : kind;
                  _partnersOnly = false;
                }),
              ),
            ChoiceChip(
              label: const Text('Van partners'),
              selected: _partnersOnly,
              onSelected: (_) => setState(() {
                _partnersOnly = !_partnersOnly;
                _kind = null;
              }),
            ),
            if (!widget.past)
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.historischekringheemskerk.nl/evenementen/lijst/?ical=1',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Abonneren op de kalender'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  shape: const StadiumBorder(),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (!widget.past) const _FixedMoments(),
        if (activities.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'Er zijn geen activiteiten die aan deze keuze voldoen.',
              style: TextStyle(color: appMutedText),
            ),
          ),
        for (final entry in byMonth.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 12),
            child: Text(
              entry.key,
              style: const TextStyle(
                fontFamily: appSerifFont,
                fontSize: 22,
                color: appGreen,
              ),
            ),
          ),
          for (final activity in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ActivityRow(activity: activity),
            ),
        ],
        const SizedBox(height: 12),
        if (!widget.past)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('agenda-past-button'),
              onPressed: () => navigateTo(context, '/agenda/eerder'),
              child: const Text('Eerdere activiteiten'),
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => navigateTo(context, '/agenda'),
              child: const Text('Naar de komende activiteiten'),
            ),
          ),
      ],
    );
  }
}

class _FixedMoments extends StatelessWidget {
  const _FixedMoments();

  @override
  Widget build(BuildContext context) {
    Widget item(String title, String text) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: appSerifFont,
            fontSize: 18,
            color: appGreen,
          ),
        ),
        Text(text, style: const TextStyle(fontSize: 15)),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: appAccentBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 12,
        children: [
          item('Historisch Huis open', practicalInfo.openingHours.toLowerCase()),
          item('Vaste momenten', '1e en 3e vrijdagmiddag · 4e dinsdagavond'),
        ],
      ),
    );
  }
}
