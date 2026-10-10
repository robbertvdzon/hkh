import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../content/site_structure.dart';
import 'app_style.dart';

/// De hoofdnavigatie en accountbediening zijn op iedere pagina beschikbaar.
class AppNavigationScope extends InheritedWidget {
  const AppNavigationScope({
    required this.navigate,
    required this.location,
    required this.accountBuilder,
    required super.child,
    this.questionsEnabled = true,
    super.key,
  });

  /// Opent een route in de app, bijvoorbeeld `/agenda`.
  final void Function(String location) navigate;
  final String location;
  final WidgetBuilder accountBuilder;

  /// Zonder AI-bron ontbreekt 'Onderzoek' in het menu.
  final bool questionsEnabled;

  static AppNavigationScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppNavigationScope>();

  @override
  bool updateShouldNotify(AppNavigationScope oldWidget) =>
      location != oldWidget.location ||
      navigate != oldWidget.navigate ||
      questionsEnabled != oldWidget.questionsEnabled ||
      accountBuilder != oldWidget.accountBuilder;
}

/// Vaste merkheader met hoofdmenu; paginatitel en acties staan eronder.
///
/// Breed: merkregel (logo, naam, zoekveld, Lid worden, account) en een
/// menuregel met de zes hoofdingangen. Smal: merkregel met Lid worden en een
/// menuknop die de ingangen in een paneel toont.
class HkhAppBar extends StatelessWidget implements PreferredSizeWidget {
  HkhAppBar({
    required BuildContext context,
    required this.title,
    this.actions,
    this.onBack,
    this.backLabel = 'Terug',
    this.bottom,
    this.accountAction,
    this.showPageTitle = true,
    super.key,
  }) : _layout = HeaderLayout(
         context,
         subMenu: subMenuFor(AppNavigationScope.of(context)?.location ?? ''),
       );

  final Widget title;
  final VoidCallback? onBack;
  final String backLabel;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? accountAction;
  final bool showPageTitle;
  final HeaderLayout _layout;

