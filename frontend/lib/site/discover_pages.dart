import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../content/content_models.dart';
import '../content/site_structure.dart';
import '../theme/app_style.dart';
import 'content_renderer.dart';
import 'site_widgets.dart';

/// Eén rubriek van Ontdek Heemskerk met haar verhalen.
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({required this.category, super.key});
  final StoryCategory category;

  @override
  Widget build(BuildContext context) => SitePage(
    title: category.title,
    children: [
      PageHeading(
        title: category.title,
        crumbs: const [('Ontdek Heemskerk', '/ontdek')],
        intro: category.description,
      ),
      CardGrid(
        children: [
          for (final slug in category.pageSlugs)
            if (pageBySlug(slug) case final page?)
              ContentCard(
                image: page.image,
                label: category.title,
                title: page.title,
                text: page.summary,
                onTap: () => navigateTo(context, '/ontdek/${page.slug}'),
              ),
        ],
      ),
      if (category.slug == 'kastelen') ...[
        const SizedBox(height: 32),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('discover-luchtfoto'),
            onPressed: () => navigateTo(context, '/luchtfoto'),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Luchtfoto van Heemskerk, toen en nu'),
          ),
        ),
      ],
      if (category.slug == 'verhalen') ...[
        const SizedBox(height: 32),
        CallToActionBand(
          title: 'Op zoek naar persoonlijke herinneringen?',
          text:
              'De verhalen van Heemskerkers zelf, opgetekend tussen 2005 en 2010, staan in het Geheugen van Heemskerk.',
          actionLabel: 'Naar het Geheugen van Heemskerk',
          onAction: () => navigateTo(context, '/geheugen'),
        ),
      ],
    ],
  );
}

/// Eén verhaal of informatiepagina, met de tekst en foto's van de oude site.
class StoryPage extends StatelessWidget {
  const StoryPage({
    required this.page,
    this.crumbs = const [('Ontdek Heemskerk', '/ontdek')],
    this.label,
    this.extraActions = const [],
    this.leading = const [],
    super.key,
  });
  final ContentPage page;
  final List<(String, String)> crumbs;
  final String? label;

  /// Knoppen onder de tekst, bijvoorbeeld een kaart of een document.
  final List<Widget> extraActions;

  /// Blokken boven de tekst, bijvoorbeeld openingstijden.
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    final category = storyCategoryOfPage(page.slug);
    final isCastleMap = page.slug == 'alle-kastelen-op-de-kaart';
    final related = category?.pageSlugs
            .where((s) => s != page.slug)
            .map(pageBySlug)
            .whereType<ContentPage>()
            .toList() ??
        const <ContentPage>[];
    return SitePage(
      title: page.title,
      children: [
        PageHeading(
          title: page.title,
          crumbs: [
            ...crumbs,
            if (category != null && crumbs.length == 1)
              (category.title, '/ontdek/${category.slug}'),
          ],
          label: label ?? category?.title,
        ),
        ...leading,
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (page.image != null &&
                  !page.blocks.any(
                    (b) => b is ImageBlock && b.src == page.image,
                  )) ...[
                SiteImage(
                  page.image!,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(height: 22),
              ],
              ContentBlocks(page.blocks),
              if (page.gallery.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final url in page.gallery)
                      SiteImage(
                        url,
                        width: 180,
                        height: 135,
                        borderRadius: BorderRadius.circular(8),
                      ),
                  ],
                ),
              ],
              if (isCastleMap || extraActions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (isCastleMap)
                      FilledButton.icon(
                        key: const Key('castle-map-button'),
                        onPressed: () => launchUrl(
                          Uri.parse(castleMapUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Open de kastelenkaart'),
                      ),
                    ...extraActions,
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        _MoreInCollections(page: page),
        if (related.isNotEmpty) ...[
          const SizedBox(height: 36),
          SectionHeader('Meer in ${category!.title.toLowerCase()}'),
          CardGrid(
            children: [
              for (final other in related.take(6))
                ContentCard(
                  image: other.image,
                  title: other.title,
                  text: other.summary,
                  onTap: () => navigateTo(context, '/ontdek/${other.slug}'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Voorgevulde zoekopdracht in de collecties over het onderwerp van de pagina.
class _MoreInCollections extends StatelessWidget {
  const _MoreInCollections({required this.page});
  final ContentPage page;

  String get _query {
    final title = page.title
        .replaceAll(RegExp(r'^Kastelen\s*[-–]\s*'), '')
        .replaceAll(RegExp(r'\s*\(.*\)$'), '');
    return title.split(' en ').first.trim();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: appAccentBackground,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 10,
      children: [
        const Text(
          'Meer in de collecties over dit onderwerp',
          style: TextStyle(
            fontFamily: appSerifFont,
            fontSize: 20,
            color: appGreen,
          ),
        ),
        FilledButton.icon(
          key: const Key('more-in-collections'),
          onPressed: () => navigateTo(
            context,
            Uri(path: '/zoeken', queryParameters: {'q': _query}).toString(),
          ),
          icon: const Icon(Icons.search, size: 18),
          label: Text('Zoek op ‘$_query’'),
        ),
      ],
    ),
  );
}
