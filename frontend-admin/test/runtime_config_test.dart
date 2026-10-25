import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_admin/config/app_config.dart';

void main() {
  test(
    'production keeps login enabled, acceptance uses same-origin preview',
    () {
      final production = RuntimeConfig.fromJson({
        'apiBaseUrl': '',
        'googleClientId': 'public-client-id',
        'previewMode': false,
      });
      final acceptance = RuntimeConfig.fromJson({
        'apiBaseUrl': '',
        'googleClientId': '',
        'previewMode': true,
      });
      expect(production.previewMode, isFalse);
      expect(production.googleClientId, isNotEmpty);
      expect(acceptance.apiBaseUrl, isEmpty);
      expect(acceptance.previewMode, isTrue);
    },
  );

  test('missing or mistyped preview setting cannot enable preview', () {
    for (final value in [null, 'true', 1]) {
      expect(
        () => RuntimeConfig.fromJson({
          'apiBaseUrl': '',
          'googleClientId': '',
          'previewMode': value,
        }),
        throwsFormatException,
      );
    }
  });
}
