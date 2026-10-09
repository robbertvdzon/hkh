import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/backend/backend_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'account sync sends the signed in token and does not silently fall back on 401',
    () async {
      var unauthorized = false;
      final client = BackendClient(
        'https://example.test',
        tokenProvider: () => 'session-test',
        onUnauthorized: () => unauthorized = true,
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/ai-search/sessions/claim');
          expect(request.headers['Authorization'], 'Bearer session-test');
          return http.Response('', 401);
        }),
      );
      await expectLater(client.syncAiSearchAccount(), throwsStateError);
      expect(unauthorized, isTrue);
    },
  );

  test(
    'passes a quoted phrase and per-field queries to the search API',
    () async {
      final client = BackendClient(
        'https://example.test',
        client: MockClient((request) async {
          expect(request.url.path, '/api/collections/search');
          expect(request.url.queryParameters['q'], '"de brand in de kerk"');
          expect(request.url.queryParametersAll['fq'], [
            'Auteur(s):Hin',
            'Rubriek:Verenigingszaken',
          ]);
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
        fieldQueries: const {'Auteur(s)': 'Hin', 'Rubriek': 'Verenigingszaken'},
      );
    },
  );

  test('leaves fq and collection off the query when unset', () async {
    final client = BackendClient(
      'https://example.test',
      client: MockClient((request) async {
        expect(request.url.queryParameters.containsKey('fq'), isFalse);
        expect(request.url.queryParameters.containsKey('collection'), isFalse);
        return http.Response(
          '{"items":[],"total":0,"page":0,"pageSize":20}',
          200,
        );
      }),
    );

    await client.search(query: 'kerk toren');
  });

  test('passes year as an exact match parameter', () async {
    final client = BackendClient(
      'https://example.test',
      client: MockClient((request) async {
        expect(request.url.queryParameters['year'], '1954');
        return http.Response(
          '{"items":[],"total":0,"page":0,"pageSize":20}',
          200,
        );
      }),
    );

    await client.search(query: 'kroniek', year: 1954);
  });

  for (final includesThumbnail in [false, true]) {
    test(
      'loads PDF detail ${includesThumbnail ? 'with a first-page thumbnail' : 'from a response without thumbnailUrl'}',
      () async {
        const pdfUrl = 'https://example.test/api/media/document.pdf';
        const thumbnailUrl = 'https://example.test/api/media/first-page.jpg';
        final client = BackendClient(
          'https://example.test',
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/collections/artikelen/42');
            return http.Response(
              jsonEncode({
                'collection': 'artikelen',
                'ident': '42',
                'title': 'De geschiedenis van de Kerklaan',
                'pdfUrl': pdfUrl,
                'detailUrl': 'https://example.test/#/objecten/artikelen/42',
                if (includesThumbnail) 'thumbnailUrl': thumbnailUrl,
                'fields': {'Aantal paginas': '10'},
              }),
              200,
            );
          }),
        );

        final detail = await client.loadDetail('artikelen', '42');

        expect(detail.collection, 'artikelen');
        expect(detail.ident, '42');
        expect(detail.pdfUrl, pdfUrl);
        expect(detail.thumbnailUrl, includesThumbnail ? thumbnailUrl : isNull);
        expect(detail.fields['Aantal paginas'], '10');
      },
    );
  }

  test('starts an AI search without exposing runtime details', () async {
    final client = BackendClient(
      'https://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/api/ai-search/sessions');
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {
          'question': 'Wat gebeurde er aan de Kerklaan?',
          'depth': 'FAST',
        });
        return http.Response(
          '{"id":"s1","turns":[{"id":"t1","turnNumber":1,"question":"Wat gebeurde er aan de Kerklaan?","status":"QUEUED","progressPercent":5,"progressMessage":"Klaar","title":null,"answerHtml":null,"sources":[],"suggestedFollowUps":[],"errorMessage":null,"createdAt":"2026-09-12T00:00:00Z","updatedAt":"2026-09-12T00:00:05Z","completedAt":null,"durationSeconds":5}]}',
          202,
        );
      }),
    );

    final session = await client.startAiSearch(
      'Wat gebeurde er aan de Kerklaan?',
    );

    expect(session.id, 's1');
    expect(session.turns.single.status, 'QUEUED');
  });

  test('lists and deletes persisted AI searches', () async {
    final requests = <http.Request>[];
    final client = BackendClient(
      'https://example.test',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'DELETE') return http.Response('', 204);
        return http.Response(
          '[{"id":"s1","question":"Kerklaan","title":"Geschiedenis","status":"SUCCEEDED","progressPercent":100,"progressMessage":"Onderzoek afgerond","turnCount":1,"createdAt":"2026-09-12T00:00:00Z","updatedAt":"2026-09-12T00:01:05Z","completedAt":"2026-09-12T00:01:05Z","durationSeconds":65}]',
          200,
        );
      }),
    );

    final searches = await client.listAiSearches();
    await client.deleteAiSearch('s1');

    expect(searches.single.durationSeconds, 65);
    expect(requests[0].method, 'GET');
    expect(requests[1].method, 'DELETE');
  });

  test('sends the session token as a Bearer header on every request', () async {
    final requests = <http.Request>[];
    final client = BackendClient(
      'https://example.test',
      tokenProvider: () => 'sess-1',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/collections/search') {
          return http.Response(
            '{"items":[],"total":0,"page":0,"pageSize":20}',
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    await client.search(query: 'kerk');
    await client.listAiSearches();

    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.headers['Authorization'], 'Bearer sess-1');
    }
  });

  test('sends no Authorization header when there is no session', () async {
    final client = BackendClient(
      'https://example.test',
      tokenProvider: () => null,
      client: MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('[]', 200);
      }),
    );

    await client.listAiSearches();
  });

  test('reports the problem detail on 409 and signs out on 401', () async {
    var unauthorized = 0;
    final client = BackendClient(
      'https://example.test',
      onUnauthorized: () => unauthorized++,
      client: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            '{"title":"Conflict","status":409,"detail":"Er loopt al een zoekopdracht."}',
            409,
            headers: const {'content-type': 'application/problem+json'},
          );
        }
        return http.Response('', 401);
      }),
    );

    await expectLater(
      client.startAiSearch('Wie woonde aan de Kerklaan?'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Er loopt al een zoekopdracht.',
        ),
      ),
    );
    await expectLater(client.listAiSearches(), throwsA(isA<StateError>()));
    expect(unauthorized, 1);
  });

  test('fetches the answer pdf from the export endpoint', () async {
    final client = BackendClient(
      'https://example.test',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/ai-search/turn-1/export/pdf');
        return http.Response.bytes(
          utf8.encode('%PDF-1.4 inhoud'),
          200,
          headers: const {'content-type': 'application/pdf'},
        );
      }),
    );

    final bytes = await client.exportAnswerPdf('turn-1');

    expect(utf8.decode(bytes), startsWith('%PDF'));
  });

  test('rejects an export that is not a non-empty pdf', () async {
    http.Response response = http.Response('', 500);
    final client = BackendClient(
      'https://example.test',
      client: MockClient((request) async => response),
    );

    await expectLater(
      client.exportAnswerPdf('turn-1'),
      throwsA(isA<StateError>()),
    );

    response = http.Response(
      'geen pdf',
      200,
      headers: const {'content-type': 'application/json'},
    );
    await expectLater(
      client.exportAnswerPdf('turn-1'),
      throwsA(isA<StateError>()),
    );

    response = http.Response.bytes(
      const [],
      200,
      headers: const {'content-type': 'application/pdf'},
    );
    await expectLater(
      client.exportAnswerPdf('turn-1'),
      throwsA(isA<StateError>()),
    );
  });
}
