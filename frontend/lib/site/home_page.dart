import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ai_search/ai_search.dart';
import '../content/generated_memory.dart';
import '../content/site_structure.dart';
import '../theme/app_style.dart';
import 'activity_widgets.dart';
import 'date_format.dart';
import 'site_widgets.dart';

/// Homepage: fotostrook en intro, komende activiteiten, zoeken en vragen,
/// nieuws, uitgelichte verhalen, educatie en praktische informatie.
class HomePage extends StatelessWidget {
  const HomePage({this.questionsEnabled = true, this.now, super.key});

  /// Zonder AI-bron ontbreekt het blok 'Onderzoek'.
  final bool questionsEnabled;

  /// Peilmoment voor 'komende' activiteiten; standaard nu.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final now = this.now ?? DateTime.now();
    final upcoming = upcomingActivities(now).take(3).toList();
    final news = newsPosts.take(3).toList();
    final narrow = isNarrowLayout(context);
    Widget boxed(List<Widget> children) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: appContentMaxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
    return Theme(
      data: appPageTheme(context),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: HkhAppBar(
            context: context,
            title: const Text(siteName),
            showPageTitle: false,
          ),
          body: SelectionArea(
            child: SafeArea(
              top: false,
              child: ListView(
                key: const Key('home-scroll'),
                padding: EdgeInsets.zero,
                children: [
                  const _Hero(),
                  boxed([
                    const SizedBox(height: 44),
                    const SectionHeader(
                      'Binnenkort',
                      linkLabel: 'Hele agenda',
                      linkPath: '/agenda',
                    ),
                    CardGrid(
                      children: [
                        for (final activity in upcoming)
                          ActivityCard(activity: activity),
                      ],
                    ),
                    const SizedBox(height: 44),
                  ]),
                  FullWidthBand(
                    color: appAccentBackground,
                    child: _SearchAndAsk(questionsEnabled: questionsEnabled),
                  ),
                  boxed([
                    const SizedBox(height: 44),
                    const SectionHeader(
                      'Nieuws',
                      linkLabel: 'Al het nieuws',
                      linkPath: '/nieuws',
                    ),
                    CardGrid(
                      children: [
                        for (final post in news)
                          ContentCard(
                            image: post.image,
                            label: formatDate(post.published),
                            title: post.title,
                            text: post.summary,
                            onTap: () =>
                                navigateTo(context, '/nieuws/${post.slug}'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 44),
                  ]),
                  FullWidthBand(
                    color: appSandBackground,
                    padding: const EdgeInsets.symmetric(vertical: 44),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(
                          'Ontdek Heemskerk',
                          linkLabel: 'Meer ontdekken',
                          linkPath: '/ontdek/kastelen',
                        ),
                        CardGrid(
                          children: [
                            for (final featured in homeFeaturedStories)
                              if (pageBySlug(featured.pageSlug)
                                  case final page?)
                                ContentCard(
                                  image: page.image,
                                  label: featured.category,
                                  title: page.title,
                                  text: page.summary,
                                  onTap: () => navigateTo(
                                    context,
                                    '/ontdek/${page.slug}',
                                  ),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  boxed([
                    const SizedBox(height: 44),
                    CallToActionBand(
                      title: 'Geheugen van Heemskerk',
                      text:
                          '${generatedMemoryStories.length} herinneringen van Heemskerkers over school, werk, straat en buurt, verdwenen plekken en feesten, opgetekend door verhalenverzamelaars.',
                      actionLabel: 'Lees de verhalen',
                      onAction: () => navigateTo(context, '/geheugen'),
                    ),
                    const SizedBox(height: 24),
                    CallToActionBand(
                      title: 'Voor basisscholen',
                      text:
                          'Rondleidingen in de kastelen, Heemskerk in oorlogstijd, wandelingen rond de school en het lesprogramma ‘Beroemd als Maerten’.',
                      actionLabel: 'Bekijk het lesaanbod',
                      onAction: () => navigateTo(context, '/educatie'),
                    ),
                    const SizedBox(height: 44),
                  ]),
                  const FullWidthBand(
                    color: appAccentBackground,
                    child: _Practical(),
                  ),
                  const SiteFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final narrow = isNarrowLayout(context);
    final images = narrow ? homeHeroImages.take(3) : homeHeroImages;
    final stripHeight = narrow ? 150.0 : 230.0;
    return ColoredBox(
      color: appGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: stripHeight,
            child: Row(
              children: [
                for (final url in images)
                  Expanded(
                    child: SiteImage(
                      url,
                      height: stripHeight,
                      width: double.infinity,
                    ),
                  ),
              ],
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: appContentMaxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  narrow ? 16 : 24,
                  narrow ? 28 : 40,
                  narrow ? 16 : 24,
                  narrow ? 32 : 44,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Semantics(
                        header: true,
                        child: Text(
                          'De geschiedenis van Heemskerk, verzameld en verteld',
                          style: TextStyle(
                            fontFamily: appSerifFont,
                            fontSize: narrow ? 28 : 40,
                            height: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Text(
                        'Lezingen, films en wandelingen, een Historisch Huis dat elke maandag open is, en ruim 18.000 foto’s, documenten, boeken en bidprentjes om zelf in te zoeken.',
                        style: TextStyle(
                          fontSize: narrow ? 16 : 18,
                          height: 1.5,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      children: [
                        _HeroButton(
                          key: const Key('home-agenda-button'),
                          label: 'Bekijk de agenda',
                          background: Colors.white,
                          foreground: appGreen,
                          onPressed: () => navigateTo(context, '/agenda'),
                        ),
                        _HeroButton(
                          key: const Key('home-search-button'),
                          label: 'Zoek in de collecties',
                          background: appAccentBackground,
                          foreground: appGreen,
                          onPressed: () => navigateTo(context, '/collecties'),
                        ),
                        _HeroButton(
                          key: const Key('home-membership-button'),
                          label: 'Word lid voor ${practicalInfo.membershipFee}',
                          background: Colors.transparent,
                          foreground: Colors.white,
                          outlined: true,
                          onPressed: () => navigateTo(context, '/lid-worden'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.outlined = false,
    super.key,
  });
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      shape: StadiumBorder(
        side: outlined
            ? const BorderSide(color: Colors.white, width: 1.5)
            : BorderSide.none,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    child: Text(label),
  );
}

/// De twee blokken 'Zoek in de collecties' en 'Onderzoek'.
class _SearchAndAsk extends StatefulWidget {
  const _SearchAndAsk({required this.questionsEnabled});
  final bool questionsEnabled;

  @override
  State<_SearchAndAsk> createState() => _SearchAndAskState();
}

class _SearchAndAskState extends State<_SearchAndAsk> {
  final _query = TextEditingController();
  final _question = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    _question.dispose();
    super.dispose();
  }

  void _search() {
    final query = _query.text.trim();
    navigateTo(
      context,
      Uri(
        path: '/zoeken',
        queryParameters: {if (query.isNotEmpty) 'q': query},
      ).toString(),
    );
  }

  void _ask() {
    final question = _question.text.trim();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(
        '/vragen',
        extra: question.isEmpty ? null : AiQuestionDraft(question),
      );
    } else {
      navigateTo(context, '/vragen');
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = _Box(
      title: 'Zoek in de collecties',
      text:
          '12.000 foto’s, 1.800 archiefstukken, 1.600 boeken, 1.300 bidprentjes, 520 Heemskring-artikelen en 760 objecten.',
      field: TextField(
        key: const Key('home-search-field'),
        controller: _query,
        onSubmitted: (_) => _search(),
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Een naam, straat, onderwerp of jaartal…',
        ),
      ),
      buttonLabel: 'Zoeken',
      buttonKey: const Key('home-search-submit'),
      onPressed: _search,
    );
    if (!widget.questionsEnabled) return search;
    final ask = _Box(
      title: 'Onderzoek',
      text:
          'Stel een onderzoeksvraag in gewone taal. Een digitale onderzoeker zoekt de bronnen in de collecties erbij en schrijft een antwoord met bronvermelding.',
      field: TextField(
        key: const Key('home-question-field'),
        controller: _question,
        onSubmitted: (_) => _ask(),
        decoration: const InputDecoration(
          hintText: 'Bijvoorbeeld: wie woonden er rond 1900 aan de Kerkweg?',
        ),
      ),
      buttonLabel: 'Vraag stellen',
      buttonKey: const Key('home-question-submit'),
      onPressed: _ask,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth <= 760
          ? Column(children: [search, const SizedBox(height: 20), ask])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: search),
                const SizedBox(width: 28),
                Expanded(child: ask),
              ],
            ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.title,
    required this.text,
    required this.field,
    required this.buttonLabel,
    required this.buttonKey,
    required this.onPressed,
  });
  final String title;
  final String text;
  final Widget field;
  final String buttonLabel;
  final Key buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: appSerifFont,
            fontSize: 24,
            color: appGreen,
          ),
        ),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(color: appMutedText, height: 1.5)),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final button = FilledButton(
              key: buttonKey,
              onPressed: onPressed,
              child: Text(buttonLabel),
            );
            if (constraints.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [field, const SizedBox(height: 10), button],
              );
            }
            return Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: 10),
                button,
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _Practical extends StatelessWidget {
  const _Practical();

  @override
  Widget build(BuildContext context) {
    Widget item(String title, String text, {String? linkLabel, String? path}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: appSerifFont,
                fontSize: 19,
                color: appGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(height: 1.5)),
            if (linkLabel != null && path != null)
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
                onPressed: () => navigateTo(context, path),
                child: Text(
                  '$linkLabel →',
                  style: const TextStyle(decoration: TextDecoration.underline),
                ),
              ),
          ],
        );
    final items = [
      item(
        'Historisch Huis',
        '${practicalInfo.address}, Heemskerk\n${practicalInfo.openingHours} open voor vragen, boeken en het inbrengen van materiaal.',
        linkLabel: 'Meer over het Historisch Huis',
        path: '/vereniging/historisch-huis',
      ),
      item(
        'Vaste momenten',
        '1e en 3e vrijdagmiddag: filmmiddag of presentatie\n4e dinsdagavond: lezing\nTweede Pinksterdag: Open Kastelendag',
        linkLabel: 'Bekijk de agenda',
        path: '/agenda',
      ),
      item(
        'Meedoen',
        'Twaalf werkgroepen en ruim honderd vrijwilligers. Kom eens langs op maandagmiddag of stuur een bericht.',
        linkLabel: 'Werkgroepen en meedoen',
        path: '/vereniging/werkgroepen',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth <= 760
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final i in items) ...[i, const SizedBox(height: 22)],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final i in items) ...[
                  Expanded(child: i),
                  const SizedBox(width: 24),
                ],
              ],
            ),
    );
  }
}
