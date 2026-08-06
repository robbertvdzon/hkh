import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_admin/auth/admin_session.dart';
import 'package:hkh_admin/main.dart';

class _AuthenticatedSession implements AdminSessionSource {
  @override
  bool get configured => true;
  @override
  Stream<AdminIdentity> get identities => const Stream.empty();
  @override
  Future<AdminIdentity?> bootstrap() async =>
      const AdminIdentity('admin@example.com');
  @override
  Future<AdminIdentity?> signIn() async =>
      const AdminIdentity('admin@example.com');
  @override
  Future<void> signOut() async {}
  @override
  void dispose() {}
}

void main() {
  testWidgets('shows the verified administrator', (tester) async {
    await tester.pumpWidget(
      HkhAdminApp(sessionSource: _AuthenticatedSession()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beheerder geverifieerd'), findsOneWidget);
    expect(find.text('admin@example.com'), findsOneWidget);
  });

  testWidgets('explains when Google login is not configured', (tester) async {
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: const DisabledAdminSessionSource(),
        googleButtonBuilder: () => const SizedBox.shrink(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Google-login is nog niet geconfigureerd.'),
      findsOneWidget,
    );
  });
}
