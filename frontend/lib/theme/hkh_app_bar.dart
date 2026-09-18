import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_style.dart';

/// De hoofdnavigatie en accountbediening zijn op iedere pagina beschikbaar.
class AppNavigationScope extends InheritedWidget {
  const AppNavigationScope({
    required this.onOpenHome,
    required this.onOpenSearch,
    required this.onOpenQuestions,
    required this.onOpenDossiers,
    required this.location,
    required this.accountBuilder,
    required super.child,
    super.key,
  });

  final VoidCallback onOpenHome;
  final VoidCallback onOpenSearch;
  final VoidCallback? onOpenQuestions;
  final VoidCallback? onOpenDossiers;
  final String location;
  final WidgetBuilder accountBuilder;

  static AppNavigationScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppNavigationScope>();

  @override
  bool updateShouldNotify(AppNavigationScope oldWidget) =>
      location != oldWidget.location ||
      onOpenHome != oldWidget.onOpenHome ||
      onOpenSearch != oldWidget.onOpenSearch ||
      onOpenQuestions != oldWidget.onOpenQuestions ||
      onOpenDossiers != oldWidget.onOpenDossiers ||
      accountBuilder != oldWidget.accountBuilder;
}

/// Vaste merkheader met hoofdnavigatie; paginatitel en acties staan eronder.
class HkhAppBar extends StatelessWidget implements PreferredSizeWidget {
  HkhAppBar({
    required BuildContext context,
    required this.title,
    this.actions,
    this.bottom,
    this.accountAction,
    this.showPageTitle = true,
    super.key,
  }) : _layout = _HeaderLayout(context);

  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? accountAction;
  final bool showPageTitle;
  final _HeaderLayout _layout;

