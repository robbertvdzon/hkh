import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../content/content_models.dart';
import '../content/site_structure.dart';
import '../theme/app_style.dart';
import 'activity_widgets.dart';
import 'content_renderer.dart';
import 'date_format.dart';
import 'site_widgets.dart';

/// Eén activiteit met tekst, praktische gegevens en inschrijfformulier.
class ActivityPage extends StatelessWidget {
  const ActivityPage({required this.activity, this.now, super.key});
  final Activity activity;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final now = this.now ?? DateTime.now();
    final past = !activity.isUpcoming(now);
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activity.image != null)
          SiteImage(
            activity.image!,
            height: 380,
            width: double.infinity,
            borderRadius: BorderRadius.circular(14),
          ),
        const SizedBox(height: 18),
        MetaLabel(
          activity.partner
              ? '${activity.kind.label} · ${activity.organizer}'
              : activity.kind.label,
        ),
        const SizedBox(height: 6),
        Semantics(
          header: true,
          child: Text(
            activity.title,
            style: const TextStyle(
              fontFamily: appSerifFont,
              fontSize: 36,
              height: 1.2,
              color: appGreen,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${formatActivityMoment(start: activity.start, end: activity.end, allDay: activity.allDay)}'
          '${activity.venueName.isEmpty ? '' : ' · ${activity.venueName}'}',
          style: const TextStyle(fontSize: 17, color: appMutedText),
        ),
        if (past)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: StatusPill('Deze activiteit is geweest', tone: PillTone.few),
          ),
        const SizedBox(height: 20),
        ContentBlocks(activity.blocks),
        if (activity.organizer.isNotEmpty)
          Text(
            'Organisatie: ${activity.organizer}',
            style: const TextStyle(fontSize: 14.5, color: appMutedText),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://www.historischekringheemskerk.nl/evenement/${activity.slug}/?ical=1',
                ),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('Toevoegen aan kalender'),
            ),
          ],
        ),
      ],
    );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!past) RegistrationForm(activity: activity),
        if (!past) const SizedBox(height: 18),
        InfoBox(
          rows: [
            (
              'Wanneer',
              activity.multiDay
                  ? '${formatShortDate(activity.start)} t/m ${formatShortDate(activity.end!)}'
                  : activity.allDay
                  ? formatShortDate(activity.start)
                  : '${formatShortDate(activity.start)}, ${formatTime(activity.start)}'
                        '${activity.end == null ? '' : '–${formatTime(activity.end!)}'}',
            ),
            if (activity.venueName.isNotEmpty)
              (
                'Waar',
                [
                  activity.venueName,
                  activity.venueAddress,
                ].where((s) => s.isNotEmpty).join(', '),
              ),
            ('Kosten', activity.price ?? 'Gratis'),
            if (activity.organizer.isNotEmpty)
              ('Organisatie', activity.organizer),
            if (activity.registration?.capacity case final capacity?)
              ('Plaatsen', 'maximaal $capacity personen'),
            ('Vragen', practicalInfo.registrationEmail),
          ],
        ),
      ],
    );
    return SitePage(
      title: activity.title,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 12),
          child: Breadcrumbs(
            crumbs: const [('Agenda', '/agenda')],
            current: activity.title,
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 860
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [main, const SizedBox(height: 28), side],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: main),
                    const SizedBox(width: 36),
                    SizedBox(width: 380, child: side),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Inschrijven of op de wachtlijst. In deze fase wordt nog niets bewaard:
/// na verzenden verschijnt een voorbeeldbevestiging.
class RegistrationForm extends StatefulWidget {
  const RegistrationForm({required this.activity, super.key});
  final Activity activity;

