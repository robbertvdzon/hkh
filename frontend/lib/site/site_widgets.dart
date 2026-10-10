import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../content/site_structure.dart';
import '../theme/app_style.dart';

/// Opent een route in de app via de navigatie-scope.
void navigateTo(BuildContext context, String location) {
  final navigation = AppNavigationScope.of(context);
  if (navigation != null) {
    navigation.navigate(location);
    return;
  }
  GoRouter.maybeOf(context)?.go(location);
}

/// Opent een link: interne links via de router, andere in een nieuw tabblad.
Future<void> openLink(BuildContext context, String href) async {
  final internal = internalRouteFor(href);
  if (internal != null) {
    navigateTo(context, internal);
    return;
  }
  final uri = Uri.tryParse(href);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Pagina-omlijsting: vaste header zonder titelregel, inhoud met maximale
/// breedte, en de sitevoet onderaan.
class SitePage extends StatelessWidget {
  const SitePage({
    required this.title,
    required this.children,
    this.fullWidthHeader,
    this.scrollKey,
    super.key,
  });

  /// Titel voor de browser en schermlezers; de pagina toont haar eigen kop.
  final String title;
  final List<Widget> children;

  /// Blok dat over de volle breedte boven de inhoud komt (bijv. de fotostrook).
  final Widget? fullWidthHeader;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    final narrow = isNarrowLayout(context);
    return Theme(
      data: appPageTheme(context),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: HkhAppBar(
            context: context,
            title: Text(title),
            showPageTitle: false,
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              key: scrollKey,
              padding: EdgeInsets.zero,
              children: [
                if (fullWidthHeader != null) fullWidthHeader!,
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: appContentMaxWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: narrow ? 16 : 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const SiteFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Een vlak over de volle breedte met een eigen achtergrondkleur, waarbinnen
/// de inhoud de normale maximale breedte houdt.
class FullWidthBand extends StatelessWidget {
  const FullWidthBand({
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 36),
    super.key,
  });
  final Color color;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final narrow = isNarrowLayout(context);
    return ColoredBox(
      color: color,
      child: Padding(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: appContentMaxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 24),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kop met kruimelpad en intro bovenaan een pagina.
class PageHeading extends StatelessWidget {
  const PageHeading({
    required this.title,
    this.crumbs = const [],
    this.intro,
    this.label,
    this.trailing,
    super.key,
  });
  final String title;

  /// Kruimels (label, route). De huidige pagina komt er automatisch achter.
  final List<(String, String)> crumbs;
  final String? intro;

  /// Kleine kop boven de titel, bijvoorbeeld de rubriek.
  final String? label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final narrow = isNarrowLayout(context);
    return Padding(
      padding: EdgeInsets.only(top: narrow ? 24 : 36, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Breadcrumbs(crumbs: crumbs, current: title),
          const SizedBox(height: 10),
          if (label != null) ...[
            MetaLabel(label!),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: appSerifFont,
                      fontSize: narrow ? 30 : 40,
                      height: 1.15,
                      color: appGreen,
                    ),
                  ),
                ),
              ),
              if (trailing != null && !narrow) ...[
                const SizedBox(width: 16),
                trailing!,
              ],
            ],
          ),
          if (intro != null) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Text(
                intro!,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: appMutedText,
                ),
              ),
            ),
          ],
          if (trailing != null && narrow) ...[
            const SizedBox(height: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs({required this.crumbs, required this.current, super.key});
  final List<(String, String)> crumbs;
  final String current;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 13, color: appMutedText);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: () => navigateTo(context, '/'),
          child: const Text('Home', style: style),
        ),
        for (final (label, route) in crumbs) ...[
          const Text(' › ', style: style),
          InkWell(
            onTap: () => navigateTo(context, route),
            child: Text(label, style: style),
          ),
        ],
        const Text(' › ', style: style),
        Text(current, style: style, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Kop van een blok op de homepage of een overzichtspagina, met een link rechts.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.linkLabel, this.linkPath, super.key});
  final String title;
  final String? linkLabel;
  final String? linkPath;

  @override
  Widget build(BuildContext context) {
    final heading = Semantics(
      header: true,
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: appSerifFont,
          fontSize: 28,
          color: appGreen,
        ),
      ),
    );
    final link = linkLabel != null && linkPath != null
        ? TextButton(
            onPressed: () => navigateTo(context, linkPath!),
            child: Text(
              '$linkLabel →',
              style: const TextStyle(
                decoration: TextDecoration.underline,
                fontSize: 15,
              ),
            ),
          )
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (link == null) return heading;
          // Op smalle schermen (of met grote tekst) komt de link onder de kop.
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, link],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [Expanded(child: heading), link],
          );
        },
      ),
    );
  }
}

/// Kleine kop in kapitalen boven een titel: datum, rubriek of soort.
class MetaLabel extends StatelessWidget {
  const MetaLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 12.5,
      letterSpacing: 1,
      color: appMutedText,
      height: 1.4,
    ),
  );
}

enum PillTone { normal, few, full }

/// Statuslabel: 'Nog 14 plaatsen', 'Vol · wachtlijst', 'Vrij toegankelijk'.
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {this.tone = PillTone.normal, super.key});
  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      PillTone.normal => (appAccentBackground, appGreen),
      PillTone.few => (appSandBackground, appSandForeground),
      PillTone.full => (appFullBackground, appFullForeground),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Afbeelding van de oude site. De site stuurt geen CORS-headers, daarom valt
