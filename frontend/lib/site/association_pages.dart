import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../content/content_models.dart';
import '../content/generated_content.dart';
import '../content/site_structure.dart';
import '../theme/app_style.dart';
import 'content_renderer.dart';
import 'discover_pages.dart';
import 'site_widgets.dart';

const _crumbs = [('Vereniging', '/vereniging')];

/// Bouwt de pagina voor een onderdeel van Vereniging, of null bij een
/// onbekende slug.
Widget? associationSectionPage(String slug) {
  switch (slug) {
    case 'bestuur':
      return const BoardPage();
    case 'uitgaven':
      return const PublicationsPage();
    case 'anbi':
      return const DocumentsPage();
    case 'contact':
      return const ContactPage();
    case 'links':
      return const LinksPage();
    case 'historisch-huis':
      return const HistoricHousePage();
    case 'werkgroepen':
      final page = pageBySlug('werkgroepen');
      if (page == null) return null;
      return StoryPage(
        page: page,
        crumbs: _crumbs,
        label: 'Vereniging',
        extraActions: [
          Builder(
            builder: (context) => FilledButton.icon(
              key: const Key('workgroups-join'),
              onPressed: () => navigateTo(context, '/vereniging/contact'),
              icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
              label: const Text('Vrijwilliger worden'),
            ),
          ),
          Builder(
            builder: (context) => OutlinedButton(
              onPressed: () => navigateTo(context, '/educatie'),
              child: const Text('Lesaanbod van de werkgroep Educatie'),
            ),
          ),
        ],
      );
    default:
      for (final section in associationSections) {
        if (section.slug == slug && section.pageSlug != null) {
          final page = pageBySlug(section.pageSlug!);
          if (page == null) return null;
          return StoryPage(
            page: page,
            crumbs: _crumbs,
            label: 'Vereniging',
            extraActions: slug == 'over-de-hkh'
                ? [
                    Builder(
                      builder: (context) => FilledButton(
                        key: const Key('about-membership'),
                        onPressed: () => navigateTo(context, '/lid-worden'),
                        child: Text(
                          'Lid worden voor ${practicalInfo.membershipFee}',
                        ),
                      ),
                    ),
                    Builder(
                      builder: (context) => OutlinedButton(
                        onPressed: () => navigateTo(context, '/vereniging/links'),
                        child: const Text('Partnerorganisaties'),
                      ),
                    ),
                  ]
                : const [],
          );
        }
      }
      return null;
  }
}

class BoardPage extends StatelessWidget {
  const BoardPage({super.key});

  @override
  Widget build(BuildContext context) => SitePage(
    title: 'Bestuur',
    children: [
      const PageHeading(
        title: 'Bestuur',
        crumbs: _crumbs,
        intro:
            'Maak op deze pagina kennis met de bestuursleden van de Historische Kring Heemskerk.',
      ),
      CardGrid(
        children: [
          for (final member in generatedBoard)
            AppCard(
              key: Key('board-${member.name.toLowerCase().replaceAll(' ', '-')}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (member.image != null)
                    SiteImage(
                      member.image!,
                      height: 220,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontFamily: appSerifFont,
                      fontSize: 22,
                      color: appGreen,
                    ),
                  ),
                  Text(
                    member.role,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: appSandForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Actief sinds ${member.since}',
                      style: const TextStyle(color: appMutedText, fontSize: 14)),
                  Text(member.phone,
                      style: const TextStyle(color: appMutedText, fontSize: 14)),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse('mailto:${member.email}')),
                    child: Text(
                      member.email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: appGreen,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  if (member.bio.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(member.bio, style: const TextStyle(height: 1.5)),
                  ],
                ],
              ),
            ),
        ],
      ),
    ],
  );
}

/// Historisch Huis: openingstijden en adres eerst, daarna de geschiedenis.
class HistoricHousePage extends StatelessWidget {
  const HistoricHousePage({super.key});

