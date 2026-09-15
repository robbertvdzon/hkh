import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/auth/user_session.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userJson =
    '{"email":"jan@example.com","displayName":"Jan","roles":["ADMIN"]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native session restores and logs out without Google configuration',
    () async {
      SharedPreferences.setMockInitialValues({
        GoogleUserSession.tokenPrefsKey: 'native-session',
      });
      final requests = <http.Request>[];
      final controller = GoogleUserSession(
        apiBaseUrl: 'https://example.test',
        googleClientId: '',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            request.url.path == '/api/auth/me' ? _userJson : '',
            200,
          );
        }),
      );
      expect(controller.configured, isFalse);
      await controller.bootstrap();
      expect(controller.signedIn, isTrue);
      expect(requests.single.headers['Authorization'], 'Bearer native-session');
      await controller.signOut();
      expect(requests.last.url.path, '/api/auth/logout');
      expect(controller.signedIn, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString(
          GoogleUserSession.tokenPrefsKey,
        ),
        isNull,
      );
      controller.dispose();
    },
  );

  GoogleUserSession session(MockClient client) => GoogleUserSession(
    apiBaseUrl: 'https://example.test',
    googleClientId: 'client-id',
    client: client,
  );

  test('bootstrap validates a stored token via /api/auth/me', () async {
    SharedPreferences.setMockInitialValues({
      GoogleUserSession.tokenPrefsKey: 'sess-1',
      GoogleUserSession.emailPrefsKey: 'jan@example.com',
    });
    final requests = <http.Request>[];
    final controller = session(
      MockClient((request) async {
        requests.add(request);
        return http.Response(_userJson, 200);
      }),
    );

    await controller.bootstrap();

    expect(requests.single.url.path, '/api/auth/me');
    expect(requests.single.headers['Authorization'], 'Bearer sess-1');
    expect(controller.identity?.email, 'jan@example.com');
    expect(controller.identity?.displayName, 'Jan');
    expect(controller.identity?.isAdmin, isTrue);
    expect(controller.token, 'sess-1');
    expect(controller.busy, isFalse);
  });

  test('bootstrap without a stored token does not call the backend', () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final controller = session(
      MockClient((_) async {
        calls++;
        return http.Response(_userJson, 200);
      }),
    );

    await controller.bootstrap();

    expect(calls, 0);
    expect(controller.signedIn, isFalse);
  });

  test('a 401 on bootstrap clears the stored token', () async {
    SharedPreferences.setMockInitialValues({
      GoogleUserSession.tokenPrefsKey: 'sess-expired',
      GoogleUserSession.emailPrefsKey: 'jan@example.com',
    });
    final controller = session(MockClient((_) async => http.Response('', 401)));

    await controller.bootstrap();

    expect(controller.signedIn, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(GoogleUserSession.tokenPrefsKey), isNull);
    expect(prefs.getString(GoogleUserSession.emailPrefsKey), isNull);
  });

  test(
    'completeGoogleLogin exchanges the ID token and stores the session',
    () async {
      SharedPreferences.setMockInitialValues({});
      final requests = <http.Request>[];
      final controller = session(
        MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"token":"sess-new","user":{"email":"jan@example.com","displayName":null,"roles":[]}}',
            200,
          );
        }),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.completeGoogleLogin('google-id-token');

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/api/auth/google');
      expect(jsonDecode(requests.single.body), {'idToken': 'google-id-token'});
      expect(controller.identity?.email, 'jan@example.com');
      expect(controller.identity?.isAdmin, isFalse);
      expect(controller.identity?.label, 'jan@example.com');
      expect(controller.token, 'sess-new');
      expect(controller.error, isNull);
      expect(notifications, greaterThan(0));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(GoogleUserSession.tokenPrefsKey), 'sess-new');
      expect(
        prefs.getString(GoogleUserSession.emailPrefsKey),
        'jan@example.com',
      );
    },
  );

  test(
    'a rejected Google token leaves the user signed out with an error',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = session(
        MockClient((_) async => http.Response('', 401)),
      );

      await controller.completeGoogleLogin('bad-token');

      expect(controller.signedIn, isFalse);
      expect(controller.error, isNotNull);
    },
  );

  test('signOut calls /api/auth/logout and clears the session', () async {
    SharedPreferences.setMockInitialValues({
      GoogleUserSession.tokenPrefsKey: 'sess-1',
      GoogleUserSession.emailPrefsKey: 'jan@example.com',
    });
    final requests = <http.Request>[];
    final controller = session(
      MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/auth/logout') {
          return http.Response('', 204);
        }
        return http.Response(_userJson, 200);
      }),
    );
    await controller.bootstrap();
    expect(controller.signedIn, isTrue);

    await controller.signOut();

    final logout = requests.last;
    expect(logout.method, 'POST');
    expect(logout.url.path, '/api/auth/logout');
    expect(logout.headers['Authorization'], 'Bearer sess-1');
    expect(controller.signedIn, isFalse);
    expect(controller.token, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(GoogleUserSession.tokenPrefsKey), isNull);
  });
}
