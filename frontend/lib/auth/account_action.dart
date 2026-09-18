import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'google_login_dialog.dart';
import 'user_session.dart';

/// Compacte, vaste accountknop in de merkheader op iedere pagina.
class AccountAction extends StatelessWidget {
  const AccountAction({
    required this.session,
    this.googleButtonBuilder,
    super.key,
  });

  final UserSessionController session;
  final Widget Function()? googleButtonBuilder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      if (!session.configured && !session.signedIn) {
        return const SizedBox.shrink();
      }
      final identity = session.identity;
      final decoration = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF728994)),
      );
      if (identity != null) {
        return PopupMenuButton<String>(
          key: const Key('account-menu'),
          tooltip: 'Mijn account',
          onSelected: (_) => session.signOut(),
          itemBuilder: (_) => [
            PopupMenuItem<String>(enabled: false, child: Text(identity.label)),
            const PopupMenuItem(
              value: 'sign-out',
              child: ListTile(
                leading: Icon(Icons.logout),
                title: Text('Uitloggen'),
              ),
            ),
          ],
          child: Container(
            width: 44,
            height: 44,
            decoration: decoration,
            child: const Icon(
              Icons.person_outline,
              color: appHeaderForeground,
              size: 22,
            ),
          ),
        );
      }
      return Container(
        decoration: decoration,
        child: IconButton(
          tooltip: 'Inloggen',
          onPressed: session.busy
              ? null
              : () => startSignIn(
                  context,
                  session,
                  googleButtonBuilder: googleButtonBuilder,
                ),
          icon: session.busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: appHeaderForeground,
                  ),
                )
              : const Icon(
                  Icons.person_outline,
                  color: appHeaderForeground,
                  size: 22,
                ),
        ),
      );
    },
  );
}
