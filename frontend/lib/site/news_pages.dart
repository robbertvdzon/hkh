import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../content/content_models.dart';
import '../content/site_structure.dart';
import '../theme/app_style.dart';
import 'content_renderer.dart';
import 'date_format.dart';
import 'site_widgets.dart';

/// Nieuwsoverzicht met ingangen naar nieuwsbrieven en Heemskring.
class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) => SitePage(
    title: 'Nieuws',
    children: [
      const PageHeading(
        title: 'Nieuws',
        intro:
            'Berichten van de Historische Kring Heemskerk. Aankondigingen van activiteiten vindt u ook in de agenda.',
      ),
      const SizedBox(height: 24),
      CardGrid(
        children: [
          for (final post in newsPosts)
            ContentCard(
              image: post.image,
              label: formatDate(post.published),
              title: post.title,
              text: post.summary,
              onTap: () => navigateTo(context, '/nieuws/${post.slug}'),
            ),
        ],
      ),
    ],
  );
}

class NewsArticlePage extends StatelessWidget {
  const NewsArticlePage({required this.post, super.key});
  final NewsPost post;

  @override
  Widget build(BuildContext context) => SitePage(
    title: post.title,
    children: [
      PageHeading(
        title: post.title,
        crumbs: const [('Nieuws', '/nieuws')],
        label: formatLongDate(post.published),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (post.image != null) ...[
              SiteImage(
                post.image!,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                borderRadius: BorderRadius.circular(14),
              ),
              const SizedBox(height: 22),
            ],
            ContentBlocks(post.blocks),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: () => navigateTo(context, '/nieuws'),
          child: const Text('Alle berichten'),
        ),
      ),
    ],
  );
}

class NewslettersPage extends StatelessWidget {
  const NewslettersPage({super.key});

  @override
  Widget build(BuildContext context) => SitePage(
    title: 'Nieuwsbrieven',
    children: [
      const PageHeading(
        title: 'Nieuwsbrieven',
        crumbs: [('Nieuws', '/nieuws')],
        intro:
            'Twee maal per jaar verschijnt de Nieuwsbrief van de HKH vooruitlopend op de voorjaarsledenvergadering en de najaarsledenvergadering. De Nieuwsbrief is bedoeld om de leden bij te praten over de vereniging en haar activiteiten, maar ook om hen uit te nodigen voor de ledenvergaderingen. Belangrijke zaken de HKH aangaande worden tijdens ledenvergaderingen besproken en er wordt gestemd als er besluiten genomen moeten worden. Bestuursleden worden benoemd en de nieuwe Heemskring wordt er gepresenteerd.',
      ),
      for (final newsletter in newsletters)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AppCard(
            key: Key('newsletter-${newsletter.number}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  newsletter.title,
                  style: const TextStyle(
                    fontFamily: appSerifFont,
                    fontSize: 22,
                    color: appGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  newsletter.description,
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(newsletter.pdfUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Download deze nieuwsbrief'),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class HeemskringPage extends StatelessWidget {
  const HeemskringPage({super.key});

  @override
  Widget build(BuildContext context) => SitePage(
    title: 'Heemskring',
    children: [
      const PageHeading(
        title: 'Heemskring',
        crumbs: [('Nieuws', '/nieuws')],
        intro: heemskringIntro,
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final image = SiteImage(
            heemskringImage,
            width: constraints.maxWidth < 700 ? double.infinity : 360,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.circular(14),
          );
          final actions = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lezen en verkrijgen',
                style: TextStyle(
                  fontFamily: appSerifFont,
                  fontSize: 24,
                  color: appGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Leden ontvangen elk nummer thuis. Losse nummers zijn te koop in het Historisch Huis op maandagmiddag. Oudere artikelen zijn volledig doorzoekbaar in de collectie Artikelen; van nummers jonger dan vijf jaar is een samenvatting opgenomen.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    key: const Key('heemskring-articles'),
                    onPressed: () =>
                        navigateTo(context, '/zoeken?collection=artikelen'),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Zoek in de Heemskring-artikelen'),
                  ),
                  OutlinedButton(
                    onPressed: () => navigateTo(context, '/lid-worden'),
                    child: const Text('Lid worden'),
                  ),
                  OutlinedButton(
                    onPressed: () => navigateTo(context, '/vereniging/uitgaven'),
                    child: const Text('Uitgaven en winkel'),
                  ),
                ],
              ),
            ],
          );
          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [image, const SizedBox(height: 20), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              image,
              const SizedBox(width: 32),
              Expanded(child: actions),
            ],
          );
        },
      ),
    ],
  );
}
