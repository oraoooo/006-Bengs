import 'package:flutter_test/flutter_test.dart';
import 'package:bengs/models/repeat_rule.dart';

void main() {
  group('RepeatRule.occurrences', () {
    test('never yields exactly the start date', () {
      final start = DateTime(2026, 9, 3);
      final occurrences = const RepeatRule().occurrences(startDate: start);
      expect(occurrences, [start]);
    });

    test('weekly on Sun+Thu matches the mockup summary exactly', () {
      final start = DateTime(2026, 9, 3); // a Thursday
      const rule = RepeatRule(frequency: RepeatFrequency.weekly, weekdays: {'SU', 'TH'});
      final occurrences = rule.occurrences(startDate: start, endDate: DateTime(2026, 9, 17));

      expect(occurrences, everyElement(predicate<DateTime>((d) => !d.isBefore(start))));
      expect(occurrences.map((d) => d.weekday).toSet(), {DateTime.thursday, DateTime.sunday});
      expect(rule.summary(start), 'Repeats every week on Sunday and Thursday');
    });

    test('biweekly steps by 2 weeks, not 1', () {
      final start = DateTime(2026, 9, 3); // Thursday
      const rule = RepeatRule(frequency: RepeatFrequency.weekly, every: 2, weekdays: {'TH'});
      final occurrences = rule.occurrences(startDate: start, endDate: DateTime(2026, 10, 15));

      for (var i = 1; i < occurrences.length; i++) {
        expect(occurrences[i].difference(occurrences[i - 1]).inDays, 14);
      }
    });

    test('monthly on specific days of month', () {
      final start = DateTime(2026, 9, 1);
      const rule = RepeatRule(frequency: RepeatFrequency.monthly, monthDays: {1, 15});
      final occurrences = rule.occurrences(startDate: start, endDate: DateTime(2026, 11, 30));

      expect(occurrences, [
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 15),
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 15),
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 15),
      ]);
    });

    test('occurrence generation is capped so an unbounded rule cannot flood beng_daily', () {
      final start = DateTime(2026, 1, 1);
      const rule = RepeatRule(frequency: RepeatFrequency.daily);
      final occurrences = rule.occurrences(startDate: start, endDate: DateTime(2030, 1, 1), maxOccurrences: 10);
      expect(occurrences.length, 10);
    });
  });
}
