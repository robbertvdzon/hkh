import 'package:flutter/material.dart';

import '../content/content_models.dart';
import '../content/generated_memory.dart';
import '../content/site_structure.dart';
import '../theme/app_style.dart';
import 'site_widgets.dart';

const _crumbs = [('Geheugen van Heemskerk', '/geheugen')];

/// Overzicht van alle verhalen, optioneel beperkt tot thema, buurt of auteur.
class MemoryOverviewPage extends StatefulWidget {
  const MemoryOverviewPage({
    this.theme,
    this.neighbourhood,
    super.key,
  });
  final String? theme;
  final String? neighbourhood;

  @override
  State<MemoryOverviewPage> createState() => _MemoryOverviewPageState();
}

class _MemoryOverviewPageState extends State<MemoryOverviewPage> {
  String? _author;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = memoryStories(
      theme: widget.theme,
      neighbourhood: widget.neighbourhood,
      author: _author,
    ).where((s) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          s.narrator.toLowerCase().contains(q) ||
          s.summary.toLowerCase().contains(q);
    }).toList();
    final scope = widget.theme ?? widget.neighbourhood;
    final title = scope ?? 'Geheugen van Heemskerk';
    return SitePage(
      title: title,
      children: [
        PageHeading(
          title: scope == null ? 'Geheugen van Heemskerk' : _capitalize(scope),
          crumbs: scope == null
              ? const []
              : [
                  ..._crumbs,
                  if (widget.theme != null) ('Thema’s', '/geheugen/themas'),
                  if (widget.neighbourhood != null) ('Buurten', '/geheugen/buurten'),
                ],
          label: widget.theme != null
              ? 'Thema'
              : widget.neighbourhood != null
              ? 'Buurt'
              : null,
          intro: scope == null
              ? '${generatedMemoryStories.length} herinneringen van Heemskerkers, opgetekend tussen 2005 en 2010 door meer dan twintig verhalenverzamelaars. Zoek op titel of verteller, of kies een thema, buurt of verzamelaar.'
              : '${filtered.length} ${filtered.length == 1 ? 'verhaal' : 'verhalen'} ${widget.theme != null ? 'bij het thema' : 'uit de buurt'} ‘$scope’.',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                key: const Key('memory-search'),
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Zoek op titel of verteller',
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 300,
              child: DropdownButtonFormField<String?>(
                key: const Key('memory-author'),
                initialValue: _author,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Verhalenverzamelaar',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Alle verzamelaars'),
                  ),
                  for (final author in memoryAuthors())
                    DropdownMenuItem<String?>(
                      value: author.name,
                      child: Text(
                        '${author.name} (${author.count})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _author = v),
              ),
            ),
          ],
        ),
        if (scope == null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final theme in memoryThemes())
                ActionChip(
                  key: Key('memory-theme-${_slug(theme.name)}'),
                  label: Text('${theme.name} (${theme.count})'),
                  onPressed: () => navigateTo(
                    context,
                    '/geheugen/thema/${Uri.encodeComponent(theme.name)}',
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'Geen verhalen gevonden.',
              style: TextStyle(color: appMutedText),
            ),
          ),
        CardGrid(
          children: [
            for (final story in filtered) MemoryStoryCard(story: story),
          ],
        ),
      ],
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _slug(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

class MemoryStoryCard extends StatelessWidget {
  const MemoryStoryCard({required this.story, super.key});
  final MemoryStory story;

  @override
  Widget build(BuildContext context) => ContentCard(
    key: Key('memory-${story.slug}'),
    image: story.image,
    label: [
      story.theme,
      if (story.neighbourhood.isNotEmpty && story.neighbourhood != '.')
        story.neighbourhood,
    ].join(' · '),
    title: story.title,
    status: story.narrator.isEmpty
        ? null
        : Text(
            'Aan het woord: ${story.narrator}',
            style: const TextStyle(fontSize: 13.5, color: appMutedText),
          ),
    text: story.summary,
    onTap: () => navigateTo(context, '/geheugen/verhaal/${story.slug}'),
  );
}

/// Overzicht van thema's of buurten als kaarten met aantallen.
class MemoryGroupsPage extends StatelessWidget {
  const MemoryGroupsPage({required this.byNeighbourhood, super.key});
  final bool byNeighbourhood;

  @override
  Widget build(BuildContext context) {
    final groups = byNeighbourhood ? memoryNeighbourhoods() : memoryThemes();
    final title = byNeighbourhood ? 'Buurten' : 'Thema’s';
    return SitePage(
      title: title,
      children: [
        PageHeading(
          title: title,
          crumbs: _crumbs,
          intro: byNeighbourhood
              ? 'De verhalen zijn verzameld per buurt, zoals Welschap Welzijn Heemskerk indeelde.'
              : 'Elk verhaal hoort bij een thema, van school en werk tot verdwenen plekken en feesten.',
        ),
        CardGrid(
          children: [
            for (final group in groups)
              ContentCard(
                key: Key('memory-group-${_slug(group.name)}'),
                title: _capitalize(group.name),
                text: '${group.count} ${group.count == 1 ? 'verhaal' : 'verhalen'}',
                actionLabel: 'Bekijk de verhalen',
                actionFilled: false,
                onTap: () => navigateTo(
                  context,
                  '/geheugen/${byNeighbourhood ? 'buurt' : 'thema'}/${Uri.encodeComponent(group.name)}',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Over het project Geheugen van Heemskerk.
class MemoryAboutPage extends StatelessWidget {
  const MemoryAboutPage({super.key});

  @override
  Widget build(BuildContext context) => SitePage(
    title: 'Over het Geheugen van Heemskerk',
    children: [
      const PageHeading(
        title: 'Over het Geheugen van Heemskerk',
        crumbs: _crumbs,
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(memoryIntro, style: TextStyle(fontSize: 16.5, height: 1.55)),
            const SizedBox(height: 14),
            Text(
              'Samen geven de ${generatedMemoryStories.length} verhalen een levendige kijk op het leven in Heemskerk van vroeger en in de laatste decennia. De verhalen zijn ongewijzigd overgenomen; de verhalenverzamelaar staat bij elk verhaal vermeld.',
              style: const TextStyle(fontSize: 16.5, height: 1.55),
            ),
            for (final paragraph in generatedMemoryAbout) ...[
              const SizedBox(height: 14),
              Text(paragraph, style: const TextStyle(fontSize: 16.5, height: 1.55)),
            ],
            const SizedBox(height: 24),
            InfoBox(
              title: 'Zelf een verhaal?',
              rows: [
                ('E-mail', practicalInfo.email),
                ('Bezoek', '${practicalInfo.address}, ${practicalInfo.openingHours.toLowerCase()}'),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

/// Eén verhaal met foto's en bijpassende verhalen.
class MemoryStoryPage extends StatelessWidget {
  const MemoryStoryPage({required this.story, super.key});
  final MemoryStory story;

  @override
  Widget build(BuildContext context) {
    final related = story.relatedSlugs
        .map(memoryStoryBySlug)
        .whereType<MemoryStory>()
        .toList();
    const bodyStyle = TextStyle(fontSize: 16.5, height: 1.55);
    return SitePage(
      title: story.title,
      children: [
        PageHeading(
          title: story.title,
          crumbs: [
            ..._crumbs,
            (story.theme, '/geheugen/thema/${Uri.encodeComponent(story.theme)}'),
          ],
          label: [
            story.theme,
            if (story.neighbourhood.isNotEmpty && story.neighbourhood != '.')
              story.neighbourhood,
            if (story.period.isNotEmpty) story.period,
          ].join(' · '),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (story.narrator.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Aan het woord: ${story.narrator}',
                    style: const TextStyle(
                      fontFamily: appSerifFont,
                      fontSize: 19,
                      color: appGreen,
                    ),
                  ),
                ),
              for (final paragraph in story.intro)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    paragraph,
                    style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              for (final figure in story.figures) ...[
                SiteImage(
                  figure.src,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  borderRadius: BorderRadius.circular(12),
                ),
                if (figure.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      figure.caption,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                        color: appMutedText,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
              for (final paragraph in story.body)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(paragraph, style: bodyStyle),
                ),
              const SizedBox(height: 8),
              Text(
                'Opgetekend door ${story.author} voor het Geheugen van Heemskerk.',
                style: const TextStyle(fontSize: 14.5, color: appMutedText),
              ),
            ],
          ),
        ),
        if (related.isNotEmpty) ...[
          const SizedBox(height: 36),
          const SectionHeader('Bijpassende verhalen'),
          CardGrid(
            children: [
              for (final other in related.take(6))
                MemoryStoryCard(story: other),
            ],
          ),
        ],
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => navigateTo(context, '/geheugen'),
            child: const Text('Alle verhalen'),
          ),
        ),
      ],
    );
  }
}
