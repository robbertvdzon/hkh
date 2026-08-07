import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'auth/admin_session.dart';
import 'config/app_config.dart';
import 'google_signin_button_stub.dart'
    if (dart.library.html) 'google_signin_button_web.dart'
    as google_button;

void main() {
  final sessionSource = AppConfig.previewMode
      ? PreviewAdminSessionSource(apiBaseUrl: AppConfig.apiBaseUrl)
      : AppConfig.googleClientId.isEmpty
      ? const DisabledAdminSessionSource()
      : AdminSessionService(
          apiBaseUrl: AppConfig.apiBaseUrl,
          googleClientId: AppConfig.googleClientId,
        );
  runApp(HkhAdminApp(sessionSource: sessionSource));
}

class HkhAdminApp extends StatelessWidget {
  const HkhAdminApp({
    required this.sessionSource,
    this.googleButtonBuilder,
    super.key,
  });

  final AdminSessionSource sessionSource;
  final Widget Function()? googleButtonBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HKH Beheer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF594A78)),
        useMaterial3: true,
      ),
      home: AdminGate(
        sessionSource: sessionSource,
        googleButtonBuilder:
            googleButtonBuilder ?? google_button.renderGoogleButton,
      ),
    );
  }
}

class AdminGate extends StatefulWidget {
  const AdminGate({
    required this.sessionSource,
    required this.googleButtonBuilder,
    super.key,
  });

  final AdminSessionSource sessionSource;
  final Widget Function() googleButtonBuilder;

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  StreamSubscription<AdminIdentity>? _subscription;
  AdminIdentity? _identity;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _subscription = widget.sessionSource.identities.listen(
      _authenticated,
      onError: _failed,
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!widget.sessionSource.configured) {
      setState(() => _busy = false);
      return;
    }
    try {
      final identity = await widget.sessionSource.bootstrap();
      if (identity != null) _authenticated(identity);
      if (mounted) setState(() => _busy = false);
    } catch (error) {
      _failed(error);
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final identity = await widget.sessionSource.signIn();
      if (identity != null) _authenticated(identity);
      if (mounted) setState(() => _busy = false);
    } catch (error) {
      _failed(error);
    }
  }

  Future<void> _signOut() async {
    await widget.sessionSource.signOut();
    if (mounted) setState(() => _identity = null);
  }

  void _authenticated(AdminIdentity identity) {
    if (!mounted) return;
    setState(() {
      _identity = identity;
      _busy = false;
      _error = null;
    });
  }

  void _failed(Object error) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = 'Inloggen mislukt. Controleer je HKH-beheeraccount.';
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    widget.sessionSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final identity = _identity;
    if (identity != null) {
      return _AdminHome(identity: identity, onSignOut: _signOut);
    }
    return _LoginScreen(
      configured: widget.sessionSource.configured,
      error: _error,
      onSignIn: _signIn,
      googleButtonBuilder: widget.googleButtonBuilder,
    );
  }
}

class _LoginScreen extends StatelessWidget {
  const _LoginScreen({
    required this.configured,
    required this.error,
    required this.onSignIn,
    required this.googleButtonBuilder,
  });

  final bool configured;
  final String? error;
  final VoidCallback onSignIn;
  final Widget Function() googleButtonBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 60),
                const SizedBox(height: 16),
                Text(
                  'HKH Beheer',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  configured
                      ? 'Log in met een toegestaan Google-account.'
                      : 'Google-login is nog niet geconfigureerd.',
                  textAlign: TextAlign.center,
                ),
                if (configured) ...[
                  const SizedBox(height: 24),
                  if (kIsWeb)
                    SizedBox(height: 40, child: googleButtonBuilder())
                  else
                    FilledButton.icon(
                      onPressed: onSignIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Inloggen met Google'),
                    ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome({required this.identity, required this.onSignOut});

  final AdminIdentity identity;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HKH Beheer'),
        actions: [
          IconButton(
            onPressed: onSignOut,
            tooltip: 'Uitloggen',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Beheerder geverifieerd',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(identity.email),
              const SizedBox(height: 20),
              const Text(
                'Inhoudelijk beheer wordt in een volgende productiteratie toegevoegd.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