  @override
  Widget build(BuildContext context) {
    final opening = pageBySlug('openstelling-historisch-huis');
    final history = pageBySlug('historisch-huis');
    return SitePage(
      title: 'Historisch Huis',
      children: [
        const PageHeading(
          title: 'Historisch Huis',
          crumbs: _crumbs,
          label: 'Vereniging',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final info = InfoBox(
              title: 'Bezoek',
              rows: [
                ('Adres', '${practicalInfo.address}, ${practicalInfo.postalCode}'),
                ('Open', practicalInfo.openingHours),
                ('Telefoon', practicalInfo.phone),
                ('Post', practicalInfo.postbox),
              ],
            );
            final text = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (opening != null) ...[
                  if (opening.image != null) ...[
                    SiteImage(
                      opening.image!,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    const SizedBox(height: 22),
                  ],
                  const Text(
                    'Openstelling',
                    style: TextStyle(
                      fontFamily: appSerifFont,
                      fontSize: 26,
                      color: appGreen,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ContentBlocks(opening.blocks),
                ],
                if (history != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'De St. Mariaschool',
                    style: TextStyle(
                      fontFamily: appSerifFont,
                      fontSize: 26,
                      color: appGreen,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ContentBlocks(history.blocks),
                ],
              ],
            );
            if (constraints.maxWidth < 860) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [info, const SizedBox(height: 24), text],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: text),
                const SizedBox(width: 36),
                SizedBox(width: 360, child: info),
              ],
            );
          },
        ),
      ],
    );
  }
}

class PublicationsPage extends StatelessWidget {
  const PublicationsPage({super.key});

