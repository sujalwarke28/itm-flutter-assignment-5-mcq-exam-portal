import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/utils/app_theme.dart';

void main() {
  test('AppSpacing scale is monotonically increasing', () {
    expect(AppSpacing.xs < AppSpacing.sm, isTrue);
    expect(AppSpacing.sm < AppSpacing.md, isTrue);
    expect(AppSpacing.md < AppSpacing.lg, isTrue);
    expect(AppSpacing.lg < AppSpacing.xl, isTrue);
  });
}