/// de webversie terug op een gewoon img-element.
class SiteImage extends StatelessWidget {
  const SiteImage(
    this.url, {
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius,
    super.key,
  });
  final String url;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      height: height,
      width: width,
      fit: fit,
      webHtmlElementStrategy: kIsWeb
          ? WebHtmlElementStrategy.fallback
          : WebHtmlElementStrategy.never,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: width,
        color: appSandBackground,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, color: appMutedText),
      ),
    );
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

/// Kaart met foto, label, titel, korte tekst en optionele knop.
class ContentCard extends StatelessWidget {
  const ContentCard({
    required this.title,
    this.image,
    this.label,
    this.text,
    this.status,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.actionFilled = true,
    super.key,
  });
  final String title;
  final String? image;
  final String? label;
  final String? text;
  final Widget? status;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final bool actionFilled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap ?? onAction,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius,
            border: Border.all(color: appCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null)
                SiteImage(
                  image!,
                  height: 170,
                  width: double.infinity,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label != null) ...[
                      MetaLabel(label!),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: appSerifFont,
                        fontSize: 20,
                        height: 1.25,
                        color: appGreen,
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 8),
                      status!,
                    ],
                    if (text != null && text!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        text!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.45,
                          color: appMutedText,
                        ),
                      ),
                    ],
                    if (actionLabel != null) ...[
                      const SizedBox(height: 14),
                      actionFilled
                          ? FilledButton(
                              onPressed: onAction ?? onTap,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(actionLabel!),
                            )
                          : OutlinedButton(
                              onPressed: onAction ?? onTap,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(actionLabel!),
                            ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raster van kaarten: drie naast elkaar op breed, één kolom op smal.
class CardGrid extends StatelessWidget {
  const CardGrid({required this.children, this.columns = 3, super.key});
  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = constraints.maxWidth <= 620
          ? 1
          : (constraints.maxWidth <= 900 ? 2 : columns);
      const gap = 22.0;
      final width = (constraints.maxWidth - gap * (count - 1)) / count;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// Donkergroen oproepblok met titel, tekst en een knop.
class CallToActionBand extends StatelessWidget {
  const CallToActionBand({
    required this.title,
    required this.text,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });
  final String title;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final narrow = isNarrowLayout(context);
    final button = FilledButton(
      onPressed: onAction,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: appGreen,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      child: Text(actionLabel),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: appSerifFont,
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            height: 1.5,
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: appGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 18), button],
            )
          : Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 30),
                button,
              ],
            ),
    );
  }
}

/// Licht saliegroen informatieblok met kop en regels.
class InfoBox extends StatelessWidget {
  const InfoBox({required this.rows, this.title, super.key});
  final String? title;

  /// (label, waarde)
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
    decoration: BoxDecoration(
      color: appAccentBackground,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: const TextStyle(
              fontFamily: appSerifFont,
              fontSize: 20,
              color: appGreen,
            ),
          ),
          const SizedBox(height: 10),
        ],
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    label,
                    style: const TextStyle(color: appMutedText),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Sitevoet met adres, openingstijden en de belangrijkste links.
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = isNarrowLayout(context);
    Widget column(String title, List<(String, String)> links) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: appSerifFont,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        for (final (label, route) in links)
          InkWell(
            onTap: () => navigateTo(context, route),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
    final address = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HKH',
          style: TextStyle(
            fontFamily: appSerifFont,
            fontSize: 32,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Historisch Huis · ${practicalInfo.address}\n'
          '${practicalInfo.postalCode} · ${practicalInfo.phone}\n'
          '${practicalInfo.openingHours}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            for (final social in socialLinks)
              InkWell(
                onTap: () => openLink(context, social.url),
                child: Text(
                  social.name,
                  style: const TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
    final columns = [
      column('Agenda en nieuws', const [
        ('Agenda', '/agenda'),
        ('Nieuws', '/nieuws'),
        ('Nieuwsbrieven', '/nieuws/nieuwsbrieven'),
        ('Heemskring', '/nieuws/heemskring'),
      ]),
      column('Ontdekken', const [
        ('Kastelen', '/ontdek/kastelen'),
        ('Geheugen van Heemskerk', '/geheugen'),
        ('Zoeken in de collecties', '/collecties'),
        ('Uitgebreid zoeken', '/zoeken'),
      ]),
      column('Vereniging', const [
        ('Over de HKH', '/vereniging/over-de-hkh'),
        ('Lid worden', '/lid-worden'),
        ('Werkgroepen en meedoen', '/vereniging/werkgroepen'),
        ('Contact', '/vereniging/contact'),
        ('Privacy · Disclaimer · ANBI', '/vereniging/anbi'),
      ]),
    ];
    return FullWidthBand(
      color: appHeaderBackground,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                address,
                for (final c in columns) ...[const SizedBox(height: 24), c],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: address),
                for (final c in columns) Expanded(flex: 4, child: c),
              ],
            ),
    );
  }
}

/// Melding dat een formulier in deze fase nog niets bewaart.
class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: appSandBackground,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      children: [
        Icon(Icons.science_outlined, size: 18, color: appSandForeground),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Voorbeeld: dit formulier bewaart in deze versie nog niets.',
            style: TextStyle(fontSize: 12.5, color: appSandForeground),
          ),
        ),
      ],
    ),
  );
}
