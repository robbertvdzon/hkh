import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminIdentity {
  const AdminIdentity(this.email, {this.requestHeaders = const {}});

  final String email;
  final Map<String, String> requestHeaders;
}

abstract interface class AdminSessionSource {
  bool get configured;
  Stream<AdminIdentity> get identities;
  Future<AdminIdentity?> bootstrap();
  Future<AdminIdentity?> signIn();
  Future<void> signOut();
  void dispose();
}

class DisabledAdminSessionSource implements AdminSessionSource {
  const DisabledAdminSessionSource();

  @override
  bool get configured => false;
  @override
  Stream<AdminIdentity> get identities => const Stream.empty();
  @override
  Future<AdminIdentity?> bootstrap() async => null;
  @override
  Future<AdminIdentity?> signIn() async => null;
  @override
  Future<void> signOut() async {}
  @override
  void dispose() {}
}

class PreviewAdminSessionSource implements AdminSessionSource {
  PreviewAdminSessionSource({required this.apiBaseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  @override
  bool get configured => true;
  @override
  Stream<AdminIdentity> get identities => const Stream.empty();

  @override
  Future<AdminIdentity?> bootstrap() => _authenticate();

  @override
  Future<AdminIdentity?> signIn() => _authenticate();

  Future<AdminIdentity> _authenticate() async {
    final response = await _client
        .get(
          Uri.parse('$apiBaseUrl/api/admin/me'),
          headers: const {'X-HKH-Preview-Admin': 'enabled'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError(
        'Preview admin login rejected (${response.statusCode}).',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminIdentity(
      json['email'] as String,
      requestHeaders: const {'X-HKH-Preview-Admin': 'enabled'},
    );
  }

  @override
  Future<void> signOut() async {}

  @override
  void dispose() => _client.close();
}

class AdminSessionService implements AdminSessionSource {
  AdminSessionService({
    required this.apiBaseUrl,
    required String googleClientId,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _googleSignIn = GoogleSignIn(
         clientId: kIsWeb ? googleClientId : null,
         serverClientId: kIsWeb ? null : googleClientId,
         scopes: const ['email'],
       ) {
    _accountSubscription = _googleSignIn.onCurrentUserChanged.listen((
      account,
    ) async {
      if (account == null) return;
      try {
        _identityController.add(await _authenticate(account));
      } catch (error, stackTrace) {
        _identityController.addError(error, stackTrace);
      }
    });
  }

  final String apiBaseUrl;
  final http.Client _client;
  final GoogleSignIn _googleSignIn;
  final StreamController<AdminIdentity> _identityController =
      StreamController.broadcast();
  StreamSubscription<GoogleSignInAccount?>? _accountSubscription;

  static const _tokenPrefsKey = 'hkh_admin_session_token';
  static const _emailPrefsKey = 'hkh_admin_session_email';

  @override
  bool get configured => true;
  @override
  Stream<AdminIdentity> get identities => _identityController.stream;

  /// Herstelt eerst het eerder bewaarde HKH-sessietoken (geen Google-round trip, dus geen
  /// herhaalde inlogprompt bij elke pagina-ververs) en valt alleen terug op Google's stille
  /// sign-in als er niets bewaard is of de bewaarde sessie niet langer geldig blijkt.
  ///
  /// Het sessietoken is een jaar geldig en schuift bij gebruik op; het vervalt alleen door
  /// expliciet uitloggen of intrekking aan de serverkant. Het ruwe Google ID-token (één uur
  /// geldig) wordt dus nooit bewaard.
  @override
  Future<AdminIdentity?> bootstrap() async {
    final stored = await _restoreStoredIdentity();
    if (stored != null) return stored;
    final account = await _googleSignIn.signInSilently();
    return account == null ? null : _authenticate(account);
  }

  @override
  Future<AdminIdentity?> signIn() async {
    final account = await _googleSignIn.signIn();
    return account == null ? null : _authenticate(account);
  }

  Future<AdminIdentity?> _restoreStoredIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenPrefsKey);
    final email = prefs.getString(_emailPrefsKey);
    if (token == null || email == null) return null;
    if (await _isValid(token)) {
      return AdminIdentity(
        email,
        requestHeaders: {'Authorization': 'Bearer $token'},
      );
    }
    await prefs.remove(_tokenPrefsKey);
    await prefs.remove(_emailPrefsKey);
    return null;
  }

  /// Een bewaarde sessie is geldig als de backend hem nog kent én het account beheerder is.
  Future<bool> _isValid(String sessionToken) async {
    final response = await _client
        .get(
          Uri.parse('$apiBaseUrl/api/auth/me'),
          headers: {'Authorization': 'Bearer $sessionToken'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return false;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _isAdmin(json);
  }

  /// Wisselt het (kortlevende) Google ID-token één keer in voor een HKH-sessietoken en bewaart
  /// dat sessietoken lokaal.
  Future<AdminIdentity> _authenticate(GoogleSignInAccount account) async {
    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null) throw StateError('Google returned no ID token.');
    final response = await _client
        .post(
          Uri.parse('$apiBaseUrl/api/auth/google'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError(
        'Inloggen geweigerd door de server (${response.statusCode}).',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final sessionToken = json['token'] as String;
    final user = json['user'] as Map<String, dynamic>;
    if (!_isAdmin(user)) {
      throw StateError('Dit account is geen HKH-beheerder.');
    }
    final email = user['email'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenPrefsKey, sessionToken);
    await prefs.setString(_emailPrefsKey, email);
    return AdminIdentity(
      email,
      requestHeaders: {'Authorization': 'Bearer $sessionToken'},
    );
  }

  static bool _isAdmin(Map<String, dynamic> user) {
    final roles = user['roles'];
    return roles is List && roles.contains('ADMIN');
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenPrefsKey);
    if (token != null) {
      try {
        await _client
            .post(
              Uri.parse('$apiBaseUrl/api/auth/logout'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // De sessie wordt lokaal hoe dan ook gewist; een mislukte server-logout is niet erg.
      }
    }
    await prefs.remove(_tokenPrefsKey);
    await prefs.remove(_emailPrefsKey);
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Zonder Google-plugin (bijv. in tests) is er niets uit te loggen.
    }
  }

  @override
  void dispose() {
    _accountSubscription?.cancel();
    _identityController.close();
    _client.close();
  }
}
