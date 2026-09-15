import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/backend/backend_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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

  test('starts an AI search without exposing runtime details', () async {
    final client = BackendClient(
      'https://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/api/ai-search/sessions');
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {
          'question': 'Wat gebeurde er aan de Kerklaan?',
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

  test('creates a dossier with title and goal', () async {
    final client = BackendClient(
      'https://example.test',
      tokenProvider: () => 'sess-1',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/dossiers');
        expect(request.headers['Authorization'], 'Bearer sess-1');
        expect(jsonDecode(request.body), {
          'title': 'De Kerklaan',
          'goal': 'Artikel voor het blad',
        });
        return http.Response(
          '{"id":"d1","title":"De Kerklaan","goal":"Artikel voor het blad","role":"OWNER","ownerEmail":"jan@example.com","members":[],"factSheet":{"markdown":"","html":"","sources":[],"status":"IDLE","dirty":false,"updatedAt":null,"error":null},"questions":[],"articles":[],"createdAt":"2026-09-12T00:00:00Z","updatedAt":"2026-09-12T00:00:00Z"}',
          201,
        );
      }),
    );

    final dossier = await client.createDossier(
      title: 'De Kerklaan',
      goal: 'Artikel voor het blad',
    );

    expect(dossier.id, 'd1');
    expect(dossier.role.canManage, isTrue);
    expect(dossier.factSheet.status, 'IDLE');
  });

  test('saves an article with the base version and reads the diff', () async {
    final requests = <http.Request>[];
    final client = BackendClient(
      'https://example.test',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'PUT') {
          expect(request.url.path, '/api/articles/a1');
          expect(jsonDecode(request.body), {
            'title': 'Titel',
            'contentMarkdown': 'Tekst',
            'basedOnVersionId': 'v1',
          });
          return http.Response(
            '{"id":"a1","dossierId":"d1","dossierTitle":"De Kerklaan","title":"Titel","role":"EDITOR","current":{"id":"v2","versionNumber":2,"title":"Titel","contentMarkdown":"Tekst","contentHtml":"<p>Tekst</p>","sources":[],"unknownSources":[],"authorKind":"USER","authorEmail":"jan@example.com","aiInstruction":null,"changeSummary":null,"state":"ACCEPTED","jobStatus":null,"progressMessage":null,"errorMessage":null,"basedOnVersionNumber":1,"createdAt":"2026-09-12T00:00:00Z","decidedAt":null,"decidedByEmail":null},"proposal":null,"versionCount":2,"createdAt":"2026-09-12T00:00:00Z","updatedAt":"2026-09-12T00:00:00Z"}',
            200,
          );
        }
        expect(request.url.path, '/api/articles/a1/versions/2/diff');
        expect(request.url.queryParameters['against'], '1');
        return http.Response(
          '{"fromVersion":1,"toVersion":2,"lines":[{"type":"DELETE","text":"a"},{"type":"INSERT","text":"b"}]}',
          200,
        );
      }),
    );

    final article = await client.saveArticle(
      'a1',
      title: 'Titel',
      contentMarkdown: 'Tekst',
      basedOnVersionId: 'v1',
    );
    final diff = await client.loadDiff('a1', versionNumber: 2, against: 1);

    expect(article.current.versionNumber, 2);
    expect(article.role.canEdit, isTrue);
    expect(article.role.canManage, isFalse);
    expect(diff.lines.map((line) => line.type), ['DELETE', 'INSERT']);
    expect(requests, hasLength(2));
  });

  test('reports the problem detail on 409 and signs out on 401', () async {
    var unauthorized = 0;
    final client = BackendClient(
      'https://example.test',
      onUnauthorized: () => unauthorized++,
      client: MockClient((request) async {
        if (request.url.path == '/api/articles/a1') {
          return http.Response(
            '{"title":"Conflict","status":409,"detail":"Iemand anders heeft dit artikel al opgeslagen."}',
            409,
            headers: const {'content-type': 'application/problem+json'},
          );
        }
        return http.Response('', 401);
      }),
    );

    await expectLater(
      client.saveArticle(
        'a1',
        title: 'T',
        contentMarkdown: '',
        basedOnVersionId: 'v1',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Iemand anders heeft dit artikel al opgeslagen.',
        ),
      ),
    );
    await expectLater(client.listDossiers(), throwsA(isA<StateError>()));
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
