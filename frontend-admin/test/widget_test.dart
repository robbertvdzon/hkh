import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_admin/auth/admin_session.dart';
import 'package:hkh_admin/main.dart';
import 'package:hkh_admin/news/admin_latest_news.dart';

class _NewsSource implements AdminLatestNewsSource {
  String? title;
  String? message;

  @override
  Future<void> create({
    required AdminIdentity identity,
    required String title,
    required String message,
  }) async {
    this.title = title;
    this.message = message;
  }
}

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
    final newsSource = _NewsSource();
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: _AuthenticatedSession(),
        newsSource: newsSource,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beheerder geverifieerd'), findsOneWidget);
    expect(find.text('admin@example.com'), findsOneWidget);
    expect(find.text('Nieuw bericht'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Dorpsnieuws');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Een historisch bericht.',
    );
    await tester.ensureVisible(find.text('Publiceren'));
    await tester.tap(find.text('Publiceren'));
    await tester.pumpAndSettle();

    expect(newsSource.title, 'Dorpsnieuws');
    expect(newsSource.message, 'Een historisch bericht.');
    expect(find.text('Het nieuwsbericht is gepubliceerd.'), findsOneWidget);
  });

  testWidgets('explains when Google login is not configured', (tester) async {
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: const DisabledAdminSessionSource(),
        newsSource: _NewsSource(),
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
