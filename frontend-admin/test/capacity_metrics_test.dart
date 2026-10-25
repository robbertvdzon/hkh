import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_admin/ai/capacity_metrics.dart';

Map<String, dynamic> attempt(
  String status,
  String start,
  String end, {
  String? error,
}) => {
  'status': status,
  'startedAt': start,
  'completedAt': end,
  'errorCode': error,
};
List<Map<String, dynamic>> samplePhases() => [
  {
    'run_id': 'r1',
    'phase_key': 'hkh-capacity-one-direct',
    'job_id': 'j1',
    'status': 'SUCCEEDED',
    'attempts': [
      attempt('SUCCEEDED', '2026-10-25T12:18:06Z', '2026-10-25T12:18:58Z'),
    ],
  },
  {
    'run_id': 'r1',
    'phase_key': 'hkh-capacity-one-write',
    'job_id': 'j2',
    'status': 'SUCCEEDED',
    'usage': {'attemptCount': 2},
    'attempts': [
      attempt(
        'FAILED',
        '2026-10-25T12:18:59Z',
        '2026-10-25T12:19:09Z',
        error: 'PROVIDER_RATE_LIMIT',
      ),
      attempt('SUCCEEDED', '2026-10-25T12:21:00Z', '2026-10-25T12:21:49Z'),
    ],
  },
];
void main() {
  test('provider warnings do not count as a reached limit', () {
    final m = CapacityMetrics([], [
      {
        'observation': {'kind': 'WEEK', 'blocked': false},
      },
    ]);
    expect(m.limitLabel, 'Geen waargenomen');
  });
  test(
    'logical AI runs, retries and recovered errors are counted separately',
    () {
      final m = CapacityMetrics(samplePhases(), [
        {
          'job_id': 'j2',
          'observation': {'kind': 'SHORT_WINDOW'},
        },
      ]);
      expect(m.runs, 2);
      expect(m.attemptCount, 3);
      expect(m.retries, 1);
      expect(m.errorsLabel('SUCCEEDED'), '1 hersteld');
      expect(m.firstDuration, const Duration(seconds: 52));
      expect(
        m.phase('hkh-capacity-one-write').executionDuration,
        const Duration(seconds: 59),
      );
      expect(m.limitLabel, 'Kort venster');
      expect(
        CapacityMetrics.elapsed('2026-10-25T12:18:06Z', '2026-10-25T12:21:49Z'),
        const Duration(seconds: 223),
      );
    },
  );
  test(
    'explicit phase generations do not count as additional logical AI runs',
    () {
      final m = CapacityMetrics([
        {
          'phase_key': 'same',
          'job_id': 'j1',
          'status': 'RETRY',
          'attempts': [
            attempt('FAILED', '2026-10-25T12:00:00Z', '2026-10-25T12:00:02Z'),
          ],
        },
        {
          'phase_key': 'same',
          'job_id': 'j2',
          'status': 'SUCCEEDED',
          'attempts': [
            attempt(
              'SUCCEEDED',
              '2026-10-25T12:01:00Z',
              '2026-10-25T12:01:03Z',
            ),
          ],
        },
      ], []);
      expect(m.runs, 1);
      expect(m.retries, 1);
      expect(m.firstDuration, const Duration(seconds: 5));
      expect(m.errors, 1);
    },
  );
  test(
    'unknown durations stay unknown and limits cannot leak across scenarios',
    () {
      final m = CapacityMetrics(
        [
          ...samplePhases(),
          {
            'run_id': 'r2',
            'phase_key': 'unknown',
            'job_id': 'j3',
            'status': 'RUNNING',
          },
        ],
        [
          {
            'job_id': 'j2',
            'observation': {'kind': 'WEEK'},
          },
        ],
      );
      expect(m.forRun('r2').firstDuration, isNull);
      expect(CapacityMetrics.duration(null), 'Onbekend');
      expect(m.forRun('r2').end, isNull);
      expect(m.forRun('r2').limitLabel, 'Geen waargenomen');
      expect(m.forRun('r1').limitLabel, 'Week');
    },
  );
  test(
    'active elapsed duration updates while a completed duration remains fixed',
    () {
      expect(
        CapacityMetrics.elapsed(
          '2026-10-25T12:00:00Z',
          null,
          active: true,
          now: DateTime.parse('2026-10-25T12:02:03Z'),
        ),
        const Duration(seconds: 123),
      );
      expect(CapacityMetrics.elapsed('2026-10-25T12:00:00Z', null), isNull);
      expect(CapacityMetrics.status('WAITING_FOR_WORKER'), 'Wacht op worker');
    },
  );
}