  @override
  Widget build(BuildContext context) => SitePage(
    title: 'Uitgaven en winkel',
    children: [
      const PageHeading(
        title: 'Uitgaven en winkel',
        crumbs: _crumbs,
        intro:
            'Hier vindt u alle boeken, DVD’s, wandelingen en andere uitgaven van de Historische Kring Heemskerk. Kijk rustig rond en klik naar de detailpagina van de uitgave van uw keuze. Op deze pagina staat tevens vermeld waar u de betreffende uitgave kunt verkrijgen.',
      ),
      AppCard(
        color: appAccentBackground,
        child: Row(
          children: [
            SiteImage(
              heemskringImage,
              width: 120,
              height: 90,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Heemskring',
                    style: TextStyle(
                      fontFamily: appSerifFont,
                      fontSize: 22,
                      color: appGreen,
                    ),
                  ),
                  const Text(
                    'Het magazine van de HKH, twee keer per jaar. Leden gratis; losse nummers te koop in het Historisch Huis.',
                    style: TextStyle(height: 1.5),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => navigateTo(context, '/nieuws/heemskring'),
                    child: const Text(
                      'Meer over de Heemskring →',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      CardGrid(
        children: [
          for (final publication in generatedPublications)
            ContentCard(
              key: Key('publication-${publication.slug}'),
              image: publication.image,
              label: publication.category,
              title: publication.title,
              text: publication.description,
              status: Text(
                [
                  if (publication.memberPrice != null)
                    'Leden ${publication.memberPrice}',
                  if (publication.price != null)
                    'Niet-leden ${publication.price}',
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AppDialog(
                  title: publication.title,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(publication.description),
                      const SizedBox(height: 12),
                      Text('Verkrijgbaar bij: ${publication.availability}'),
                      if (publication.memberPrice != null)
                        Text('Prijs voor leden: ${publication.memberPrice}'),
                      if (publication.price != null)
                        Text('Prijs voor niet-leden: ${publication.price}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Sluiten'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 22),
      const Text(
        'Uitgaven zijn af te halen in het Historisch Huis op maandagmiddag tussen 14.00 en 16.00 uur. Online bestellen is niet mogelijk.',
        style: TextStyle(color: appMutedText),
      ),
    ],
  );
}

/// ANBI en documenten: financiën, beleidsplan, privacy en disclaimer op één pagina.
class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = documentPageSlugs.map(pageBySlug).whereType<ContentPage>();
    return SitePage(
      title: 'ANBI en documenten',
      children: [
        const PageHeading(
          title: 'ANBI en documenten',
          crumbs: _crumbs,
          intro:
              'De HKH is een vereniging met ANBI-status. Hier vindt u de financiële verantwoording, het beleidsplan, het privacyreglement, de integriteitsregeling en de disclaimer.',
        ),
        for (final page in pages) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: Text(
              page.title,
              style: const TextStyle(
                fontFamily: appSerifFont,
                fontSize: 26,
                color: appGreen,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ContentBlocks(page.blocks),
          ),
          const Divider(height: 36),
        ],
      ],
    );
  }
}

class LinksPage extends StatelessWidget {
  const LinksPage({super.key});

  @override
  Widget build(BuildContext context) => SitePage(
    title: 'Links',
    children: [
      const PageHeading(
        title: 'Links',
        crumbs: _crumbs,
        intro: 'Organisaties waarmee de HKH samenwerkt of die u ook kunnen helpen.',
      ),
      CardGrid(
        children: [
          for (final link in partnerLinks)
            ContentCard(
              title: link.name,
              text: link.url.replaceFirst(RegExp(r'^https?://(www\.)?'), ''),
              actionLabel: 'Bezoek de website',
              actionFilled: false,
              onTap: () => launchUrl(
                Uri.parse(link.url),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
    ],
  );
}

/// Contact: bericht sturen (voorbeeld), adres en openingstijden.
class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _recipient = contactRecipients.first;
  bool _agreed = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _subject, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_agreed) {
      if (!_agreed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ga akkoord met de privacyverklaring om door te gaan.'),
          ),
        );
      }
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Bericht verstuurd',
        content: Text(
          'Uw bericht aan de ${_recipient.toLowerCase()} is verstuurd. U krijgt antwoord op ${_email.text.trim()}.\n\nDit is een voorbeeld: er is nog niets bewaard.',
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
    final form = AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Stuur bericht naar Historische Kring Heemskerk',
              style: TextStyle(
                fontFamily: appSerifFont,
                fontSize: 24,
                color: appGreen,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Vul onderstaand formulier in om via deze site een bericht te sturen naar de HKH.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('contact-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Naam'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Vul uw naam in.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('contact-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: (v) =>
                  (v ?? '').contains('@') ? null : 'Vul een geldig e-mailadres in.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Onderwerp'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('contact-recipient'),
              initialValue: _recipient,
              decoration: const InputDecoration(labelText: 'Stuur bericht naar'),
              items: [
                for (final recipient in contactRecipients)
                  DropdownMenuItem(value: recipient, child: Text(recipient)),
              ],
              onChanged: (v) => setState(() => _recipient = v ?? _recipient),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('contact-message'),
              controller: _message,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Bericht',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Schrijf een bericht.' : null,
            ),
            CheckboxListTile(
              key: const Key('contact-privacy'),
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Historische Kring Heemskerk slaat de door u ingevulde gegevens op maar gebruikt deze alleen om contact met u op te nemen en zal uw persoonlijke gegevens nooit zonder uw toestemming aan derden overhandigen.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('contact-submit'),
              onPressed: _submit,
              child: const Text('Verstuur'),
            ),
            const SizedBox(height: 10),
            const DemoNotice(),
          ],
        ),
      ),
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBox(
          title: 'Bezoek en postadres',
          rows: [
            ('Adres', '${practicalInfo.address}, ${practicalInfo.postalCode}'),
            ('Open', practicalInfo.openingHours),
            ('Telefoon', practicalInfo.phone),
            ('E-mail', practicalInfo.email),
            ('Post', practicalInfo.postbox),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(practicalInfo.mapsUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Route in Google Maps'),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final social in socialLinks)
              OutlinedButton(
                onPressed: () => launchUrl(
                  Uri.parse(social.url),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(social.name),
              ),
          ],
        ),
      ],
    );
    return SitePage(
      title: 'Contact',
      children: [
        const PageHeading(title: 'Contact', crumbs: _crumbs),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 860
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [info, const SizedBox(height: 24), form],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: form),
                    const SizedBox(width: 36),
                    SizedBox(width: 360, child: info),
                  ],
                ),
        ),
      ],
    );
  }
}
