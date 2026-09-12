import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_admin/auth/admin_session.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'hkh_admin_session_token';
const _emailKey = 'hkh_admin_session_email';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AdminSessionService service(MockClient client) => AdminSessionService(
    apiBaseUrl: 'https://example.test',
    googleClientId: 'client-id',
    client: client,
  );

  test('bootstrap restores a stored session token via /api/auth/me', () async {
    SharedPreferences.setMockInitialValues({
      _tokenKey: 'sess-1',
      _emailKey: 'admin@example.com',
    });
    final requests = <http.Request>[];
    final identity = await service(
      MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{"email":"admin@example.com","displayName":null,"roles":["ADMIN"]}',
          200,
        );
      }),
    ).bootstrap();

    expect(requests.single.url.path, '/api/auth/me');
    expect(requests.single.headers['Authorization'], 'Bearer sess-1');
    expect(identity?.email, 'admin@example.com');
    expect(identity?.requestHeaders, {'Authorization': 'Bearer sess-1'});
  });

  test('a stored session without the ADMIN role is discarded', () async {
    SharedPreferences.setMockInitialValues({
      _tokenKey: 'sess-user',
      _emailKey: 'user@example.com',
    });
    final identity = await service(
      MockClient(
        (_) async => http.Response(
          '{"email":"user@example.com","displayName":null,"roles":[]}',
          200,
        ),
      ),
    ).bootstrap();

    expect(identity, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_tokenKey), isNull);
  });

  test('a 401 on bootstrap clears the stored session', () async {
    SharedPreferences.setMockInitialValues({
      _tokenKey: 'sess-expired',
      _emailKey: 'admin@example.com',
    });
    final identity = await service(
      MockClient((_) async => http.Response('', 401)),
    ).bootstrap();

    expect(identity, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_tokenKey), isNull);
    expect(prefs.getString(_emailKey), isNull);
  });

  test('signOut revokes the session on the server and locally', () async {
    SharedPreferences.setMockInitialValues({
      _tokenKey: 'sess-1',
      _emailKey: 'admin@example.com',
    });
    final requests = <http.Request>[];
    await service(
      MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    ).signOut();

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/auth/logout');
    expect(requests.single.headers['Authorization'], 'Bearer sess-1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_tokenKey), isNull);
  });
}
