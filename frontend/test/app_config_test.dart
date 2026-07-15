import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/config/app_config.dart';

void main() {
  test('requires an explicit tenant outside local development', () {
    expect(AppConfig.tenantSlug, isEmpty);

    expect(
      AppConfig.validateRequiredConfig,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('TENANT_SLUG'),
        ),
      ),
    );
  });
}
