import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.label,
    required this.installedVersionCode,
    required this.latestVersionCode,
    required this.downloadUrl,
    required this.apkFileName,
  });

  final String label;
  final int installedVersionCode;
  final int latestVersionCode;
  final String downloadUrl;
  final String apkFileName;

  bool get updateAvailable => latestVersionCode > installedVersionCode;
}

class UpdatePermissionRequiredException implements Exception {}

class UpdateChecker {
  static const _channel = MethodChannel('nl.vdzon.hkh/updater');
  static const _repository = String.fromEnvironment('UPDATE_REPOSITORY');
  static const _releaseTag = String.fromEnvironment('UPDATE_RELEASE_TAG');
  static const _label = String.fromEnvironment(
    'UPDATE_LABEL',
    defaultValue: 'HKH-app',
  );

  bool get isConfigured => _repository.isNotEmpty && _releaseTag.isNotEmpty;

  Future<AppUpdateInfo> check() async {
    final installedVersionCode =
        await _channel.invokeMethod<int>('installedVersionCode') ?? -1;
    final response = await http
        .get(
          Uri.parse(
            'https://api.github.com/repos/$_repository/releases/tags/$_releaseTag',
          ),
          headers: const {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('GitHub gaf HTTP ${response.statusCode} terug.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final body = json['body'] as String? ?? '';
    final latestVersionCode = int.tryParse(
      RegExp(r'build (\d+)').firstMatch(body)?.group(1) ?? '',
    );
    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final apk = assets.where((asset) {
      return (asset['name'] as String?)?.endsWith('.apk') ?? false;
    }).firstOrNull;
    if (latestVersionCode == null || apk == null) {
      throw StateError('De nieuwste APK-versie kon niet worden bepaald.');
    }

    return AppUpdateInfo(
      label: _label,
      installedVersionCode: installedVersionCode,
      latestVersionCode: latestVersionCode,
      downloadUrl: apk['browser_download_url'] as String,
      apkFileName: apk['name'] as String,
    );
  }

  Future<void> update(AppUpdateInfo info) async {
    final canInstall =
        await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    if (!canInstall) {
      await _channel.invokeMethod<void>('requestInstallPermission');
      throw UpdatePermissionRequiredException();
    }
    await _channel.invokeMethod<void>('downloadAndInstall', {
      'url': info.downloadUrl,
      'fileName': info.apkFileName,
    });
  }
}