  @override
  Size get preferredSize => Size.fromHeight(
    _layout.brandHeight +
        _layout.menuHeight +
        _layout.subMenuHeight +
        (showPageTitle ? 56 : 0) +
        (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final navigation = AppNavigationScope.of(context);
    final path = navigation?.location ?? '';
    final account = accountAction ?? navigation?.accountBuilder(context);
    void go(String location) {
      if (navigation != null) {
        navigation.navigate(location);
      } else {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    }

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
                            onTap: () => go('/'),
                            child: ExcludeSemantics(child: _brand()),
                          ),
                        ),
                      ),
                      if (_layout.showSearchField) ...[
                        const SizedBox(width: 16),
                        _HeaderSearchField(onSearch: go),
                      ],
                      if (!_layout.compactBrand) ...[
                        const SizedBox(width: 12),
                        _MembershipButton(
                          compact: _layout.narrow,
                          onPressed: () => go('/lid-worden'),
                        ),
                      ],
                      if (account != null) ...[
                        const SizedBox(width: 12),
                        SizedBox(width: 44, child: account),
                      ],
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
                      child: _layout.narrow
                          ? _MenuButton(
                              layout: _layout,
                              path: path,
                              questionsEnabled:
                                  navigation?.questionsEnabled ?? true,
                              navigate: go,
                            )
                          : Wrap(
                              children: [
                                for (final item in mainMenu)
                                  _NavigationButton(
                                    layout: _layout,
                                    label: item.label,
                                    keyName: 'menu-${item.path.substring(1)}',
                                    selected: isMenuPathActive(
                                      item.path,
                                      path,
                                    ),
                                    onPressed: () =>
                                        go(menuTargetFor(item.path)),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              if (_layout.subMenu.isNotEmpty)
                ColoredBox(
                  color: appSubMenuBackground,
                  child: SizedBox(
                    width: double.infinity,
                    height: _layout.subMenuHeight,
                    child: _HeaderContent(
                      padding: _layout.horizontal - _layout.menuPadding,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          key: const Key('submenu-bar'),
                          children: [
                            for (final item in _layout.subMenu)
                              _SubNavigationButton(
                                layout: _layout,
                                label: item.label,
                                keyName:
                                    'submenu-${item.path.substring(1).replaceAll('/', '-')}',
                                selected:
                                    activeSubMenuPath(path) == item.path,
                                onPressed: () => go(item.path),
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
                                  if (onBack != null ||
                                      Navigator.of(context).canPop()) ...[
                                    if (onBack != null)
                                      IconButton(
                                        tooltip: backLabel,
                                        onPressed: onBack,
                                        icon: const BackButtonIcon(),
                                        color: appGreen,
                                      )
                                    else
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
              Text(
                siteName,
                style: _layout.nameStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                siteTagline.toUpperCase(),
                style: _layout.taglineStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Of een menu-ingang als actief telt voor de huidige route.
bool isMenuPathActive(String menuPath, String currentPath) =>
    isMainMenuPathActive(menuPath, currentPath);

/// Knop in de submenubalk: lichter van toon, actieve knop vet met streep.
class _SubNavigationButton extends StatelessWidget {
  const _SubNavigationButton({
    required this.layout,
    required this.label,
    required this.keyName,
    required this.selected,
    required this.onPressed,
  });
  final HeaderLayout layout;
  final String label;
  final String keyName;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TextButton(
      key: Key(keyName),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: appGreen,
        minimumSize: Size(40, layout.subMenuRowHeight),
        padding: EdgeInsets.symmetric(horizontal: layout.menuPadding),
        shape: const RoundedRectangleBorder(),
        textStyle: layout.subMenuStyle.copyWith(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Container(
        height: layout.subMenuRowHeight,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? appGreen : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(widthFactor: 1, child: Text(label)),
      ),
    ),
  );
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.layout,
    required this.label,
    required this.keyName,
    required this.selected,
    required this.onPressed,
  });
  final HeaderLayout layout;
  final String label;
  final String keyName;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TextButton(
      key: Key(keyName),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: appHeaderForeground,
        minimumSize: Size(48, layout.menuRowHeight),
        padding: EdgeInsets.symmetric(horizontal: layout.menuPadding),
        shape: const RoundedRectangleBorder(),
        textStyle: layout.menuStyle,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Container(
        height: layout.menuRowHeight,
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
}

/// Op smalle schermen: één knop die het hoofdmenu in een paneel opent.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.layout,
    required this.path,
    required this.questionsEnabled,
    required this.navigate,
  });
  final HeaderLayout layout;
  final String path;
  final bool questionsEnabled;
  final void Function(String) navigate;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const Key('menu-toggle'),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      backgroundColor: appBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final item in mainMenu)
              ListTile(
                key: Key('menu-${item.path.substring(1)}'),
                title: Text(item.label),
                selected: isMenuPathActive(item.path, path),
                selectedColor: appGreen,
                onTap: () {
                  Navigator.of(sheet).pop();
                  navigate(menuTargetFor(item.path));
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Zoeken in de collecties'),
              onTap: () {
                Navigator.of(sheet).pop();
                navigate('/collecties');
              },
            ),
            ListTile(
              leading: const Icon(Icons.card_membership_outlined),
              title: const Text('Lid worden'),
              onTap: () {
                Navigator.of(sheet).pop();
                navigate('/lid-worden');
              },
            ),
          ],
        ),
      ),
    ),
    style: TextButton.styleFrom(
      foregroundColor: appHeaderForeground,
      minimumSize: Size(48, layout.menuRowHeight),
      padding: EdgeInsets.symmetric(horizontal: layout.menuPadding),
      textStyle: layout.menuStyle,
    ),
    icon: const Icon(Icons.menu, size: 22),
    label: const Text('Menu'),
  );
}

class _MembershipButton extends StatelessWidget {
  const _MembershipButton({required this.compact, required this.onPressed});
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    key: const Key('membership-action'),
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: appHeaderBackground,
      minimumSize: Size(0, compact ? 40 : 44),
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
      textStyle: TextStyle(
        fontSize: compact ? 13 : 15,
        fontWeight: FontWeight.w600,
      ),
      shape: const StadiumBorder(),
    ),
    child: const Text('Lid worden'),
  );
}

/// Compact zoekvak in de merkregel; opent de zoekpagina, waar het echte
/// zoekveld staat. Bewust geen TextField: zo blijft de header licht en zonder
/// eigen scrollgebied.
class _HeaderSearchField extends StatelessWidget {
  const _HeaderSearchField({required this.onSearch});
  final void Function(String location) onSearch;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Zoek in de collecties',
    child: InkWell(
      key: const Key('header-search-field'),
      onTap: () => onSearch('/collecties'),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 300,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: appHeaderForeground.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: appHeaderForeground, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Zoek in de collecties…',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: appHeaderForeground.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
class HeaderLayout {
  HeaderLayout(
    BuildContext context, {
    this.subMenu = const [],
  }) {
    final width = math.min(MediaQuery.sizeOf(context).width, 1160.0);
    narrow = width <= 900;
    final tiny = width <= 350;
    showSearchField = width >= 1000;
    horizontal = narrow ? 18 : 28;
    logoWidth = tiny ? 64 : (narrow ? 80 : 108);
    brandGap = narrow ? 12 : 20;
    menuPadding = narrow ? 10 : 14;
    nameStyle = TextStyle(
      fontFamily: appSerifFont,
      color: appHeaderForeground,
      fontSize: tiny ? 15 : (narrow ? 17 : 22),
      height: 1.25,
    );
    taglineStyle = TextStyle(
      color: const Color(0xFFC4D0C8),
      fontSize: narrow ? 9 : 11,
      height: 1.5,
      letterSpacing: narrow ? 1.0 : 1.8,
    );
    menuStyle = TextStyle(
      fontSize: narrow ? 14 : 15,
      height: 1.4,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
    );
    subMenuStyle = TextStyle(fontSize: narrow ? 13.5 : 14.5, height: 1.4);
    final scaler = MediaQuery.textScalerOf(context);
    // Op een smal scherm met grote tekst, of op een kleine telefoon, blijft
    // alleen het logo over; 'Lid worden' zit dan in het menupaneel.
    compactBrand = narrow && (scaler.scale(16) > 20 || width < 420);
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

    // Ruimte rechts van de naam: zoekveld, Lid worden en account.
    final rightWidth =
        (showSearchField ? 316.0 : 0.0) + (narrow ? 100.0 : 140.0) + 56;
    final nameWidth = math.max(
      1.0,
      width -
          2 * horizontal -
          rightWidth -
          (compactBrand ? 0 : logoWidth + brandGap),
    );
    final name = measure(siteName, nameStyle, nameWidth);
    final tagline = measure(siteTagline.toUpperCase(), taglineStyle, nameWidth);
    brandHeight = compactBrand
        ? 72
        : math.max(narrow ? 84 : 112, name.height + 6 + tagline.height + 36);
    menuRowHeight = math.max(50, scaler.scale(menuStyle.fontSize!) * 1.4 + 24);
    subMenuRowHeight = math.max(
      42,
      scaler.scale(subMenuStyle.fontSize!) * 1.4 + 18,
    );
    final menuWidth = width - 2 * (horizontal - menuPadding);
    int rowsFor(List<String> labels, TextStyle style) {
      var rows = 1;
      var used = 0.0;
      for (final label in labels) {
        final itemWidth =
            measure(label, style, double.infinity).width + 2 * menuPadding;
        if (used > 0 && used + itemWidth > menuWidth) {
          rows++;
          used = 0;
        }
        used += itemWidth;
      }
      return rows;
    }

    menuHeight = narrow
        ? menuRowHeight
        : rowsFor([for (final i in mainMenu) i.label], menuStyle) *
              menuRowHeight;
    subMenuHeight = subMenu.isEmpty
        ? 0
        : rowsFor([for (final i in subMenu) i.label], subMenuStyle) *
              subMenuRowHeight;
  }

  /// Subitems van het onderdeel waarin de bezoeker zich bevindt.
  final List<({String label, String path})> subMenu;

  late final bool narrow, compactBrand, showSearchField;
  late final double horizontal, logoWidth, brandGap, menuPadding;
  late final double brandHeight, menuRowHeight, menuHeight;
  late final double subMenuRowHeight, subMenuHeight;
  late final TextStyle nameStyle, taglineStyle, menuStyle, subMenuStyle;
}
