/// The recurrence a scheduled beng repeats on — mirrors the native iOS
/// Reminders/Calendar pattern (Repeat list → Custom screen) per CLAUDE.md,
/// and maps 1:1 onto `beng`'s repeat_* JSONB columns.
enum RepeatFrequency { never, daily, weekly, monthly, yearly }

const weekdayCodes = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];
const weekdayLabels = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const monthLabels = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class RepeatRule {
  const RepeatRule({
    this.frequency = RepeatFrequency.never,
    this.every = 1,
    this.weekdays = const {},
    this.monthDays = const {},
    this.months = const {},
  });

  final RepeatFrequency frequency;
  final int every;

  /// Weekly only — two-letter codes ("SU".."SA"), matching repeat_weekdays.
  final Set<String> weekdays;

  /// Monthly only — days of the month (1-31), matching repeat_month_days.
  final Set<int> monthDays;

  /// Yearly only — months (1-12), matching repeat_months.
  final Set<int> months;

  RepeatRule copyWith({
    RepeatFrequency? frequency,
    int? every,
    Set<String>? weekdays,
    Set<int>? monthDays,
    Set<int>? months,
  }) {
    return RepeatRule(
      frequency: frequency ?? this.frequency,
      every: every ?? this.every,
      weekdays: weekdays ?? this.weekdays,
      monthDays: monthDays ?? this.monthDays,
      months: months ?? this.months,
    );
  }

  Map<String, dynamic> toBengFields() {
    if (frequency == RepeatFrequency.never) {
      return {'repeat_frequency': 'never', 'repeat_every': 1};
    }
    return {
      'repeat_frequency': frequency.name,
      'repeat_every': every,
      if (frequency == RepeatFrequency.weekly && weekdays.isNotEmpty) 'repeat_weekdays': weekdays.toList(),
      if (frequency == RepeatFrequency.monthly && monthDays.isNotEmpty) 'repeat_month_days': monthDays.toList()..sort(),
      if (frequency == RepeatFrequency.yearly && months.isNotEmpty) 'repeat_months': (months.toList()..sort()),
    };
  }

  String summary(DateTime startDate) {
    switch (frequency) {
      case RepeatFrequency.never:
        return "Doesn't repeat";
      case RepeatFrequency.daily:
        return every == 1 ? 'Repeats every day' : 'Repeats every $every days';
      case RepeatFrequency.weekly:
        final dayNames = weekdays.isEmpty
            ? [weekdayLabels[startDate.weekday % 7]]
            : (weekdays.toList()..sort((a, b) => weekdayCodes.indexOf(a).compareTo(weekdayCodes.indexOf(b))))
                .map((c) => weekdayLabels[weekdayCodes.indexOf(c)])
                .toList();
        final days = dayNames.length <= 2 ? dayNames.join(' and ') : '${dayNames.sublist(0, dayNames.length - 1).join(', ')} and ${dayNames.last}';
        final cadence = every == 1 ? 'every week' : 'every $every weeks';
        return 'Repeats $cadence on $days';
      case RepeatFrequency.monthly:
        final days = monthDays.isEmpty ? '${startDate.day}' : (monthDays.toList()..sort()).join(', ');
        final cadence = every == 1 ? 'every month' : 'every $every months';
        return 'Repeats $cadence on day $days';
      case RepeatFrequency.yearly:
        final list = months.isEmpty
            ? monthLabels[startDate.month - 1]
            : (months.toList()..sort()).map((m) => monthLabels[m - 1]).join(', ');
        final cadence = every == 1 ? 'every year' : 'every $every years';
        return 'Repeats $cadence in $list';
    }
  }

  /// Concrete occurrence dates from [startDate], stopping at whichever comes
  /// first: [endDate], or [maxOccurrences] — a hard cap so a "Weekly forever"
  /// rule can't blow up beng_daily with unbounded rows before v2's proper
  /// occurrence-window job exists.
  List<DateTime> occurrences({
    required DateTime startDate,
    DateTime? endDate,
    int maxOccurrences = 52,
  }) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (frequency == RepeatFrequency.never) return [start];

    final limit = endDate ?? start.add(const Duration(days: 366));
    final result = <DateTime>[];

    switch (frequency) {
      case RepeatFrequency.never:
        break;
      case RepeatFrequency.daily:
        var d = start;
        while (!d.isAfter(limit) && result.length < maxOccurrences) {
          result.add(d);
          d = d.add(Duration(days: every));
        }
        break;
      case RepeatFrequency.weekly:
        final targetCodes = weekdays.isEmpty ? {weekdayCodes[start.weekday % 7]} : weekdays;
        var weekStart = start.subtract(Duration(days: start.weekday % 7));
        while (!weekStart.isAfter(limit) && result.length < maxOccurrences) {
          for (var i = 0; i < 7; i++) {
            final day = weekStart.add(Duration(days: i));
            if (day.isBefore(start) || day.isAfter(limit)) continue;
            if (targetCodes.contains(weekdayCodes[day.weekday % 7])) {
              result.add(day);
              if (result.length >= maxOccurrences) break;
            }
          }
          weekStart = weekStart.add(Duration(days: 7 * every));
        }
        result.sort();
        break;
      case RepeatFrequency.monthly:
        final targetDays = monthDays.isEmpty ? {start.day} : monthDays;
        var monthCursor = DateTime(start.year, start.month, 1);
        while (!monthCursor.isAfter(limit) && result.length < maxOccurrences) {
          final daysInMonth = DateTime(monthCursor.year, monthCursor.month + 1, 0).day;
          final candidates = targetDays.where((d) => d <= daysInMonth).toList()..sort();
          for (final d in candidates) {
            final day = DateTime(monthCursor.year, monthCursor.month, d);
            if (day.isBefore(start) || day.isAfter(limit)) continue;
            result.add(day);
            if (result.length >= maxOccurrences) break;
          }
          monthCursor = DateTime(monthCursor.year, monthCursor.month + every, 1);
        }
        break;
      case RepeatFrequency.yearly:
        final targetMonths = months.isEmpty ? {start.month} : months;
        var yearCursor = start.year;
        while (DateTime(yearCursor, 1, 1).isBefore(limit.add(const Duration(days: 1))) && result.length < maxOccurrences) {
          final candidates = targetMonths.toList()..sort();
          for (final m in candidates) {
            final daysInMonth = DateTime(yearCursor, m + 1, 0).day;
            final day = DateTime(yearCursor, m, start.day.clamp(1, daysInMonth));
            if (day.isBefore(start) || day.isAfter(limit)) continue;
            result.add(day);
            if (result.length >= maxOccurrences) break;
          }
          yearCursor += every;
        }
        break;
    }

    return result.isEmpty ? [start] : result;
  }
}
