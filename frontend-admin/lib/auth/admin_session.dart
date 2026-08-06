import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AdminIdentity {
  const AdminIdentity(this.email);

  final String email;
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

  @override
  bool get configured => true;
  @override
  Stream<AdminIdentity> get identities => _identityController.stream;

  @override
  Future<AdminIdentity?> bootstrap() async {
    final account = await _googleSignIn.signInSilently();
    return account == null ? null : _authenticate(account);
  }

  @override
  Future<AdminIdentity?> signIn() async {
    final account = await _googleSignIn.signIn();
    return account == null ? null : _authenticate(account);
  }

  Future<AdminIdentity> _authenticate(GoogleSignInAccount account) async {
    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null) throw StateError('Google returned no ID token.');
    final response = await _client
        .get(
          Uri.parse('$apiBaseUrl/api/admin/me'),
          headers: {'Authorization': 'Bearer $idToken'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Admin login rejected (${response.statusCode}).');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminIdentity(json['email'] as String);
  }

  @override
  Future<void> signOut() => _googleSignIn.signOut();

  @override
  void dispose() {
    _accountSubscription?.cancel();
    _identityController.close();
    _client.close();
  }
}
