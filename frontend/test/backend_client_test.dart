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
          '{"id":"s1","turns":[{"id":"t1","turnNumber":1,"question":"Wat gebeurde er aan de Kerklaan?","status":"QUEUED","progressPercent":5,"progressMessage":"Klaar","title":null,"answerHtml":null,"sources":[],"suggestedFollowUps":[],"errorMessage":null,"createdAt":"2026-09-12T00:00:00Z"}]}',
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
}
