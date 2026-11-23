import 'package:flutter/material.dart';
import '../../services/notification_repository.dart';
import '../../services/request_repository.dart';
import '../../theme/app_colors.dart';
import '../requests/reviewing_screen.dart';

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Notification tab ("Inbox" per the 5-tab nav) — bengs01.pdf's Notification
/// screen has three sections: "Requests of Your Bengs" (pending requests
/// against your own bengs — driver side, BR-10), "Your Request" (your own
/// outstanding requests as a passenger), and a date-grouped activity feed
/// below that. Only the feed existed before this — the two pending-request
/// sections are net new, since nothing anywhere aggregated a passenger's
/// own sent requests into one list.
class InboxTab extends StatefulWidget {
  const InboxTab({super.key});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  late Future<List<Map<String, dynamic>>> _incomingRequestsFuture;
  late Future<List<Map<String, dynamic>>> _myRequestsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = NotificationRepository.getMyNotifications();
    _incomingRequestsFuture = RequestRepository.getIncomingRequests();
    _myRequestsFuture = RequestRepository.getMyPendingRequests();
  }

  Future<void> _refresh() async {
    setState(() {
      _notificationsFuture = NotificationRepository.getMyNotifications();
      _incomingRequestsFuture = RequestRepository.getIncomingRequests();
      _myRequestsFuture = RequestRepository.getMyPendingRequests();
    });
    await Future.wait([_notificationsFuture, _incomingRequestsFuture, _myRequestsFuture]);
  }

  Future<void> _onTapNotification(Map<String, dynamic> notification) async {
    if (notification['is_read'] == true) return;
    await NotificationRepository.markAsRead(notification['id'] as String);
    _refresh();
  }

  String _dateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    final weekday = _weekdayNames[date.weekday - 1];
    final formatted = '$weekday ${date.day} ${_monthNames[date.month - 1]} ${date.year}';
    return isToday ? 'Today – $formatted' : formatted;
  }

  /// PDF shows a countdown ("3 Hours Left") but that's only meaningful when
  /// there's an actual deadline — response_deadline is spontaneous-only in
  /// the schema, so a scheduled request (the only kind requestable today)
  /// shows how long ago it was sent instead of fabricating a countdown that
  /// isn't backed by any real deadline.
  String _timingLabel(Map<String, dynamic> request) {
    final deadline = request['response_deadline'] as String?;
    if (deadline != null) {
      final remaining = DateTime.parse(deadline).difference(DateTime.now());
      if (remaining.isNegative) return 'Expired';
      if (remaining.inHours < 1) return '${remaining.inMinutes} min left';
      if (remaining.inHours < 24) return '${remaining.inHours}h left';
      return '${remaining.inDays}d left';
    }
    final sentAgo = DateTime.now().difference(DateTime.parse(request['created_at'] as String));
    if (sentAgo.inHours < 1) return 'Sent ${sentAgo.inMinutes}m ago';
    if (sentAgo.inHours < 24) return 'Sent ${sentAgo.inHours}h ago';
    return 'Sent ${sentAgo.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _PendingSection(
              title: 'Requests of Your Bengs',
              future: _incomingRequestsFuture,
              rowBuilder: (r) => _PendingRow(
                title: r['beng_daily']?['beng']?['label'] as String? ?? 'Your Beng',
                timing: _timingLabel(r),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewingScreen())).then((_) => _refresh()),
              ),
            ),
            _PendingSection(
              title: 'Your Request',
              future: _myRequestsFuture,
              rowBuilder: (r) {
                final beng = r['beng_daily']?['beng'] as Map<String, dynamic>?;
                final driverName = (beng?['driver'] as Map<String, dynamic>?)?['first_name'] as String?;
                return _PendingRow(
                  title: beng?['label'] as String? ?? "${driverName ?? 'Driver'}'s Beng",
                  timing: _timingLabel(r),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Request Pending'),
                      content: Text('${r['origin_name']} → ${r['destination_name']} at ${(r['depart_time'] as String).substring(0, 5)}\n\nWaiting for ${driverName ?? 'the driver'} to respond.'),
                      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
                    ),
                  ),
                );
              },
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Padding(padding: const EdgeInsets.all(24), child: Text('Could not load notifications: ${snapshot.error}'));
                }
                final notifications = snapshot.data ?? [];
                if (notifications.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No notifications yet', style: TextStyle(color: AppColors.mutedText))),
                  );
                }
                final grouped = <String, List<Map<String, dynamic>>>{};
                for (final n in notifications) {
                  final header = _dateHeader(DateTime.parse(n['created_at'] as String).toLocal());
                  grouped.putIfAbsent(header, () => []).add(n);
                }
                return Column(
                  children: [
                    for (final group in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(group.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navyText)),
                      ),
                      for (final n in group.value) _NotificationRow(notification: n, onTap: () => _onTapNotification(n)),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingSection extends StatelessWidget {
  const _PendingSection({required this.title, required this.future, required this.rowBuilder});

  final String title;
  final Future<List<Map<String, dynamic>>> future;
  final Widget Function(Map<String, dynamic>) rowBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (snapshot.connectionState != ConnectionState.done || items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navyText)),
            ),
            for (final item in items) rowBuilder(item),
          ],
        );
      },
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.title, required this.timing, required this.onTap});

  final String title;
  final String timing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEEEEEE))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                Text(timing, style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
                const SizedBox(width: 8),
                const CircleAvatar(radius: 12, backgroundColor: AppColors.navyText, child: Icon(Icons.arrow_forward, size: 13, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] == true;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: isRead ? const Color(0xFFF1F1F1) : AppColors.sheetLavender,
        child: Icon(Icons.notifications_outlined, color: isRead ? AppColors.mutedText : AppColors.iconBlue, size: 18),
      ),
      title: Text(
        notification['label'] as String? ?? '',
        style: TextStyle(fontWeight: isRead ? FontWeight.w400 : FontWeight.w700, fontSize: 13),
      ),
      subtitle: notification['body'] != null ? Text(notification['body'] as String, style: const TextStyle(fontSize: 12)) : null,
      trailing: isRead ? null : const CircleAvatar(radius: 4, backgroundColor: AppColors.mapPinRed),
    );
  }
}
