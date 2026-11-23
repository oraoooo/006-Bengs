import 'package:bengs/utils/age.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateAge (BR-01/BR-02 gating)', () {
    test('birthday already passed this year', () {
      expect(calculateAge(DateTime(2008, 1, 1), DateTime(2026, 6, 1)), 18);
    });

    test('birthday later this year — not counted yet', () {
      expect(calculateAge(DateTime(2008, 12, 31), DateTime(2026, 6, 1)), 17);
    });

    test('birthday is today', () {
      expect(calculateAge(DateTime(2013, 6, 1), DateTime(2026, 6, 1)), 13);
    });

    test('one day before 18th birthday', () {
      expect(calculateAge(DateTime(2008, 6, 2), DateTime(2026, 6, 1)), 17);
    });
  });
}
