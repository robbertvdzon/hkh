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

/// Rollen waarvoor apart een model te kiezen is.
enum AiRole {
  agent('AGENT', 'Agent', 'Zoekt zelf via de API (methode agent).'),
  extraction(
    'EXTRACTION',
    'Extractie',
    'Maakt de AI-kaarten (samenvatting en trefwoorden); bulkwerk, klein model.',
  ),
  research(
    'RESEARCH',
    'Onderzoek',
    'Bepaalt zoektermen en beoordeelt kaarten per ronde (methode pijplijn).',
  ),
  writer(
    'WRITER',
    'Schrijven',
    'Schrijft het antwoord uit de gekozen documenten (methode pijplijn).',
  );

  const AiRole(this.apiValue, this.label, this.description);

  final String apiValue;
  final String label;
  final String description;

  static AiRole fromApiValue(String? value) => AiRole.values.firstWhere(
    (role) => role.apiValue == value,
    orElse: () => AiRole.agent,
  );
}

/// Onderzoeksmethode voor nieuwe vragen.
enum AiResearchMethod {
  agent(
    'AGENT',
    'Agent',
    'De agent zoekt zelf via de REST-API, zoals tot nu toe.',
  ),
  pipeline(
    'PIPELINE',
    'Pijplijn',
    'De code bestuurt de rondes: tolerant zoeken in AI-kaarten, het model '
        'beoordeelt en schrijft.',
  );

  const AiResearchMethod(this.apiValue, this.label, this.description);

  final String apiValue;
  final String label;
  final String description;

  static AiResearchMethod fromApiValue(String? value) =>
      AiResearchMethod.values.firstWhere(
        (method) => method.apiValue == value,
        orElse: () => AiResearchMethod.agent,
      );
}

/// Het huidige model van één rol.
class AiRoleModel {
  const AiRoleModel({
    required this.role,
    required this.current,
    required this.fromSetting,
  });

  factory AiRoleModel.fromJson(Map<String, dynamic> json) => AiRoleModel(
    role: AiRole.fromApiValue(json['role'] as String?),
    current: AiExecution.fromJson(json['current'] as Map<String, dynamic>),
    fromSetting: json['fromSetting'] as bool? ?? false,
  );

  final AiRole role;
  final AiExecution current;
  final bool fromSetting;
}

/// Actieve keuze van een rol plus de catalogus van de runtime, de methode en alle rollen.
class AiModelState {
  const AiModelState({
    required this.current,
    required this.fromSetting,
    required this.updatedAt,
    required this.updatedBy,
    required this.options,
    required this.catalogError,
    this.role = AiRole.agent,
    this.method = AiResearchMethod.agent,
    this.roles = const [],
  });

  factory AiModelState.fromJson(Map<String, dynamic> json) => AiModelState(
    role: AiRole.fromApiValue(json['role'] as String?),
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
    method: AiResearchMethod.fromApiValue(json['method'] as String?),
    roles: (json['roles'] as List<dynamic>? ?? const [])
        .map((item) => AiRoleModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  final AiRole role;
  final AiExecution current;
  final bool fromSetting;
  final DateTime? updatedAt;
  final String? updatedBy;
  final List<AiModelOption> options;
  final String? catalogError;
  final AiResearchMethod method;
  final List<AiRoleModel> roles;
}

abstract interface class AdminAiModelSource {
  Future<AiModelState> load(AdminIdentity identity, {AiRole role});
  Future<AiModelState> select(
    AdminIdentity identity,
    AiExecution execution, {
    AiRole role,
  });
  Future<AiModelState> reset(AdminIdentity identity, {AiRole role});
  Future<AiModelState> selectMethod(
    AdminIdentity identity,
    AiResearchMethod method,
  );
}

class AdminAiModelClient implements AdminAiModelSource {
  AdminAiModelClient(this.apiBaseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  Uri _modelUri(AiRole role) => Uri.parse(
    '$apiBaseUrl/api/admin/ai-search/model',
  ).replace(queryParameters: {'role': role.apiValue});

  Uri get _methodUri => Uri.parse('$apiBaseUrl/api/admin/ai-search/method');

  @override
  Future<AiModelState> load(
    AdminIdentity identity, {
    AiRole role = AiRole.agent,
  }) async => _parse(
    await _client
        .get(_modelUri(role), headers: identity.requestHeaders)
        .timeout(const Duration(seconds: 20)),
    'Modelinstelling laden mislukt',
  );

  @override
  Future<AiModelState> select(
    AdminIdentity identity,
    AiExecution execution, {
    AiRole role = AiRole.agent,
  }) async => _parse(
    await _client
        .put(
          _modelUri(role),
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
  Future<AiModelState> reset(
    AdminIdentity identity, {
    AiRole role = AiRole.agent,
  }) async => _parse(
    await _client
        .delete(_modelUri(role), headers: identity.requestHeaders)
        .timeout(const Duration(seconds: 20)),
    'Terugzetten mislukt',
  );

  @override
  Future<AiModelState> selectMethod(
    AdminIdentity identity,
    AiResearchMethod method,
  ) async => _parse(
    await _client
        .put(
          _methodUri,
          headers: {
            ...identity.requestHeaders,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'method': method.apiValue}),
        )
        .timeout(const Duration(seconds: 20)),
    'Methode kiezen mislukt',
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
