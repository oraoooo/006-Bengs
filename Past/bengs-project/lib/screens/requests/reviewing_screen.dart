import 'package:flutter/material.dart';
import '../../services/request_repository.dart';
import '../../services/route_matching.dart';
import '../../services/route_repository.dart';
import '../../theme/app_colors.dart';

/// The "Reviewing" screen from bengs01.pdf (BR-10) — a driver accepting or
/// rejecting pending join requests against their own bengs. Reject needs no
/// reason (unlike Cancel, which unwinds an already-accepted deal elsewhere).
class ReviewingScreen extends StatefulWidget {
  const ReviewingScreen({super.key});

  @override
  State<ReviewingScreen> createState() => _ReviewingScreenState();
}

class _ReviewingScreenState extends State<ReviewingScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = RequestRepository.getIncomingRequests();
  }

  void _refresh() => setState(() => _future = RequestRepository.getIncomingRequests());

  Future<void> _respond(String requestId, bool accept, String bengDailyId) async {
    setState(() => _busyIds.add(requestId));
    try {
      await RequestRepository.respondToRequest(requestId, accept: accept);
      // A newly-accepted passenger changes the optimal stop order (BR-09),
      // so the route has to be recomputed — see CLAUDE.md roadmap step 4.
      if (accept) await RouteRepository.rebuildRoute(bengDailyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(accept ? 'Request accepted' : 'Request declined')));
      _refresh();
    } on RouteCapacityExceededException {
      // The vehicle is already full through every span of the route —
      // undo the Accept rather than leave it sitting there with no route.
      await RequestRepository.revertToPending(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This beng is already at full capacity. Reject or cancel another passenger first.")),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not respond: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(requestId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviewing'), backgroundColor: Colors.white, foregroundColor: AppColors.navyText, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Could not load requests: ${snapshot.error}'));
            }
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return const Center(child: Text('No pending requests', style: TextStyle(color: AppColors.mutedText)));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final r = requests[index];
                final id = r['id'] as String;
                final bengDailyId = r['beng_daily_id'] as String;
                final passenger = r['profile'] as Map<String, dynamic>?;
                final bengDaily = r['beng_daily'] as Map<String, dynamic>?;
                final beng = bengDaily?['beng'] as Map<String, dynamic>?;
                final firstName = passenger?['first_name'] as String? ?? 'Someone';
                final surname = passenger?['surname'] as String? ?? '';
                final name = [firstName, surname].where((s) => s.isNotEmpty).join(' ');
                final rating = (passenger?['passenger_rating'] as num?)?.toDouble();
                final isBusy = _busyIds.contains(id);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(backgroundColor: AppColors.primaryBlue, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                if (rating != null) Text('★ ${rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
                              ],
                            ),
                          ),
                          Text(beng?['label'] as String? ?? 'Your Beng', style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${r['origin_name']} → ${r['destination_name']} at ${(r['depart_time'] as String).substring(0, 5)}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isBusy ? null : () => _respond(id, false, bengDailyId),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isBusy ? null : () => _respond(id, true, bengDailyId),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                              child: isBusy
                                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
