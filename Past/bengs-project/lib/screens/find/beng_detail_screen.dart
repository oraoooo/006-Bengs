import 'package:flutter/material.dart';
import '../../models/beng_listing.dart';
import '../../services/request_repository.dart';
import '../../theme/app_colors.dart';

/// bengs01.pdf's beng detail screen, for the pre-request browsing case —
/// the route/stop timeline version (page showing "Departure/Pick-up/
/// Drop-off/Arrival") only makes sense once a request is accepted and the
/// route-matching step has actually assigned stops, so this simpler detail
/// view is what a passenger sees before that happens.
class BengDetailScreen extends StatefulWidget {
  const BengDetailScreen({super.key, required this.listing});

  final BengListing listing;

  @override
  State<BengDetailScreen> createState() => _BengDetailScreenState();
}

class _BengDetailScreenState extends State<BengDetailScreen> {
  late Future<String?> _statusFuture;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _statusFuture = RequestRepository.getMyRequestStatus(widget.listing.bengDailyId);
  }

  Future<void> _requestToJoin() async {
    setState(() => _isRequesting = true);
    try {
      await RequestRepository.requestToJoin(widget.listing);
      if (!mounted) return;
      setState(() => _statusFuture = RequestRepository.getMyRequestStatus(widget.listing.bengDailyId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent. The driver will review it.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send request: $e')));
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    return Scaffold(
      appBar: AppBar(
        title: Text(listing.label ?? "${listing.driverName}'s Beng"),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navyText,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sheetLavender,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: AppColors.primaryBlue, child: Text(listing.driverName.isNotEmpty ? listing.driverName[0] : '?', style: const TextStyle(color: Colors.white))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(listing.driverName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (listing.driverRating != null)
                            Row(
                              children: [
                                const Icon(Icons.star, size: 13, color: AppColors.amber),
                                const SizedBox(width: 2),
                                Text(listing.driverRating!.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Text('Rp${listing.price}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _InfoRow(icon: Icons.calendar_today, label: '${listing.date.day}/${listing.date.month}/${listing.date.year} at ${listing.departTime}'),
              if (listing.vehicleLabel != null) _InfoRow(icon: Icons.directions_car_outlined, label: listing.vehicleLabel!),
              _InfoRow(icon: Icons.event_seat_outlined, label: '${listing.maxPassenger} seat(s)'),
              const SizedBox(height: 12),
              const Text('Route', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.my_location, iconColor: AppColors.iconBlue, label: listing.originName),
              if (listing.destinationName != null)
                _InfoRow(icon: Icons.flag_outlined, iconColor: AppColors.mapPinRed, label: listing.destinationName!),
              const SizedBox(height: 28),
              FutureBuilder<String?>(
                future: _statusFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(height: 52, child: Center(child: CircularProgressIndicator()));
                  }
                  if (listing.isOwn) {
                    return const SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: null,
                        child: Text('This is your Beng'),
                      ),
                    );
                  }
                  final status = snapshot.data;
                  if (status != null) {
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: Text('Request ${status[0].toUpperCase()}${status.substring(1)}'),
                      ),
                    );
                  }
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isRequesting ? null : _requestToJoin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: AppColors.navyText,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isRequesting
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Request to Join', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.iconColor = AppColors.mutedText});

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.navyText))),
        ],
      ),
    );
  }
}
