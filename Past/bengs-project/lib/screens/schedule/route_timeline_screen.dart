import 'package:flutter/material.dart';
import '../../services/beng_management_repository.dart';
import '../../services/friend_repository.dart';
import '../../services/rating_repository.dart';
import '../../services/route_repository.dart';
import '../../theme/app_colors.dart';
import '../../utils/whatsapp.dart';

/// The route/stop timeline from bengs01.pdf's beng-detail screen
/// (Departure/Pick-up/Drop-off/Arrival) — reads what RouteRepository
/// actually computed and saved, once at least one request's been accepted.
///
/// BR-10's Cancel/Delete actions live here (only shown to the driver who
/// owns this beng) — distinct from Reject, which lives in ReviewingScreen
/// since it applies before a request is ever accepted.
class RouteTimelineScreen extends StatefulWidget {
  const RouteTimelineScreen({
    super.key,
    required this.bengDailyId,
    required this.title,
    this.isOwnerDriver = false,
    this.isPast = false,
    this.bengId,
  });

  final String bengDailyId;
  final String title;
  final bool isOwnerDriver;

  /// Shows the rating section instead of Cancel/Delete — those only make
  /// sense for a ride that hasn't happened yet.
  final bool isPast;

  /// Required when [isOwnerDriver] is true — Delete acts on the whole
  /// recurring series, not just this one day.
  final String? bengId;

  @override
  State<RouteTimelineScreen> createState() => _RouteTimelineScreenState();
}

