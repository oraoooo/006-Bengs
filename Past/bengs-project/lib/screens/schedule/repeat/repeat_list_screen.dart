import 'package:flutter/cupertino.dart';
import '../../../models/repeat_rule.dart';
import 'repeat_custom_screen.dart';

/// The "Repeat" list from docs/BENGS_Repeat_picker_revised.html — canned
/// presets over the same frequency/every/weekdays model Custom edits
/// directly, matching the native iOS Reminders Repeat screen CLAUDE.md
/// calls for. "Hourly" from the mockup is dropped: a ride can't recur
/// hourly and the schema has no column for it.
class RepeatListScreen extends StatelessWidget {
  const RepeatListScreen({super.key, required this.initial, required this.startDate});

  final RepeatRule initial;
  final DateTime startDate;

  static final _presets = <String, RepeatRule>{
    'Never': const RepeatRule(),
    'Daily': const RepeatRule(frequency: RepeatFrequency.daily),
    'Weekdays': const RepeatRule(frequency: RepeatFrequency.weekly, weekdays: {'MO', 'TU', 'WE', 'TH', 'FR'}),
    'Weekends': const RepeatRule(frequency: RepeatFrequency.weekly, weekdays: {'SA', 'SU'}),
    'Weekly': const RepeatRule(frequency: RepeatFrequency.weekly),
    'Biweekly': const RepeatRule(frequency: RepeatFrequency.weekly, every: 2),
    'Monthly': const RepeatRule(frequency: RepeatFrequency.monthly),
    'Every 3 months': const RepeatRule(frequency: RepeatFrequency.monthly, every: 3),
    'Every 6 months': const RepeatRule(frequency: RepeatFrequency.monthly, every: 6),
    'Yearly': const RepeatRule(frequency: RepeatFrequency.yearly),
  };

  bool _matchesPreset(RepeatRule preset) =>
      preset.frequency == initial.frequency &&
      preset.every == initial.every &&
      preset.weekdays.difference(initial.weekdays).isEmpty &&
      initial.weekdays.difference(preset.weekdays).isEmpty;

  @override
  Widget build(BuildContext context) {
    final isCustom = !_presets.values.any(_matchesPreset);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Repeat')),
      child: SafeArea(
        child: ListView(
          children: [
            for (final entry in _presets.entries)
              _row(
                context,
                label: entry.key,
                selected: !isCustom && _matchesPreset(entry.value),
                onTap: () => Navigator.of(context).pop(entry.value),
              ),
            _row(
              context,
              label: 'Custom',
              selected: isCustom,
              trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: CupertinoColors.systemGrey),
              onTap: () async {
                final result = await Navigator.of(context).push<RepeatRule>(
                  CupertinoPageRoute(builder: (_) => RepeatCustomScreen(initial: initial, startDate: startDate)),
                );
                if (result != null && context.mounted) Navigator.of(context).pop(result);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5F8FF) : CupertinoColors.systemBackground.resolveFrom(context),
          border: const Border(bottom: BorderSide(color: Color(0xFFF3F3F3), width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? const Color(0xFF1D5BFE) : const Color(0xFF0F1330),
              ),
            ),
            trailing ?? (selected ? const Icon(CupertinoIcons.check_mark, size: 15, color: Color(0xFF1D5BFE)) : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
