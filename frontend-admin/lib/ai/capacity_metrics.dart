/// Display metrics keep unknown measurements distinct from zero.
class CapacityMetrics {
  CapacityMetrics(this.phases, this.limits, {DateTime? now})
    : now = now ?? DateTime.now();
  final List<Map<String, dynamic>> phases;
  final List<Map<String, dynamic>> limits;
  final DateTime now;

  static DateTime? time(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
  static List<Map<String, dynamic>> rows(dynamic value) =>
      (value is List ? value : const []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get attempts =>
      phases.expand((p) => rows(p['attempts'])).toList();
  List<String> get keys => phases
      .where((p) => p['job_id'] != null)
      .map((p) => '${p['phase_key']}')
      .toSet()
      .toList();
  int get runs => keys.length;
  int get attemptCount => phases.fold(0, (n, p) {
    final measured =
        ((p['usage'] as Map?)?['attemptCount'] as num?)?.toInt() ?? 0;
    final observed = rows(p['attempts']).length;
    return n + (measured > observed ? measured : observed);
  });
  int get retries => (attemptCount - runs).clamp(0, 1000000);
  int get errors => phases.fold(0, (n, p) {
    final a = rows(p['attempts']);
    return n +
        (a.isNotEmpty
            ? a
                  .where(
                    (v) => v['status'] == 'FAILED' || v['errorCode'] != null,
                  )
                  .length
            : ['FAILED', 'RETRY'].contains(p['status']) ||
                  p['error_code'] != null
            ? 1
            : 0);
  });
  String errorsLabel(String status) => errors == 0
      ? (status == 'FAILED' ? 'Mislukt' : 'Geen')
      : status == 'SUCCEEDED'
      ? '$errors hersteld'
      : '$errors fout${errors == 1 ? '' : 'en'}';
  String get runsLabel =>
      '$runs${retries > 0 ? ' + $retries herpoging${retries == 1 ? '' : 'en'}' : ''}';
  String get limitLabel {
    final kinds = limits
        .where((l) => (l['observation'] as Map?)?['blocked'] != false)
        .map((l) => (l['observation'] as Map?)?['kind'])
        .toSet();
    if (kinds.isEmpty) return 'Geen waargenomen';
    return kinds
        .map(
          (k) =>
              const {
                'SHORT_WINDOW': 'Kort venster',
                'WEEK': 'Week',
                'MONTH': 'Maand',
                'UNKNOWN': 'Onbekend',
              }[k] ??
              'Onbekend',
        )
        .join(', ');
  }

  CapacityMetrics forRun(String id) {
    final selected = phases.where((p) => p['run_id'] == id).toList();
    final jobs = selected.map((p) => p['job_id']).toSet();
    return CapacityMetrics(
      selected,
      limits.where((l) => jobs.contains(l['job_id'])).toList(),
      now: now,
    );
  }

  CapacityMetrics phase(String key) {
    final selected = phases.where((p) => p['phase_key'] == key).toList();
    final jobs = selected.map((p) => p['job_id']).toSet();
    return CapacityMetrics(
      selected,
      limits.where((l) => jobs.contains(l['job_id'])).toList(),
      now: now,
    );
  }

  DateTime? get start {
    final dates =
        attempts.map((a) => time(a['startedAt'])).whereType<DateTime>().toList()
          ..sort();
    return dates.firstOrNull;
  }

  bool get active => phases.any(
    (p) => !['SUCCEEDED', 'FAILED', 'CANCELLED', 'RETRY'].contains(p['status']),
  );
  DateTime? get end {
    if (active) return null;
    final dates =
        attempts
            .map((a) => time(a['completedAt']))
            .whereType<DateTime>()
            .toList()
          ..sort();
    return dates.lastOrNull;
  }

  Duration? get executionDuration {
    if (attempts.isEmpty) return null;
    var total = Duration.zero;
    for (final a in attempts) {
      final from = time(a['startedAt']);
      final to =
          time(a['completedAt']) ?? (a['status'] == 'RUNNING' ? now : null);
      if (from == null || to == null) return null;
      total += to.difference(from);
    }
    return total.isNegative ? Duration.zero : total;
  }

  Duration? get firstDuration =>
      keys.isEmpty ? null : phase(keys.first).executionDuration;
  static Duration? elapsed(
    dynamic from,
    dynamic to, {
    DateTime? now,
    bool active = false,
  }) {
    final start = time(from),
        end = time(to) ?? (active ? now ?? DateTime.now() : null);
    return start == null || end == null ? null : end.difference(start);
  }

  static String duration(Duration? d) {
    if (d == null) return 'Onbekend';
    final s = d.inSeconds.clamp(0, 999999999);
    if (s < 60) return '$s sec';
    if (s < 3600) return '${s ~/ 60} min ${s % 60} sec';
    return '${s ~/ 3600} uur ${(s % 3600) ~/ 60} min';
  }

  static String date(dynamic value, {bool compact = false}) {
    final d = time(value)?.toLocal();
    if (d == null) return '—';
    String pad(int n) => '$n'.padLeft(2, '0');
    final day = '${pad(d.day)}-${pad(d.month)}${compact ? '' : '-${d.year}'}';
    return '$day${compact ? '\n' : ' '}${pad(d.hour)}:${pad(d.minute)}:${pad(d.second)}';
  }

  static String phaseName(String key) {
    if (key.endsWith('-direct')) return 'Onderzoek richten';
    if (key.endsWith('-plan')) return 'Zoektermen bepalen';
    if (key.endsWith('-write')) return 'Antwoord schrijven';
    if (key.endsWith('-expand')) return 'Antwoord uitwerken';
    return 'Onderzoek uitvoeren';
  }

  static String status(dynamic status) =>
      const {
        'RUNNING': 'Bezig',
        'WAITING_FOR_WORKER': 'Wacht op worker',
        'QUEUED': 'In wachtrij',
        'SUBMITTING': 'Voorbereiden',
        'SUCCEEDED': 'Geslaagd',
        'FAILED': 'Mislukt',
        'RETRY': 'Wacht op herstel',
        'CANCELLED': 'Onderbroken',
        'ACTIVE': 'Bezig',
      }[status] ??
      '$status';
}
