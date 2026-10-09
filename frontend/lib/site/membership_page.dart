import 'package:flutter/material.dart';

import '../content/site_structure.dart';
import '../theme/app_style.dart';
import 'site_widgets.dart';

/// Lid worden: waarom, wat het kost en het aanmeldformulier (voorbeeld).
class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = {
    for (final field in _fields) field: TextEditingController(),
  };
  String _salutation = 'nvt.';
  bool _agreedPrivacy = false;
  bool _agreedDebit = false;

  static const _fields = [
    'Voorletter(s)',
    'Naam',
    'Straatnaam en huisnummer',
    'Postcode',
    'Woonplaats',
    'Telefoonnummer',
    'E-mail',
    'Bankrekeningnummer',
    'Bericht',
  ];
  static const _required = {
    'Naam',
    'Straatnaam en huisnummer',
    'Postcode',
    'Woonplaats',
    'E-mail',
    'Bankrekeningnummer',
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedPrivacy || !_agreedDebit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ga akkoord met de privacyverklaring en de automatische incasso om door te gaan.',
          ),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Welkom bij de HKH',
        content: Text(
          'Bedankt voor uw aanmelding, ${_controllers['Naam']!.text.trim()}. De ledenadministratie bevestigt uw lidmaatschap per e-mail.\n\nDit is een voorbeeld: er is nog niets bewaard.',
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
    final benefits = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lidmaatschap kost ${practicalInfo.membershipFee}.',
          style: const TextStyle(
            fontFamily: appSerifFont,
            fontSize: 24,
            color: appGreen,
          ),
        ),
        const SizedBox(height: 12),
        for (final benefit in const [
          'Twee keer per jaar het magazine Heemskring thuisbezorgd.',
          'Twee keer per jaar de nieuwsbrief en een uitnodiging voor de ledenvergadering.',
          'Ledenprijs bij uitgaven en betaalde activiteiten.',
          'U steunt het verzamelen, bewaren en vertellen van de geschiedenis van Heemskerk.',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check, size: 20, color: appGreen),
                const SizedBox(width: 8),
                Expanded(child: Text(benefit, style: const TextStyle(height: 1.5))),
              ],
            ),
          ),
        const SizedBox(height: 10),
        const Text(
          'De HKH is een levendige, actieve vereniging voor alle Heemskerkers. In 1988 gestart, inmiddels met ruim 1.800 leden en meer dan honderd actieve vrijwilligers.',
          style: TextStyle(height: 1.5, color: appMutedText),
        ),
      ],
    );
    final form = AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Aanmelden als lid',
              style: TextStyle(
                fontFamily: appSerifFont,
                fontSize: 24,
                color: appGreen,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _salutation,
              decoration: const InputDecoration(labelText: 'Aanhef'),
              items: const [
                DropdownMenuItem(value: 'de Heer', child: Text('de Heer')),
                DropdownMenuItem(value: 'Mevrouw', child: Text('Mevrouw')),
                DropdownMenuItem(value: 'nvt.', child: Text('n.v.t.')),
              ],
              onChanged: (v) => setState(() => _salutation = v ?? 'nvt.'),
            ),
            for (final field in _fields) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: Key('membership-${field.toLowerCase().split(' ').first}'),
                controller: _controllers[field],
                keyboardType: field == 'E-mail'
                    ? TextInputType.emailAddress
                    : field == 'Telefoonnummer'
                    ? TextInputType.phone
                    : TextInputType.text,
                minLines: field == 'Bericht' ? 3 : 1,
                maxLines: field == 'Bericht' ? 6 : 1,
                decoration: InputDecoration(
                  labelText: _required.contains(field) ? '$field *' : field,
                  alignLabelWithHint: field == 'Bericht',
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (_required.contains(field) && value.isEmpty) {
                    return 'Dit veld is verplicht.';
                  }
                  if (field == 'E-mail' && !value.contains('@')) {
                    return 'Vul een geldig e-mailadres in.';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('membership-privacy'),
              value: _agreedPrivacy,
              onChanged: (v) => setState(() => _agreedPrivacy = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Historische Kring Heemskerk slaat de door u ingevulde gegevens op maar gebruikt deze alleen om contact met u op te nemen en zal uw persoonlijke gegevens nooit zonder uw toestemming aan derden overhandigen.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            CheckboxListTile(
              key: const Key('membership-debit'),
              value: _agreedDebit,
              onChanged: (v) => setState(() => _agreedDebit = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Ik ga akkoord met de automatische incasso van de contributie.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('membership-submit'),
              onPressed: _submit,
              child: const Text('Verstuur'),
            ),
            const SizedBox(height: 10),
            const DemoNotice(),
          ],
        ),
      ),
    );
    return SitePage(
      title: 'Lid worden',
      children: [
        const PageHeading(
          title: 'Lid worden van de Historische Kring Heemskerk',
          intro:
              'Word lid en help mee de geschiedenis van Heemskerk te bewaren en te vertellen.',
        ),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 860
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [benefits, const SizedBox(height: 28), form],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: form),
                    const SizedBox(width: 36),
                    Expanded(child: benefits),
                  ],
                ),
        ),
      ],
    );
  }
}
