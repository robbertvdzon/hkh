import 'package:flutter/material.dart';

import '../content/content_models.dart';
import '../theme/app_style.dart';
import 'date_format.dart';
import 'site_widgets.dart';

/// Status van de inschrijving als label en knoptekst.
({String text, PillTone tone, String action, bool filled}) registrationStatus(
  Activity activity,
) {
  final registration = activity.registration;
  if (registration == null) {
    return (
      text: activity.kind == ActivityKind.expositie
          ? 'Vrij toegankelijk'
          : 'Geen inschrijving nodig',
      tone: PillTone.normal,
      action: 'Meer',
      filled: false,
    );
  }
  if (registration.isExternal) {
    return (
      text: 'Inschrijven via partner',
      tone: PillTone.normal,
      action: 'Meer',
      filled: false,
    );
  }
  if (registration.capacity == null) {
    return (
      text: 'Inschrijven gewenst',
      tone: PillTone.normal,
      action: 'Inschrijven',
      filled: true,
    );
  }
  if (registration.isFull) {
    final waiting = registration.waitlist;
    return (
      text: waiting > 0 ? 'Vol · $waiting op wachtlijst' : 'Vol · wachtlijst',
      tone: PillTone.full,
      action: 'Op de wachtlijst',
      filled: false,
    );
  }
  final free = registration.free;
  return (
    text: 'Nog $free ${free == 1 ? 'plaats' : 'plaatsen'}',
    tone: free <= 5 ? PillTone.few : PillTone.normal,
    action: 'Inschrijven',
    filled: true,
  );
}

/// Korte omschrijving van soort, prijs en capaciteit.
String activitySubline(Activity activity) {
  final parts = <String>[
    activity.partner ? '${activity.kind.label} · partner' : activity.kind.label,
    if (activity.price != null) activity.price!,
    if (activity.registration?.capacity case final capacity?)
      'max. $capacity personen',
  ];
  return parts.join(' · ');
}

/// Kaart met foto, datum, titel en inschrijfstatus (homepage).
class ActivityCard extends StatelessWidget {
  const ActivityCard({required this.activity, super.key});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final status = registrationStatus(activity);
    final when = activity.multiDay
        ? 't/m ${activity.end!.day} ${monthShort(activity.end!)}'
        : '${formatShortDate(activity.start)} · ${formatTime(activity.start)}';
    return ContentCard(
      image: activity.image,
      label: '$when · ${activity.venueName}',
      title: activity.title,
      status: StatusPill(status.text, tone: status.tone),
      actionLabel: status.action,
      actionFilled: status.filled,
      onTap: () => navigateTo(context, '/agenda/${activity.slug}'),
    );
  }
}

/// Regel in de agenda: datumblok, titel en plaats, foto en status.
class ActivityRow extends StatelessWidget {
  const ActivityRow({required this.activity, super.key});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final status = registrationStatus(activity);
    final start = activity.start;
    final date = Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E6D2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            activity.multiDay
                ? '${weekdayShort(start)}–${weekdayShort(activity.end!)}'
                : weekdayShort(start),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1,
              color: Color(0xFF8A5A2B),
            ),
          ),
          Text(
            '${start.day}',
            style: const TextStyle(
              fontFamily: 'HkhSerif',
              fontSize: 30,
              height: 1.1,
              color: Color(0xFF1F3B2E),
            ),
          ),
          Text(
            activity.multiDay
                ? 't/m ${activity.end!.day} ${monthShort(activity.end!)}'
                : monthShort(start),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1,
              color: Color(0xFF8A5A2B),
            ),
          ),
        ],
      ),
    );
    final where = [
      activity.venueName,
      if (!activity.allDay && !activity.multiDay)
        '${formatTime(start)}–${activity.end == null ? '' : formatTime(activity.end!)}',
      if (activity.organizer.isNotEmpty && activity.partner) activity.organizer,
    ].where((s) => s.isNotEmpty).join(' · ');
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activity.title,
          style: const TextStyle(
            fontFamily: 'HkhSerif',
            fontSize: 21,
            height: 1.25,
            color: Color(0xFF1F3B2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          where,
          style: const TextStyle(fontSize: 14, color: Color(0xFF5A6A5C)),
        ),
        Text(
          activitySubline(activity),
          style: const TextStyle(fontSize: 14, color: Color(0xFF5A6A5C)),
        ),
      ],
    );
    final action = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        StatusPill(status.text, tone: status.tone),
        const SizedBox(height: 8),
        status.filled
            ? FilledButton(
                onPressed: () =>
                    navigateTo(context, '/agenda/${activity.slug}'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  shape: const StadiumBorder(),
                ),
                child: Text(status.action),
              )
            : OutlinedButton(
                onPressed: () =>
                    navigateTo(context, '/agenda/${activity.slug}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  shape: const StadiumBorder(),
                ),
                child: Text(status.action),
              ),
      ],
    );
    return AppCard(
      key: Key('activity-${activity.slug}'),
      padding: const EdgeInsets.all(18),
      onTap: () => navigateTo(context, '/agenda/${activity.slug}'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    date,
                    const SizedBox(width: 16),
                    Expanded(child: body),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(status.text, tone: status.tone),
                    TextButton(
                      onPressed: () =>
                          navigateTo(context, '/agenda/${activity.slug}'),
                      child: Text(status.action),
                    ),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              date,
              const SizedBox(width: 20),
              Expanded(child: body),
              if (activity.image != null) ...[
                const SizedBox(width: 20),
                SiteImage(
                  activity.image!,
                  width: 180,
                  height: 96,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
              const SizedBox(width: 20),
              SizedBox(width: 170, child: action),
            ],
          );
        },
      ),
    );
  }
}
