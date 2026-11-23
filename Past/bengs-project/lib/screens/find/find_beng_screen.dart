import 'package:flutter/material.dart';
import '../../models/beng_listing.dart';
import '../../services/beng_search_repository.dart';
import '../../theme/app_colors.dart';
import 'beng_detail_screen.dart';

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Find-a-Beng / Search-the-Bengs — unchanged from bengs01.pdf per
/// CLAUDE.md. Browses *scheduled* bengs (as opposed to the Home tab's
/// spontaneous search).
class FindBengScreen extends StatefulWidget {
  const FindBengScreen({super.key});

  @override
  State<FindBengScreen> createState() => _FindBengScreenState();
}

class _FindBengScreenState extends State<FindBengScreen> {
  late Future<List<BengListing>> _future;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = BengSearchRepository.searchScheduled();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch() {
    setState(() => _future = BengSearchRepository.searchScheduled(query: _searchController.text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Beng'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navyText,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  hintText: 'Search by origin, destination, or driver',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF1F1F1),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<BengListing>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Could not load bengs: ${snapshot.error}'));
                  }
                  final listings = snapshot.data ?? [];
                  if (listings.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No scheduled bengs yet. Add one from Schedule (+), or check back when others post rides.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: listings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _BengListingCard(listing: listings[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BengListingCard extends StatelessWidget {
  const _BengListingCard({required this.listing});

  final BengListing listing;

  @override
  Widget build(BuildContext context) {
    final date = listing.date;
    final dateLabel = '${_weekdayNames[date.weekday - 1]} ${date.day}/${date.month}';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BengDetailScreen(listing: listing)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.isOwn ? (listing.label ?? 'Your Beng') : (listing.label ?? "${listing.driverName}'s Beng"),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navyText),
                  ),
                  const SizedBox(height: 4),
                  Text('$dateLabel · ${listing.departTime}', style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.my_location, size: 13, color: AppColors.iconBlue),
                      const SizedBox(width: 4),
                      Expanded(child: Text(listing.originName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  if (listing.destinationName != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.flag_outlined, size: 13, color: AppColors.mapPinRed),
                        const SizedBox(width: 4),
                        Expanded(child: Text(listing.destinationName!, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Rp${listing.price}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navyText)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 13, color: AppColors.amber),
                    const SizedBox(width: 2),
                    Text(listing.driverRating?.toStringAsFixed(1) ?? '—', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
