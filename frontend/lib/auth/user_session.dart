import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Een ingelogde gebruiker van de publieke app.
class UserIdentity {
  const UserIdentity({
    required this.email,
    required this.isAdmin,
    required this.token,
    this.displayName,
  });

  final String email;
  final String? displayName;
  final bool isAdmin;

  /// Het HKH-sessietoken (een jaar geldig, verlengend bij gebruik). Dit is nooit het ruwe
  /// Google ID-token; dat wordt één keer ingewisseld en daarna weggegooid.
  final String token;

  /// Naam om in de UI te tonen: de weergavenaam als die er is, anders het e-mailadres.
  String get label {
    final name = displayName?.trim();
    return name == null || name.isEmpty ? email : name;
  }
}

/// Houdt de (optionele) login van de publieke app bij. Inloggen is nooit verplicht: zonder
/// identiteit werkt de app anoniem verder.
abstract class UserSessionController extends ChangeNotifier {
  /// Of Google-login überhaupt beschikbaar is (client-id geconfigureerd).
  bool get configured;

  UserIdentity? get identity;

  bool get signedIn => identity != null;

  /// Sessietoken voor `Authorization: Bearer`, of null als er niemand is ingelogd.
  String? get token => identity?.token;

  /// Of er een login/logout of validatie loopt.
  bool get busy;

  /// Laatste foutmelding voor de gebruiker, of null.
  String? get error;

  /// Herstelt een eerder bewaarde sessie. Blokkeert de UI niet.
  Future<void> bootstrap();

  /// Start de Google-inlogflow (Android). Op web levert de GIS-knop het account.
  Future<void> signIn();

  Future<void> signOut();
}

/// Variant zonder Google-client-id: er is nooit iemand ingelogd.
class DisabledUserSession extends UserSessionController {
  @override
  bool get configured => false;
  @override
  UserIdentity? get identity => null;
  @override
  bool get busy => false;
  @override
  String? get error => null;
  @override
  Future<void> bootstrap() async {}
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
}

/// Google-login gekoppeld aan een HKH-sessietoken.
///
/// Het Google ID-token wordt één keer via `POST /api/auth/google` ingewisseld voor een
/// sessietoken dat in `shared_preferences` staat. Bij opstarten wordt dat token gevalideerd
/// via `GET /api/auth/me`; een 401 wist het lokaal.
class GoogleUserSession extends UserSessionController {
  GoogleUserSession({
    required this.apiBaseUrl,
    required String googleClientId,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _googleSignIn = googleClientId.isEmpty
           ? null
           : GoogleSignIn(
               clientId: kIsWeb ? googleClientId : null,
               serverClientId: kIsWeb ? null : googleClientId,
               scopes: const ['email'],
             ) {
    _accountSubscription = _googleSignIn?.onCurrentUserChanged.listen(
      _onGoogleAccount,
    );
  }

  static const tokenPrefsKey = 'hkh_user_session_token';
  static const emailPrefsKey = 'hkh_user_session_email';
  static const _timeout = Duration(seconds: 10);

  final String apiBaseUrl;
  final http.Client _client;
  final GoogleSignIn? _googleSignIn;
  StreamSubscription<GoogleSignInAccount?>? _accountSubscription;

  UserIdentity? _identity;
  bool _busy = false;
  String? _error;

  @override
  bool get configured => _googleSignIn != null;
  @override
  UserIdentity? get identity => _identity;
  @override
  bool get busy => _busy;
  @override
  String? get error => _error;

  @override
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenPrefsKey);
    if (token == null) return;
    _setBusy(true);
    try {
      final response = await _client
          .get(
            Uri.parse('$apiBaseUrl/api/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        _identity = _identityFromUser(
          jsonDecode(response.body) as Map<String, dynamic>,
          token,
        );
        await prefs.setString(emailPrefsKey, _identity!.email);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await _clearStored(prefs);
      }
      // Andere fouten (bijv. geen netwerk): token bewaren, uitgelogd tonen.
    } catch (_) {
      // Zie hierboven: tijdelijke fouten kosten de gebruiker zijn sessie niet.
    } finally {
      _setBusy(false);
    }
  }

  @override
  Future<void> signIn() async {
    // Op web levert de GIS-knop het account via onCurrentUserChanged.
    if (kIsWeb || _googleSignIn == null) return;
    _error = null;
    _setBusy(true);
    try {
      final account = await _googleSignIn.signIn();
      // Bij een account doet de onCurrentUserChanged-listener de rest.
      if (account == null) {
        _setBusy(false); // Geannuleerd.
      }
    } catch (_) {
      _error = 'Inloggen met Google is mislukt.';
      _setBusy(false);
    }
  }

  Future<void> _onGoogleAccount(GoogleSignInAccount? account) async {
    if (account == null) return;
    _setBusy(true);
    try {
      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null) {
        _error = 'Google gaf geen ID-token terug.';
        return;
      }
      await completeGoogleLogin(idToken);
    } catch (_) {
      _error = 'Inloggen met Google is mislukt.';
    } finally {
      _setBusy(false);
    }
  }

  /// Wisselt een Google ID-token in voor een HKH-sessietoken en bewaart dat lokaal.
  /// Publiek zodat de uitwisseling los van de Google-plugin te testen is.
  Future<void> completeGoogleLogin(String idToken) async {
    _error = null;
    _setBusy(true);
    try {
      final response = await _client
          .post(
            Uri.parse('$apiBaseUrl/api/auth/google'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        _error = response.statusCode == 503
            ? 'Inloggen is op dit moment niet beschikbaar.'
            : 'Google-login is geweigerd (${response.statusCode}).';
        return;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final token = json['token'] as String;
      final identity = _identityFromUser(
        json['user'] as Map<String, dynamic>,
        token,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tokenPrefsKey, token);
      await prefs.setString(emailPrefsKey, identity.email);
      _identity = identity;
    } catch (_) {
      _error = 'Inloggen is mislukt. Probeer het later opnieuw.';
    } finally {
      _setBusy(false);
    }
  }

  @override
  Future<void> signOut() async {
    _error = null;
    _setBusy(true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenPrefsKey) ?? _identity?.token;
    try {
      if (token != null) {
        await _client
            .post(
              Uri.parse('$apiBaseUrl/api/auth/logout'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(_timeout);
      }
    } catch (_) {
      // Lokaal uitloggen gaat hoe dan ook door.
    }
    await _clearStored(prefs);
    try {
      await _googleSignIn?.signOut();
    } catch (_) {
      // Zonder Google-plugin (bijv. in tests) is er niets uit te loggen.
    }
    _setBusy(false);
  }

  Future<void> _clearStored(SharedPreferences prefs) async {
    await prefs.remove(tokenPrefsKey);
    await prefs.remove(emailPrefsKey);
    _identity = null;
  }

  static UserIdentity _identityFromUser(
    Map<String, dynamic> user,
    String token,
  ) {
    final roles = user['roles'];
    return UserIdentity(
      email: user['email'] as String,
      displayName: user['displayName'] as String?,
      isAdmin: roles is List && roles.contains('ADMIN'),
      token: token,
    );
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _accountSubscription?.cancel();
    _client.close();
    super.dispose();
  }
}
