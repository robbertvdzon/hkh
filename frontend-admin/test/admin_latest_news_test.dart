import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_admin/auth/admin_session.dart';
import 'package:hkh_admin/news/admin_latest_news.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('posts news with the authenticated admin credentials', () async {
    final client = AdminLatestNewsClient(
      'https://example.test',
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://example.test/api/admin/news');
        expect(request.headers['Authorization'], 'Bearer token');
        expect(request.headers['Content-Type'], 'application/json');
        expect(jsonDecode(request.body), {
          'title': 'Dorpsnieuws',
          'message': 'Een historisch verhaal.',
        });
        return http.Response('{}', 201);
      }),
    );

    await client.create(
      identity: const AdminIdentity(
        'admin@example.com',
        requestHeaders: {'Authorization': 'Bearer token'},
      ),
      title: 'Dorpsnieuws',
      message: 'Een historisch verhaal.',
    );
  });

  test('reports a rejected publication', () async {
    final client = AdminLatestNewsClient(
      'https://example.test',
      client: MockClient((_) async => http.Response('forbidden', 403)),
    );

    await expectLater(
      client.create(
        identity: const AdminIdentity('admin@example.com'),
        title: 'Titel',
        message: 'Bericht',
      ),
      throwsStateError,
    );
  });
}
