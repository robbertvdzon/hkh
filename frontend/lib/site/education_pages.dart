import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../content/content_models.dart';
import '../content/site_structure.dart';
import '../theme/app_style.dart';
import 'site_widgets.dart';

/// Educatie: het lesaanbod voor het basisonderwijs als kaarten.
class EducationPage extends StatefulWidget {
  const EducationPage({super.key});

  @override
  State<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage> {
  String? _groupFilter;

  static const _groupFilters = ['Groep 1–4', 'Groep 5–6', 'Groep 7–8'];

  bool _matches(EducationItem item) {
    final filter = _groupFilter;
    if (filter == null) return true;
    final groups = item.groups.toLowerCase();
    if (groups.contains('alle groepen')) return true;
    return switch (filter) {
      'Groep 1–4' => false,
      'Groep 5–6' => false,
      _ => groups.contains('7') || groups.contains('8'),
    };
  }

  @override
  Widget build(BuildContext context) => SitePage(
    title: 'Educatie',
    children: [
      PageHeading(
        title: 'Educatie: lesaanbod voor het basisonderwijs',
        intro: educationIntro,
        trailing: OutlinedButton.icon(
          key: const Key('education-brochure'),
          onPressed: () => launchUrl(
            Uri.parse(educationBrochureUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Brochure als PDF'),
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Alle groepen'),
            selected: _groupFilter == null,
            onSelected: (_) => setState(() => _groupFilter = null),
          ),
          for (final filter in _groupFilters)
            ChoiceChip(
              label: Text(filter),
              selected: _groupFilter == filter,
              onSelected: (_) => setState(
                () => _groupFilter = _groupFilter == filter ? null : filter,
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
      CardGrid(
        children: [
          for (final item in educationItems.where(_matches))
            ContentCard(
              key: Key('education-${item.slug}'),
              image: item.image,
              label: item.kind,
              title: item.title,
              status: Text(
                [
                  item.groups,
                  if (item.cost != null) _shortCost(item.cost!),
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              text: item.description,
              actionLabel: item.actionLabel,
              actionFilled: item.requestable,
              onTap: () => navigateTo(context, '/educatie/${item.slug}'),
            ),
        ],
      ),
      const SizedBox(height: 34),
      CallToActionBand(
        title: 'Werkgroep Educatie',
        text:
            'Vragen of een eigen idee? De werkgroep draagt de historie van Heemskerk uit op de basisscholen, werkt samen met Museum Kennemerland en Cultuurhuis Heemskerk en nodigt alle Heemskerkse basisscholen jaarlijks uit.',
        actionLabel: 'Stuur een bericht',
        onAction: () => navigateTo(context, '/vereniging/contact'),
      ),
    ],
  );
}

String _shortCost(String cost) {
  if (cost.toLowerCase().contains('geen kosten')) return 'gratis';
  return cost;
}

/// Eén onderdeel van het lesaanbod met aanvraagformulier.
class EducationItemPage extends StatelessWidget {
  const EducationItemPage({required this.item, super.key});
  final EducationItem item;

  @override
  Widget build(BuildContext context) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.image != null)
          SiteImage(
            item.image!,
            height: 320,
            width: double.infinity,
            borderRadius: BorderRadius.circular(14),
          ),
        const SizedBox(height: 22),
        _Section('Omschrijving', item.description),
        _ListSection('Koppeling aan kerndoelen en leergebieden', item.goals),
        if (item.organisation != null) _Section('Organisatie', item.organisation!),
        if (item.duration != null)
          _Section('Duur en voorbereidingstijd', item.duration!),
        if (item.status != null) _Section('Status', item.status!),
        if (item.registration != null) _Section('Aanmelding', item.registration!),
        if (item.cost != null) _Section('Kosten', item.cost!),
      ],
    );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RequestForm(item: item),
        const SizedBox(height: 18),
        InfoBox(
          rows: [
            ('Doelgroep', item.groups),
            ('Soort', item.kind),
            if (item.cost != null) ('Kosten', _shortCost(item.cost!)),
            ('Contact', practicalInfo.email),
          ],
        ),
      ],
    );
    return SitePage(
      title: item.title,
      children: [
        PageHeading(
          title: item.title,
          crumbs: const [('Educatie', '/educatie')],
          label: '${item.kind} · ${item.groups}',
        ),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 860
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [details, const SizedBox(height: 28), side],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 36),
                    SizedBox(width: 380, child: side),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.text);
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: appSerifFont,
            fontSize: 21,
            color: appGreen,
          ),
        ),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(fontSize: 16.5, height: 1.55)),
      ],
    ),
  );
}

class _ListSection extends StatelessWidget {
  const _ListSection(this.title, this.items);
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: appSerifFont,
            fontSize: 21,
            color: appGreen,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 22, child: Text('•')),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 16.5, height: 1.55),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Aanvraagformulier voor scholen. Bewaart in deze fase nog niets.
class _RequestForm extends StatefulWidget {
  const _RequestForm({required this.item});
  final EducationItem item;

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _school = TextEditingController();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _group = TextEditingController();
  final _period = TextEditingController();

  @override
  void dispose() {
    for (final c in [_school, _contact, _email, _group, _period]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Aanvraag verstuurd',
        content: Text(
          'Bedankt. De werkgroep Educatie neemt contact op met ${_contact.text.trim()} van ${_school.text.trim()} over ‘${widget.item.title}’.\n\nDit is een voorbeeld: er is nog niets bewaard.',
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
  Widget build(BuildContext context) => AppCard(
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item.requestable ? 'Aanvragen' : widget.item.actionLabel,
            style: const TextStyle(
              fontFamily: appSerifFont,
              fontSize: 24,
              color: appGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.item.requestable
                ? 'Vul de gegevens van uw school in; de werkgroep neemt contact op om een datum af te spreken.'
                : 'Laat uw gegevens achter; de werkgroep neemt contact op zodra dit onderdeel beschikbaar is.',
            style: const TextStyle(fontSize: 14.5, height: 1.5),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('education-school'),
            controller: _school,
            decoration: const InputDecoration(labelText: 'School'),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Vul de naam van de school in.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('education-contact'),
            controller: _contact,
            decoration: const InputDecoration(labelText: 'Contactpersoon'),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Vul een contactpersoon in.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('education-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mailadres'),
            validator: (v) =>
                (v ?? '').contains('@') ? null : 'Vul een geldig e-mailadres in.',
          ),
          if (widget.item.requestable) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _group,
                    decoration: const InputDecoration(
                      labelText: 'Groep en aantal leerlingen',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _period,
                    decoration: const InputDecoration(
                      labelText: 'Gewenste periode',
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('education-submit'),
            onPressed: _submit,
            child: Text(widget.item.actionLabel),
          ),
          const SizedBox(height: 10),
          const DemoNotice(),
        ],
      ),
    ),
  );
}
