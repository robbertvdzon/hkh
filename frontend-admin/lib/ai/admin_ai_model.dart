import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/admin_session.dart';

/// Leverancier, model en uitvoeringswijze van de digitale onderzoeker.
class AiExecution {
  const AiExecution({
    required this.vendorId,
    required this.model,
    required this.mode,
    required this.label,
  });

  factory AiExecution.fromJson(Map<String, dynamic> json) => AiExecution(
    vendorId: json['vendorId'] as String? ?? '',
    model: json['model'] as String? ?? '',
    mode: json['mode'] as String? ?? '',
    label: json['label'] as String? ?? '',
  );

  final String vendorId;
  final String model;
  final String mode;
  final String label;

  String get key => '$vendorId|$model|$mode';
}

class AiModelOption {
  const AiModelOption({
    required this.execution,
    required this.available,
    required this.onlineWorkers,
  });

  factory AiModelOption.fromJson(Map<String, dynamic> json) => AiModelOption(
    execution: AiExecution.fromJson(json['execution'] as Map<String, dynamic>),
    available: json['available'] as bool? ?? false,
    onlineWorkers: (json['onlineWorkers'] as num?)?.toInt() ?? 0,
  );

  final AiExecution execution;
  final bool available;
  final int onlineWorkers;
}

/// Actieve keuze plus de catalogus van de runtime.
class AiModelState {
  const AiModelState({
    required this.current,
    required this.fromSetting,
    required this.updatedAt,
    required this.updatedBy,
    required this.options,
    required this.catalogError,
  });

  factory AiModelState.fromJson(Map<String, dynamic> json) => AiModelState(
    current: AiExecution.fromJson(json['current'] as Map<String, dynamic>),
    fromSetting: json['fromSetting'] as bool? ?? false,
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.tryParse(json['updatedAt'] as String),
    updatedBy: json['updatedBy'] as String?,
    options: (json['options'] as List<dynamic>? ?? const [])
        .map((item) => AiModelOption.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    catalogError: json['catalogError'] as String?,
  );

  final AiExecution current;
  final bool fromSetting;
  final DateTime? updatedAt;
  final String? updatedBy;
  final List<AiModelOption> options;
  final String? catalogError;
}

abstract interface class AdminAiModelSource {
  Future<AiModelState> load(AdminIdentity identity);
  Future<AiModelState> select(AdminIdentity identity, AiExecution execution);
  Future<AiModelState> reset(AdminIdentity identity);
}

class AdminAiModelClient implements AdminAiModelSource {
  AdminAiModelClient(this.apiBaseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  Uri get _uri => Uri.parse('$apiBaseUrl/api/admin/ai-search/model');

  @override
  Future<AiModelState> load(AdminIdentity identity) async => _parse(
    await _client
        .get(_uri, headers: identity.requestHeaders)
        .timeout(const Duration(seconds: 20)),
    'Modelinstelling laden mislukt',
  );

  @override
  Future<AiModelState> select(
    AdminIdentity identity,
    AiExecution execution,
  ) async => _parse(
    await _client
        .put(
          _uri,
          headers: {
            ...identity.requestHeaders,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'vendorId': execution.vendorId,
            'model': execution.model,
            'mode': execution.mode,
          }),
        )
        .timeout(const Duration(seconds: 20)),
    'Model kiezen mislukt',
  );

  @override
  Future<AiModelState> reset(AdminIdentity identity) async => _parse(
    await _client
        .delete(_uri, headers: identity.requestHeaders)
        .timeout(const Duration(seconds: 20)),
    'Terugzetten mislukt',
  );

  AiModelState _parse(http.Response response, String failure) {
    if (response.statusCode != 200) {
      String? detail;
      try {
        detail =
            (jsonDecode(response.body) as Map<String, dynamic>)['message']
                as String?;
      } catch (_) {}
      throw StateError(
        '$failure (${response.statusCode})${detail == null ? '' : ': $detail'}',
      );
    }
    return AiModelState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
