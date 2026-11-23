import 'package:flutter/material.dart';
import '../../models/schedule_entry.dart';
import '../../services/driver_repository.dart';
import '../../services/schedule_repository.dart';
import '../../theme/app_colors.dart';
import '../driver/driver_onboarding_gate.dart';
import '../find/find_beng_screen.dart';
import 'add_beng_screen.dart';
import 'route_timeline_screen.dart';

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The old calendar/list Home from bengs01.pdf, relabeled "Schedule" per
/// CLAUDE.md — same content, unchanged. Shows every upcoming beng_daily the
/// user is on, as driver or accepted passenger.
class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  late Future<List<ScheduleEntry>> _future;
  String _query = '';
  bool _showPast = false;
  bool _calendarView = true;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _future = ScheduleRepository.getUpcoming();
  }

  Future<void> _refresh() async {
    setState(() => _future = _showPast ? ScheduleRepository.getPast() : ScheduleRepository.getUpcoming());
    await _future;
  }

  void _setShowPast(bool value) {
    setState(() {
      _showPast = value;
      _future = value ? ScheduleRepository.getPast() : ScheduleRepository.getUpcoming();
    });
  }

  /// BR-03/BR-04 — posting a beng requires driver verification, same gate
  /// the spontaneous Home tab's "Offer a ride" uses. Add-a-Beng used to skip
  /// this check entirely and just throw a raw "No default vehicle" error.
  Future<void> _addBeng() async {
    final status = await DriverRepository.getVerificationStatus();
    if (!mounted) return;
    if (status != 'verified') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DriverOnboardingGate()));
      return;
    }
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AddBengScreen()));
    if (added == true) _refresh();
  }

  bool _matches(ScheduleEntry e, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return (e.label?.toLowerCase().contains(q) ?? false) ||
        e.originName.toLowerCase().contains(q) ||
        (e.destinationName?.toLowerCase().contains(q) ?? false);
  }

  String _dateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    final weekday = _weekdayNames[date.weekday - 1];
    final formatted = '$weekday ${date.day} ${_monthNames[date.month - 1]} ${date.year}';
    return isToday ? 'Today - $formatted' : formatted;
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _monthCalendar(List<ScheduleEntry> entries) {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final startWeekday = first.weekday; // Mon=1
    final marked = {
      for (final e in entries)
        if (e.date.year == _visibleMonth.year && e.date.month == _visibleMonth.month) e.date.day,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.navyText),
                onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
              ),
              Text(
                '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navyText),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.navyText),
                onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
              ),
            ],
          ),
          Row(
            children: [
              for (final d in _weekdayNames)
                Expanded(
                  child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startWeekday - 1 + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisExtent: 36),
            itemBuilder: (context, index) {
              if (index < startWeekday - 1) return const SizedBox.shrink();
              final day = index - (startWeekday - 1) + 1;
              final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
              final selected = _selectedDay != null && _isSameDay(_selectedDay!, date);
              final hasEvent = marked.contains(day);
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = selected ? null : date),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primaryBlue : (hasEvent ? AppColors.sheetLavender : Colors.transparent),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: hasEvent ? FontWeight.w700 : FontWeight.w400,
                        color: selected ? Colors.white : AppColors.navyText,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundIconButton(
                  icon: Icons.add,
                  background: AppColors.primaryBlue,
                  iconColor: Colors.white,
                  onTap: _addBeng,
                ),
                Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.calendar_today_outlined,
                      background: _calendarView ? AppColors.navyText : const Color(0xFFF1F1F1),
                      iconColor: _calendarView ? Colors.white : AppColors.navyText,
                      onTap: () => setState(() => _calendarView = true),
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      icon: Icons.list,
                      background: _calendarView ? const Color(0xFFF1F1F1) : AppColors.navyText,
                      iconColor: _calendarView ? AppColors.navyText : Colors.white,
                      onTap: () => setState(() {
                        _calendarView = false;
                        _selectedDay = null;
                      }),
                    ),
                  ],
                ),
                _RoundIconButton(
                  icon: Icons.navigation_outlined,
                  background: AppColors.amber,
                  iconColor: AppColors.navyText,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FindBengScreen()),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFFF1F1F1),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                _ToggleChip(label: 'Upcoming', isSelected: !_showPast, onTap: () => _setShowPast(false)),
                const SizedBox(width: 8),
                _ToggleChip(label: 'Past', isSelected: _showPast, onTap: () => _setShowPast(true)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<ScheduleEntry>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ScrollableMessage(text: 'Could not load your schedule: ${snapshot.error}');
                  }
                  final entries = (snapshot.data ?? []).where((e) {
                    if (!_matches(e, _query)) return false;
                    if (_selectedDay == null) return true;
                    return _isSameDay(e.date, _selectedDay!);
                  }).toList();
                  if (entries.isEmpty && !_calendarView) {
                    return _ScrollableMessage(text: _showPast ? 'No past bengs yet.' : "No upcoming bengs. Oops! Let's find other bengs!");
                  }

                  final grouped = <String, List<ScheduleEntry>>{};
                  for (final entry in entries) {
                    grouped.putIfAbsent(_dateHeader(entry.date), () => []).add(entry);
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      if (_calendarView) _monthCalendar(snapshot.data ?? []),
                      if (entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            _showPast ? 'No past bengs yet.' : "No upcoming bengs. Oops! Let's find other bengs!",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.mutedText),
                          ),
                        ),
                      for (final group in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            group.key,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navyText),
                          ),
                        ),
                        for (final entry in group.value) ...[
                          _ScheduleCard(entry: entry, isPast: _showPast, onChanged: _refresh),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollableMessage extends StatelessWidget {
  const _ScrollableMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.mutedText)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.entry, required this.isPast, required this.onChanged});

  final ScheduleEntry entry;
  final bool isPast;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    // bengs01.pdf's actual Schedule cards (not the rougher draft notes) tint
    // the whole card — light blue wash for a driver's own beng, light amber
    // for a passenger's — rather than just a thin accent border.
    final isDriver = entry.role == ScheduleRole.driver;
    final background = isDriver ? AppColors.sheetLavender : AppColors.amber.withValues(alpha: 0.18);

    Future<void> openTimeline() async {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RouteTimelineScreen(
            bengDailyId: entry.bengDailyId,
            isOwnerDriver: isDriver && !isPast,
            isPast: isPast,
            bengId: entry.bengId,
            title: entry.label ?? (isDriver ? 'Your Beng' : "${entry.counterpartName ?? 'Driver'}'s Beng"),
          ),
        ),
      );
      if (changed == true) onChanged();
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: openTimeline,
      child: Container(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.my_location, size: 14, color: AppColors.iconBlue),
                          const SizedBox(width: 6),
                          Text(entry.departTime, style: const TextStyle(fontSize: 12, color: AppColors.navyText)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(entry.originName, style: const TextStyle(fontSize: 12, color: AppColors.mutedText), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (entry.destinationName != null)
                        Row(
                          children: [
                            const Icon(Icons.flag_outlined, size: 14, color: AppColors.mapPinRed),
                            const SizedBox(width: 6),
                            Expanded(child: Text(entry.destinationName!, style: const TextStyle(fontSize: 12, color: AppColors.mutedText), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entry.label ?? (isDriver ? 'Your Beng' : "${entry.counterpartName ?? 'Driver'}'s Beng"),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navyText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDriver ? (entry.vehicleLabel ?? 'Driving') : (entry.counterpartName ?? 'Passenger'),
                      style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isDriver && entry.passengerNames.isNotEmpty) _AvatarStack(names: entry.passengerNames) else const SizedBox.shrink(),
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    onPressed: openTimeline,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.navyText,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Check out!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small overlapping initials-avatar stack for who's on a driver's ride —
/// bengs01.pdf shows real photo avatars here, but there's no avatar-photo
/// field anywhere in the schema (profiles has no avatar_url column), so
/// this is initials-in-a-circle rather than a fabricated photo.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    const maxShown = 4;
    final shown = names.take(maxShown).toList();
    final overflow = names.length - shown.length;
    return SizedBox(
      height: 24,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 16.0,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.primaryBlue,
                  child: Text(shown[i][0].toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: shown.length * 16.0,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.navyText,
                  child: Text('+$overflow', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.background, required this.iconColor, required this.onTap});

  final IconData icon;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.mutedText,
          ),
        ),
      ),
    );
  }
}
