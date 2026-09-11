import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/backend/backend_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads and parses latest news', () async {
    final client = BackendClient(
      'https://example.test',
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://example.test/api/news');
        return http.Response(
          '[{"id":42,"title":"Dorpsnieuws","message":"Een verhaal",'
          '"publishedAt":"2026-08-07T09:00:00Z","createdAt":"2026-08-07T09:00:00Z"}]',
          200,
        );
      }),
    );

    final news = await client.loadLatestNews();

    expect(news, hasLength(1));
    expect(news.single.id, 42);
    expect(news.single.title, 'Dorpsnieuws');
    expect(news.single.message, 'Een verhaal');
    expect(news.single.publishedAt, DateTime.utc(2026, 8, 7, 9));
  });

  test('reports a backend error while loading news', () async {
    final client = BackendClient(
      'https://example.test',
      client: MockClient((_) async => http.Response('error', 500)),
    );

    await expectLater(client.loadLatestNews(), throwsStateError);
  });

  test('passes a quoted phrase and the selected field to the search API', () async {
    final client = BackendClient(
      'https://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/api/collections/search');
        expect(request.url.queryParameters['q'], '"de brand in de kerk"');
        expect(request.url.queryParameters['field'], 'Auteur(s)');
        expect(request.url.queryParameters['collection'], 'artikelen');
        return http.Response(
          '{"items":[],"total":0,"page":0,"pageSize":20}',
          200,
        );
      }),
    );

    await client.search(
      query: '"de brand in de kerk"',
      collection: 'artikelen',
      field: 'Auteur(s)',
    );
  });

  test('leaves field and collection off the query when unset', () async {
    final client = BackendClient(
      'https://example.test',
      client: MockClient((request) async {
        expect(request.url.queryParameters.containsKey('field'), isFalse);
        expect(request.url.queryParameters.containsKey('collection'), isFalse);
        return http.Response(
          '{"items":[],"total":0,"page":0,"pageSize":20}',
          200,
        );
      }),
    );

    await client.search(query: 'kerk toren');
  });

  test('loads the distinct field names for a collection', () async {
    final client = BackendClient(
      'https://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/api/collections/fields');
        expect(request.url.queryParameters['collection'], 'artikelen');
        return http.Response('{"fields":["Auteur(s)","Rubriek"]}', 200);
      }),
    );

    final fields = await client.loadFields(collection: 'artikelen');

    expect(fields, ['Auteur(s)', 'Rubriek']);
  });
}
