import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'auth/account_action.dart';
import 'auth/google_signin_button_stub.dart'
    if (dart.library.html) 'auth/google_signin_button_web.dart'
    as google_button;
import 'auth/user_session.dart';
import 'backend/backend_client.dart';
import 'ai_search/ai_search.dart';
import 'ai_search/answer_source_dialog.dart';
import 'collection/collection_search.dart';
import 'navigation.dart';
import 'config/app_config.dart';
import 'self_update_prompt.dart';
import 'theme/app_style.dart';

export 'site/home_page.dart' show HomePage;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final UserSessionController session = GoogleUserSession(
    apiBaseUrl: AppConfig.apiBaseUrl,
    googleClientId: AppConfig.googleClientId,
  );
  final backend = BackendClient(
    AppConfig.apiBaseUrl,
    tokenProvider: () => session.token,
    // Een 401 op een privéroute betekent een verlopen of ingetrokken sessie.
    onUnauthorized: () => unawaited(session.signOut()),
  );
  // Niet blokkerend: de app start anoniem en toont de sessie zodra die hersteld is.
  unawaited(session.bootstrap());
  runApp(
    HkhApp(
      searchSource: backend,
      aiSearchSource: backend,
      pdfSource: backend,
      session: session,
    ),
  );
}

class HkhApp extends StatefulWidget {
  const HkhApp({
    required this.searchSource,
    this.aiSearchSource,
    this.pdfSource,
    this.session,
    this.googleButtonBuilder,
    this.now,
    super.key,
  });

  final CollectionSearchSource searchSource;
  final AiSearchSource? aiSearchSource;

  /// Zonder pdf-bron ontbreekt de exportactie op het AI-antwoordscherm.
  final AiAnswerPdfSource? pdfSource;

  /// Optionele login; zonder controller draait de app anoniem (zoals in tests).
  final UserSessionController? session;
  final Widget Function()? googleButtonBuilder;

  /// Peilmoment voor de agenda; standaard de huidige tijd.
  final DateTime? now;

  @override
  State<HkhApp> createState() => _HkhAppState();
}

class _HkhAppState extends State<HkhApp> {
  late final _router = createAppRouter(
    searchSource: widget.searchSource,
    aiSearchSource: widget.aiSearchSource,
    pdfSource: widget.pdfSource,
    session: widget.session,
    googleButtonBuilder:
        widget.googleButtonBuilder ?? google_button.renderGoogleButton,
    now: widget.now,
  );

  String? _syncedToken;
  String? _shownError;

  @override
  void initState() {
    super.initState();
    widget.session?.addListener(_onAccountChanged);
    _onAccountChanged();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _router.routerDelegate.navigatorKey.currentContext;
        if (context != null && context.mounted) maybePromptSelfUpdate(context);
      });
    }
  }

  void _onAccountChanged() {
    final session = widget.session;
    final token = session?.token;
    if (token != _syncedToken) {
      _syncedToken = token;
      final source = widget.aiSearchSource;
      if (token != null && source is AiSearchAccountSource) {
        // Ook vanaf de homepage meteen koppelen. Elke ingelogde AI-aanvraag
        // herhaalt dit idempotent als de verbinding hier tijdelijk wegvalt.
        unawaited(
          (source as AiSearchAccountSource).syncAiSearchAccount().catchError((
            Object error,
          ) {
            debugPrint(
              'Vragen koppelen wordt bij de volgende aanvraag herhaald.',
            );
          }),
        );
      }
    }
    final error = session?.error;
    if (error == null) {
      _shownError = null;
    } else if (error != _shownError) {
      _shownError = error;
      final context = _router.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  void dispose() {
    widget.session?.removeListener(_onAccountChanged);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Historische Kring Heemskerk',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: appGreen,
      ).copyWith(surface: appBackground),
      useMaterial3: true,
      scaffoldBackgroundColor: appBackground,
      appBarTheme: appHeaderTheme,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const InstantPageTransitionsBuilder(),
        },
      ),
    ),
    builder: (context, child) => ListenableBuilder(
      listenable: _router.routeInformationProvider,
      builder: (context, _) => AppNavigationScope(
        navigate: _router.go,
        questionsEnabled: widget.aiSearchSource != null,
        location: _router.routeInformationProvider.value.uri.path,
        accountBuilder: (context) => AccountAction(
          session: widget.session ?? DisabledUserSession(),
          googleButtonBuilder: widget.googleButtonBuilder,
        ),
        // Alle tekst op de site is te selecteren en te kopiëren.
        child: AnswerSourceScope(source: widget.searchSource, child: child!),
      ),
    ),
    routerConfig: _router,
  );
}