  @override
  State<RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _remark = TextEditingController();
  int _persons = 1;
  bool? _member;
  bool _agreed = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _submit(bool waitlist) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ga akkoord met de privacyverklaring om door te gaan.'),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: waitlist ? 'Op de wachtlijst' : 'Ingeschreven',
        content: Text(
          waitlist
              ? 'U staat op de wachtlijst voor ‘${widget.activity.title}’ met $_persons ${_persons == 1 ? 'persoon' : 'personen'}. Komt er een plaats vrij, dan ontvangt u een e-mail op ${_email.text.trim()} en schuift u door.\n\nDit is een voorbeeld: er is nog niets bewaard.'
              : 'U bent ingeschreven voor ‘${widget.activity.title}’ met $_persons ${_persons == 1 ? 'persoon' : 'personen'}. U ontvangt een bevestiging op ${_email.text.trim()} met een link om af te melden.\n\nDit is een voorbeeld: er is nog niets bewaard.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registration = widget.activity.registration;
    if (registration == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vrij toegankelijk',
              style: TextStyle(
                fontFamily: appSerifFont,
                fontSize: 24,
                color: appGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.activity.kind == ActivityKind.expositie
                  ? 'Voor deze expositie hoeft u zich niet aan te melden. Loop binnen tijdens de openingstijden.'
                  : 'Voor deze activiteit hoeft u zich niet aan te melden.',
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      );
    }
    if (registration.isExternal) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aanmelden',
              style: TextStyle(
                fontFamily: appSerifFont,
                fontSize: 24,
                color: appGreen,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'De aanmelding voor deze activiteit loopt via de organiserende partner.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('registration-external'),
              onPressed: () => launchUrl(
                Uri.parse(registration.externalUrl!),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(registration.externalLabel ?? 'Aanmelden'),
            ),
          ],
        ),
      );
    }
    final full = registration.isFull;
    final capacity = registration.capacity;
    final status = registrationStatus(widget.activity);
    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              full ? 'Deze activiteit is vol' : 'Inschrijven',
              style: const TextStyle(
                fontFamily: appSerifFont,
                fontSize: 24,
                color: appGreen,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(
                capacity == null
                    ? status.text
                    : full
                    ? '$capacity van de $capacity plaatsen bezet'
                          '${registration.waitlist > 0 ? ' · ${registration.waitlist} op de wachtlijst' : ''}'
                    : 'Nog ${registration.free} van de $capacity plaatsen',
                tone: status.tone,
              ),
            ),
            if (capacity != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (registration.registered / capacity).clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE5E0D3),
                  color: full ? appFullForeground : appGreen,
                ),
              ),
            ],
            if (full) ...[
              const SizedBox(height: 12),
              const Text(
                'Zet u op de wachtlijst. Komt er een plaats vrij, dan krijgt de eerste op de lijst automatisch een e-mail en schuift u door.',
                style: TextStyle(fontSize: 14.5, height: 1.5),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('registration-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Naam'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Vul uw naam in.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('registration-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mailadres'),
              validator: (v) => (v ?? '').contains('@')
                  ? null
                  : 'Vul een geldig e-mailadres in.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('registration-persons'),
                    initialValue: _persons,
                    decoration: const InputDecoration(
                      labelText: 'Aantal personen',
                    ),
                    items: [
                      for (var i = 1; i <= 4; i++)
                        DropdownMenuItem(value: i, child: Text('$i')),
                    ],
                    onChanged: (v) => setState(() => _persons = v ?? 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<bool>(
                    key: const Key('registration-member'),
                    initialValue: _member,
                    decoration: const InputDecoration(
                      labelText: 'HKH-lid?',
                    ),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Ja')),
                      DropdownMenuItem(value: false, child: Text('Nee')),
                    ],
                    onChanged: (v) => setState(() => _member = v),
                  ),
                ),
              ],
            ),
            if (!full) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _remark,
                decoration: const InputDecoration(
                  labelText: 'Opmerking (niet verplicht)',
                  hintText: 'Bijvoorbeeld: slecht ter been',
                ),
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('registration-privacy'),
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Ik ga akkoord met de privacyverklaring',
                style: TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            full
                ? FilledButton.tonal(
                    key: const Key('registration-submit'),
                    onPressed: () => _submit(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: appAccentBackground,
                      foregroundColor: appGreen,
                    ),
                    child: const Text('Op de wachtlijst'),
                  )
                : FilledButton(
                    key: const Key('registration-submit'),
                    onPressed: () => _submit(false),
                    child: const Text('Inschrijven'),
                  ),
            const SizedBox(height: 10),
            Text(
              full
                  ? 'U ontvangt een bevestiging van uw plek op de wachtlijst en een link om u weer af te melden.'
                  : 'U ontvangt direct een bevestiging per e-mail met een link om af te melden. Zonder bevestiging bent u niet ingeschreven.',
              style: const TextStyle(fontSize: 12.5, color: appMutedText),
            ),
            const SizedBox(height: 10),
            const DemoNotice(),
          ],
        ),
      ),
    );
  }
}
