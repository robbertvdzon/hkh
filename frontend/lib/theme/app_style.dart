import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gedeelde vormgeving van de publieke app: de homepage en de dossierschermen
/// en -dialogen gebruiken dezelfde kleuren, afrondingen en verticale ritmiek.
const appBackground = Color(0xFFFBF6EE);
const appGreen = Color(0xFF1F3B2E);
const appAccentBackground = Color(0xFFDCE9DA);
const appCardBorder = Color(0xFFD9CFBB);
const appControlBorder = Color(0xFF647566);
const appMutedText = Color(0xFF5A6A5C);
const appErrorBackground = Color(0xFFFBE9E7);
const appErrorForeground = Color(0xFF9F201B);

/// Kaarten zijn 16px afgerond, velden en knoppen 10px.
const appCardRadius = 16.0;
const appControlRadius = 10.0;

/// Minimale verticale ruimte tussen twee inhoudelijke secties.
const appSectionGap = 32.0;

/// Tot en met deze breedte gelden de smalle (gestapelde) varianten.
const appNarrowWidth = 600.0;

/// Achtergrond- en tekstkleur van de rolchips.
const appRoleOwnerBackground = Color(0xFFDCE9DA);
const appRoleOwnerForeground = Color(0xFF1F3B2E);
const appRoleEditorBackground = Color(0xFFF0E6D2);
const appRoleEditorForeground = Color(0xFF6B4A21);
const appRoleResearcherBackground = Color(0xFFD9ECE7);
const appRoleResearcherForeground = Color(0xFF17352F);
const appRoleReaderBackground = Color(0xFFECE8DD);
const appRoleReaderForeground = Color(0xFF4A4740);

/// True zodra het venster smal genoeg is voor de gestapelde varianten.
bool isNarrowLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width <= appNarrowWidth;

/// Velden, knoppen en accentkleur zoals op de homepage.
ThemeData appSurfaceTheme(BuildContext context) {
  final base = Theme.of(context);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(appControlRadius),
    borderSide: const BorderSide(color: appControlBorder),
  );
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: appGreen,
      onPrimary: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(appControlRadius),
        borderSide: const BorderSide(color: appGreen, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: appGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appControlRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: appGreen,
        side: const BorderSide(color: appGreen),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appControlRadius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: appGreen,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appControlRadius),
        ),
      ),
    ),
  );
}

/// De vormgeving van de homepage, aangevuld met de kaart-, balk- en
/// tabbladstijl van de dossierschermen en -dialogen.
ThemeData appDossierTheme(BuildContext context) {
  final base = appSurfaceTheme(context);
  return base.copyWith(
    scaffoldBackgroundColor: appBackground,
    appBarTheme: appHeaderTheme,
    tabBarTheme: const TabBarThemeData(
      labelColor: appGreen,
      unselectedLabelColor: appMutedText,
      indicatorColor: appGreen,
      dividerColor: appCardBorder,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appCardRadius),
        side: const BorderSide(color: appCardBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(color: appCardBorder),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appControlRadius),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: appGreen,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appControlRadius),
      ),
    ),
  );
}

/// Zijmarge van een dialoog: op smalle schermen mag de dialoog de volle
/// beschikbare breedte binnen de normale schermmarges gebruiken.
EdgeInsets appDialogInsetPadding(BuildContext context) => EdgeInsets.symmetric(
  horizontal: isNarrowLayout(context) ? 16 : 40,
  vertical: 24,
);

/// Breedte van de dialooginhoud: [maxWidth] op brede schermen, en anders wat er
/// binnen de marges en de inhoudsruimte van de dialoog past.
double appDialogContentWidth(BuildContext context, {double maxWidth = 480}) {
  final inset = appDialogInsetPadding(context).horizontal;
  // De horizontale contentPadding van een AlertDialog is 24 links en rechts.
  final available = MediaQuery.sizeOf(context).width - inset - 48;
  return math.max(0, math.min(maxWidth, available));
}

/// Dialoog in de gedeelde vormgeving: witte kaart met 16px afronding, groene
/// titel, en op smalle schermen de volle beschikbare breedte. De inhoud scrollt
/// zodat ook bij 200% tekstschaling alles bereikbaar blijft.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.content,
    required this.actions,
    this.maxWidth = 480,
    super.key,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = appDossierTheme(context);
    return Theme(
      data: theme,
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: appDialogInsetPadding(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appCardRadius),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: appGreen,
          fontWeight: FontWeight.w700,
        ),
        title: Text(title),
        scrollable: true,
        content: SizedBox(
          key: const Key('app-dialog-content'),
          width: appDialogContentWidth(context, maxWidth: maxWidth),
          child: content,
        ),
        actions: actions,
      ),
    );
  }
}

/// Neutrale kaart: wit met een dunne rand en 16px afronding.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(appCardRadius);
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        // Zonder onTap blijft de kaart een gewoon vlak met rand.
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
            border: Border.all(color: appCardBorder),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// The same heritage-green masthead on every page, including scrolled pages.
const appHeaderTheme = AppBarTheme(
  backgroundColor: appGreen,
  foregroundColor: appBackground,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  scrolledUnderElevation: 0,
  toolbarHeight: 72,
  titleTextStyle: TextStyle(
    color: appBackground,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  ),
  shape: Border(bottom: BorderSide(color: Color(0xFFC5A66B), width: 3)),
);

class HkhAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HkhAppBar({required this.title, this.actions, this.bottom, super.key});
  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  @override
  Size get preferredSize =>
      Size.fromHeight(72 + (bottom?.preferredSize.height ?? 0));
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(appBarTheme: appHeaderTheme),
    child: AppBar(
      title: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFC5A66B)),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                'HKH',
                style: TextStyle(
                  color: appBackground,
                  fontFamily: 'Georgia',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: title,
            ),
          ),
        ],
      ),
      actions: actions,
      bottom: bottom,
    ),
  );
}

class InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const InstantPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
