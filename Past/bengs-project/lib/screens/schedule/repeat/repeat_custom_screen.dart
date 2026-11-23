import 'package:flutter/cupertino.dart';
import '../../../models/repeat_rule.dart';
import '../../../theme/app_colors.dart';

/// The "Custom" screen from docs/BENGS_Repeat_picker_revised.html — Frequency
/// + Every-N stepper + a multi-select whose shape depends on frequency
/// (weekdays / month-days / months), with a live plain-English summary.
/// Built with Cupertino widgets deliberately: this picker is copying an
/// iOS-native interaction (Reminders' Custom Repeat screen) down to the
/// stepper and grouped-list styling, so it should feel like one.
class RepeatCustomScreen extends StatefulWidget {
  const RepeatCustomScreen({super.key, required this.initial, required this.startDate});

  final RepeatRule initial;
  final DateTime startDate;

  @override
  State<RepeatCustomScreen> createState() => _RepeatCustomScreenState();
}

class _RepeatCustomScreenState extends State<RepeatCustomScreen> {
  late RepeatRule _rule;

  @override
  void initState() {
    super.initState();
    _rule = widget.initial.frequency == RepeatFrequency.never
        ? widget.initial.copyWith(frequency: RepeatFrequency.weekly, weekdays: {weekdayCodes[widget.startDate.weekday % 7]})
        : widget.initial;
  }

  Future<void> _pickFrequency() async {
    final options = [RepeatFrequency.daily, RepeatFrequency.weekly, RepeatFrequency.monthly, RepeatFrequency.yearly];
    var selected = _rule.frequency;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 260,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            SizedBox(
              height: 216,
              child: CupertinoPicker(
                itemExtent: 36,
                scrollController: FixedExtentScrollController(initialItem: options.indexOf(_rule.frequency)),
                onSelectedItemChanged: (i) => selected = options[i],
                children: options.map((f) => Center(child: Text(_frequencyLabel(f)))).toList(),
              ),
            ),
            CupertinoButton(
              child: const Text('Done'),
              onPressed: () {
                setState(() => _rule = _rule.copyWith(frequency: selected));
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _frequencyLabel(RepeatFrequency f) => switch (f) {
        RepeatFrequency.never => 'Never',
        RepeatFrequency.daily => 'Daily',
        RepeatFrequency.weekly => 'Weekly',
        RepeatFrequency.monthly => 'Monthly',
        RepeatFrequency.yearly => 'Yearly',
      };

  void _toggleWeekday(String code) {
    setState(() {
      final next = {..._rule.weekdays};
      next.contains(code) ? next.remove(code) : next.add(code);
      _rule = _rule.copyWith(weekdays: next);
    });
  }

  void _toggleMonthDay(int day) {
    setState(() {
      final next = {..._rule.monthDays};
      next.contains(day) ? next.remove(day) : next.add(day);
      _rule = _rule.copyWith(monthDays: next);
    });
  }

  void _toggleMonth(int month) {
    setState(() {
      final next = {..._rule.months};
      next.contains(month) ? next.remove(month) : next.add(month);
      _rule = _rule.copyWith(months: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Custom'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(_rule),
          child: const Text('Done'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(children: [
              _Row(
                label: 'Frequency',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_frequencyLabel(_rule.frequency), style: const TextStyle(color: CupertinoColors.systemGrey)),
                    const Icon(CupertinoIcons.chevron_right, size: 14, color: CupertinoColors.systemGrey),
                  ],
                ),
                onTap: _pickFrequency,
              ),
              _Row(
                label: 'Every',
                trailing: CupertinoStepper(
                  value: _rule.every,
                  onChanged: (v) => setState(() => _rule = _rule.copyWith(every: v)),
                ),
              ),
            ]),
            if (_rule.frequency == RepeatFrequency.weekly) ...[
              const _SectionLabel('On these days'),
              _Card(
                children: weekdayCodes.asMap().entries.map((e) {
                  final code = e.value;
                  final selected = _rule.weekdays.contains(code);
                  return _Row(
                    label: weekdayLabels[e.key],
                    bold: selected,
                    trailing: selected ? const Icon(CupertinoIcons.check_mark, size: 16, color: AppColors.primaryBlue) : null,
                    onTap: () => _toggleWeekday(code),
                  );
                }).toList(),
              ),
            ],
            if (_rule.frequency == RepeatFrequency.monthly) ...[
              const _SectionLabel('On these days of the month'),
              _Card(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(31, (i) => i + 1).map((day) {
                        final selected = _rule.monthDays.contains(day);
                        return GestureDetector(
                          onTap: () => _toggleMonthDay(day),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primaryBlue : CupertinoColors.systemGrey6,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$day',
                              style: TextStyle(fontSize: 12, color: selected ? CupertinoColors.white : AppColors.navyText),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
            if (_rule.frequency == RepeatFrequency.yearly) ...[
              const _SectionLabel('In these months'),
              _Card(
                children: List.generate(12, (i) => i + 1).map((month) {
                  final selected = _rule.months.contains(month);
                  return _Row(
                    label: monthLabels[month - 1],
                    bold: selected,
                    trailing: selected ? const Icon(CupertinoIcons.check_mark, size: 16, color: AppColors.primaryBlue) : null,
                    onTap: () => _toggleMonth(month),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _rule.summary(widget.startDate),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
            ),
          ],
        ),
      ),
    );
  }
}

class CupertinoStepper extends StatelessWidget {
  const CupertinoStepper({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepButton(context, '-', () => onChanged(value > 1 ? value - 1 : 1)),
        SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        _stepButton(context, '+', () => onChanged(value + 1)),
      ],
    );
  }

  Widget _stepButton(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: CupertinoColors.systemGrey4),
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(color: AppColors.primaryBlue)),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: const Color(0xFFF7F8FC), borderRadius: BorderRadius.circular(12)),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.trailing, this.onTap, this.bold = false});

  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE8E8ED), width: 0.5))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: AppColors.navyText)),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, color: CupertinoColors.systemGrey, letterSpacing: 0.3)),
    );
  }
}