class _RouteTimelineScreenState extends State<RouteTimelineScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _future = RouteRepository.getStops(widget.bengDailyId);
  }

  Future<String?> _promptReason({required String title, required String confirmLabel}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Reason'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
          FilledButton(
            onPressed: controller.text.trim().isEmpty ? null : () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelDay() async {
    final reason = await _promptReason(title: 'Cancel The Day', confirmLabel: 'Cancel The Day');
    if (reason == null || !mounted) return;
    setState(() => _isBusy = true);
    try {
      await BengManagementRepository.cancelDay(widget.bengDailyId, reason);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
      setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteBeng() async {
    final bengId = widget.bengId;
    if (bengId == null) return;
    final reason = await _promptReason(title: 'Delete Beng', confirmLabel: 'Delete');
    if (reason == null || !mounted) return;
    setState(() => _isBusy = true);
    try {
      await BengManagementRepository.deleteBeng(bengId, reason);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      setState(() => _isBusy = false);
    }
  }

  String _label(Map<String, dynamic> stop) {
    final state = stop['passenger_state'] as int;
    final passenger = stop['passenger'] as Map<String, dynamic>?;
    final name = passenger?['first_name'] as String? ?? '';
    return switch (state) {
      1 => 'Pick-Up $name',
      -1 => 'Drop-Off $name',
      _ => name.isEmpty ? 'Driver stop' : name,
    };
  }

  Color _dotColor(int state) => switch (state) {
        1 => AppColors.amber,
        -1 => AppColors.mapPinRed,
        _ => AppColors.iconBlue,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.white, foregroundColor: AppColors.navyText, elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            _ContactBar(bengDailyId: widget.bengDailyId),
            Expanded(child: _buildTimeline(context)),
          ],
        ),
      ),
      bottomNavigationBar: widget.isPast
          ? _RatingSection(bengDailyId: widget.bengDailyId)
          : widget.isOwnerDriver
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isBusy ? null : _cancelDay,
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                            child: const Text('Cancel The Day'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: (_isBusy || widget.bengId == null) ? null : _deleteBeng,
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.mutedText, side: const BorderSide(color: AppColors.mutedText)),
                            child: const Text('Delete Beng'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
    );
  }

  Widget _buildTimeline(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Could not load route: ${snapshot.error}'));
        }
        final stops = snapshot.data ?? [];
        if (stops.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No route computed yet — this appears once a passenger request has been accepted.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: stops.length,
          itemBuilder: (context, index) {
            final stop = stops[index];
            final eta = DateTime.parse(stop['eta'] as String).toLocal();
            final timeLabel = '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      CircleAvatar(radius: 5, backgroundColor: _dotColor(stop['passenger_state'] as int)),
                      if (index != stops.length - 1) Container(width: 2, height: 32, color: AppColors.hairline),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_label(stop), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(timeLabel, style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// WA-01 — a "Text in Whatsapp" strip for every counterpart on this ride,
/// shown regardless of past/upcoming since pickup coordination happens
/// before the ride, not just settlement after it. Being paired on the same
/// beng does NOT by itself unlock WhatsApp (FRD §3.1's explicit negative
/// example) — a counterpart who isn't yet a mutual friend gets a "Follow"
/// prompt instead (WA-S01), and one who's mutual but hasn't enabled the
/// texting toggle gets a disabled chip explaining why.
class _ContactBar extends StatefulWidget {
  const _ContactBar({required this.bengDailyId});

  final String bengDailyId;

  @override
  State<_ContactBar> createState() => _ContactBarState();
}

class _ContactBarState extends State<_ContactBar> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = RouteRepository.getContacts(widget.bengDailyId);
  }

  Future<void> _follow(String contactId) async {
    try {
      await FriendRepository.follow(contactId);
      if (!mounted) return;
      // Following them may now be mutual (if they already followed us),
      // which is exactly the case that can unlock WhatsApp immediately.
      setState(() => _future = RouteRepository.getContacts(widget.bengDailyId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not follow: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final contacts = snapshot.data ?? [];
        if (snapshot.connectionState != ConnectionState.done || contacts.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: contacts.map((c) {
              final id = c['id'] as String;
              final name = c['first_name'] as String? ?? 'them';
              final phoneNumber = c['phone_number'] as String?;
              final isMutual = c['is_mutual'] == true;
              final canWhatsApp = c['can_whatsapp'] == true && phoneNumber != null;

              if (canWhatsApp) {
                return ElevatedButton.icon(
                  onPressed: () => WhatsAppLauncher.openChat(phoneNumber),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 15),
                  label: Text('Text $name', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                );
              }

              if (!isMutual) {
                return OutlinedButton.icon(
                  onPressed: () => _follow(id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  icon: const Icon(Icons.person_add_alt, size: 15),
                  label: Text('Follow $name', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                );
              }

              return OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(phoneNumber == null ? "$name hasn't added a phone number yet" : "$name hasn't turned on WhatsApp texting")),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mutedText,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 15),
                label: Text('Text $name', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/// BR's ratings/review screens — a rateable counterpart per row (the
/// driver for a passenger's ride, or each accepted passenger for a
/// driver's ride), each tied uniquely to this one beng_daily.
class _RatingSection extends StatefulWidget {
  const _RatingSection({required this.bengDailyId});

  final String bengDailyId;

  @override
  State<_RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<_RatingSection> {
  late Future<RateableCounterparts> _future;

  @override
  void initState() {
    super.initState();
    _future = RatingRepository.getRateableCounterparts(widget.bengDailyId);
  }

  Future<void> _openRatingDialog(String counterpartId, String name, {required bool isDriverRatingPassenger}) async {
    var score = 5;
    final reviewController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Rate $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return IconButton(
                    onPressed: () => setDialogState(() => score = starIndex),
                    icon: Icon(
                      starIndex <= score ? Icons.star : Icons.star_border,
                      color: AppColors.amber,
                    ),
                  );
                }),
              ),
              TextField(
                controller: reviewController,
                decoration: const InputDecoration(hintText: 'Review (optional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Submit')),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) return;
    try {
      if (isDriverRatingPassenger) {
        await RatingRepository.ratePassenger(
          bengDailyId: widget.bengDailyId,
          passengerId: counterpartId,
          score: score.toDouble(),
          review: reviewController.text.trim().isEmpty ? null : reviewController.text.trim(),
        );
      } else {
        await RatingRepository.rateDriver(
          bengDailyId: widget.bengDailyId,
          driverId: counterpartId,
          score: score.toDouble(),
          review: reviewController.text.trim().isEmpty ? null : reviewController.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rating submitted')));
      setState(() => _future = RatingRepository.getRateableCounterparts(widget.bengDailyId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit rating: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<RateableCounterparts>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
          final data = snapshot.data;
          if (data == null || data.people.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: data.people.map((c) {
                final id = c['id']!;
                final name = c['first_name'] ?? 'them';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _openRatingDialog(id, name, isDriverRatingPassenger: data.amDriver),
                      child: Text('Rate $name'),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
