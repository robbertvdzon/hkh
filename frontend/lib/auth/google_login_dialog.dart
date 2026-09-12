import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'google_signin_button_stub.dart'
    if (dart.library.html) 'google_signin_button_web.dart'
    as google_button;
import 'user_session.dart';

/// Start de login: op web via een dialoog met de officiële Google-knop, elders via de
/// native Google-flow van de sessiecontroller.
Future<void> startSignIn(
  BuildContext context,
  UserSessionController session, {
  Widget Function()? googleButtonBuilder,
}) async {
  if (kIsWeb) {
    await showDialog<void>(
      context: context,
      builder: (_) => GoogleLoginDialog(
        session: session,
        googleButtonBuilder:
            googleButtonBuilder ?? google_button.renderGoogleButton,
      ),
    );
    return;
  }
  await session.signIn();
}

/// Webdialoog met de officiële Google-knop; sluit zichzelf zodra de login rond is.
class GoogleLoginDialog extends StatefulWidget {
  const GoogleLoginDialog({
    required this.session,
    required this.googleButtonBuilder,
    super.key,
  });

  final UserSessionController session;
  final Widget Function() googleButtonBuilder;

  @override
  State<GoogleLoginDialog> createState() => _GoogleLoginDialogState();
}

class _GoogleLoginDialogState extends State<GoogleLoginDialog> {
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted && widget.session.signedIn) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Inloggen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Log in met je Google-account om onderzoeksdossiers te bewaren. '
            'Zonder account kun je de app gewoon blijven gebruiken.',
          ),
          const SizedBox(height: 20),
          SizedBox(height: 40, child: widget.googleButtonBuilder()),
          ListenableBuilder(
            listenable: widget.session,
            builder: (context, _) => widget.session.busy
                ? const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: CircularProgressIndicator(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
      ],
    );
  }
}