  @override
  Size get preferredSize => Size.fromHeight(
    _layout.brandHeight +
        _layout.menuHeight +
        (showPageTitle ? 56 : 0) +
        (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final navigation = AppNavigationScope.of(context);
    final path = navigation?.location ?? '';
    final account = accountAction ?? navigation?.accountBuilder(context);
    Widget navigationButton(
      String label,
      String key,
      VoidCallback? onPressed,
      bool selected,
    ) => Semantics(
      selected: selected,
      child: TextButton(
        key: Key(key),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: appHeaderForeground,
          disabledForegroundColor: appHeaderForeground,
          minimumSize: Size(48, _layout.menuRowHeight),
          padding: EdgeInsets.symmetric(horizontal: _layout.menuPadding),
          shape: const RoundedRectangleBorder(),
          textStyle: _layout.menuStyle,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Container(
          height: _layout.menuRowHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? appHeaderAccent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(widthFactor: 1, child: Text(label)),
        ),
      ),
    );

    return Theme(
      data: Theme.of(context).copyWith(appBarTheme: appHeaderTheme),
      child: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
        bottom: PreferredSize(
          preferredSize: preferredSize,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _layout.brandHeight,
                child: _HeaderContent(
                  padding: _layout.horizontal,
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label:
                              'Historische Kring Heemskerk, naar de homepage',
                          child: InkWell(
                            key: const Key('hkh-home'),
                            onTap:
                                navigation?.onOpenHome ??
                                () => Navigator.of(
                                  context,
                                ).popUntil((r) => r.isFirst),
                            child: ExcludeSemantics(child: _brand()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(width: 44, child: account),
                    ],
                  ),
                ),
              ),
              ColoredBox(
                color: appMenuBackground,
                child: SizedBox(
                  width: double.infinity,
                  height: _layout.menuHeight,
                  child: _HeaderContent(
                    padding: _layout.horizontal - _layout.menuPadding,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        children: [
                          navigationButton(
                            'Vraag het archief',
                            'questions-action',
                            navigation?.onOpenQuestions,
                            path.startsWith('/vragen'),
                          ),
                          navigationButton(
                            'Zoeken',
                            'search-action',
                            navigation?.onOpenSearch,
                            path.startsWith('/zoeken') ||
                                path.startsWith('/objecten'),
                          ),
                          navigationButton(
                            'Mijn dossiers',
                            'dossiers-action',
                            navigation?.onOpenDossiers,
                            path.startsWith('/dossiers') ||
                                path.startsWith('/artikelen'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (showPageTitle || bottom != null)
                Theme(
                  data: Theme.of(context).copyWith(
                    iconTheme: const IconThemeData(color: appGreen),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(foregroundColor: appGreen),
                    ),
                  ),
                  child: ColoredBox(
                    color: appBackground,
                    child: Column(
                      children: [
                        if (showPageTitle)
                          SizedBox(
                            height: 56,
                            child: _HeaderContent(
                              padding: _layout.horizontal,
                              child: Row(
                                children: [
                                  if (Navigator.of(context).canPop()) ...[
                                    const BackButton(color: appGreen),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: DefaultTextStyle(
                                      style: const TextStyle(
                                        fontSize: 20,
                                        color: appGreen,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      child: Semantics(
                                        header: true,
                                        child: title,
                                      ),
                                    ),
                                  ),
                                  ...?actions,
                                ],
                              ),
                            ),
                          ),
                        if (bottom != null) bottom!,
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    final logo = Image.asset(
      'assets/branding/hkh-logo.png',
      width: _layout.logoWidth,
      filterQuality: FilterQuality.high,
    );
    final name = Text('Historische Kring Heemskerk', style: _layout.nameStyle);
    if (_layout.compactBrand) {
      return Align(alignment: Alignment.centerLeft, child: logo);
    }
    return Row(
      children: [
        logo,
        SizedBox(width: _layout.brandGap),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              name,
              const SizedBox(height: 9),
              Text('HET GEHEUGEN VAN HEEMSKERK', style: _layout.taglineStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({required this.padding, required this.child});
  final double padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1160),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: child,
      ),
    ),
  );
}

/// Meet de merknaam en menuregels ook bij vergrote tekst, zodat de vaste
/// Scaffold-header precies genoeg ruimte reserveert zonder verborgen links.
class _HeaderLayout {
  _HeaderLayout(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width, 1160.0);
    final narrow = width <= 600;
    final tiny = width <= 350;
    horizontal = narrow ? 18 : 28;
    logoWidth = tiny ? 70 : (narrow ? 88 : 116);
    brandGap = narrow ? 14 : 24;
    menuPadding = narrow ? 10 : 14;
    nameStyle = TextStyle(
      fontFamily: 'HkhSerif',
      color: appHeaderForeground,
      fontSize: tiny ? 16 : (narrow ? 19 : 22),
      height: 1.25,
    );
    taglineStyle = TextStyle(
      color: const Color(0xFFC4D0D2),
      fontSize: 11,
      height: 1.5,
      letterSpacing: narrow ? 0.3 : 1.6,
    );
    menuStyle = TextStyle(
      fontSize: narrow ? 13 : 14,
      height: 1.4,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
    );
    final scaler = MediaQuery.textScalerOf(context);
    compactBrand = narrow && scaler.scale(16) > 21;
    Size measure(String text, TextStyle style, double maxWidth) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: maxWidth);
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final nameWidth = math.max(
      1.0,
      width - 2 * horizontal - 60 - (compactBrand ? 0 : logoWidth + brandGap),
    );
    final name = measure('Historische Kring Heemskerk', nameStyle, nameWidth);
    final tagline = measure(
      'HET GEHEUGEN VAN HEEMSKERK',
      taglineStyle,
      nameWidth,
    );
    // Bij sterke tekstvergroting vervangt het originele logo de volledige
    // verenigingsnaam. Zo blijft er ook op een kleine telefoon ruimte voor de inhoud.
    brandHeight = compactBrand
        ? 72
        : math.max(112, name.height + 9 + tagline.height + 40);
    menuRowHeight = math.max(50, scaler.scale(menuStyle.fontSize!) * 1.4 + 24);
    final menuWidth = width - 2 * (horizontal - menuPadding);
    var rows = 1;
    var used = 0.0;
    for (final label in ['Vraag het archief', 'Zoeken', 'Mijn dossiers']) {
      final itemWidth =
          measure(label, menuStyle, double.infinity).width + 2 * menuPadding;
      if (used > 0 && used + itemWidth > menuWidth) {
        rows++;
        used = 0;
      }
      used += itemWidth;
    }
    menuHeight = rows * menuRowHeight;
  }

  late final bool compactBrand;
  late final double horizontal, logoWidth, brandGap, menuPadding;
  late final double brandHeight, menuRowHeight, menuHeight;
  late final TextStyle nameStyle, taglineStyle, menuStyle;
}
