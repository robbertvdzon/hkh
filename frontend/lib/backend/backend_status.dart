class BackendStatus {
  const BackendStatus({
    required this.application,
    required this.version,
    required this.commit,
  });

  final String application;
  final String version;
  final String commit;

  factory BackendStatus.fromJson(Map<String, dynamic> json) {
    return BackendStatus(
      application: json['application'] as String,
      version: json['version'] as String,
      commit: json['commit'] as String,
    );
  }
}

abstract interface class BackendStatusSource {
  Future<BackendStatus> load();
}
