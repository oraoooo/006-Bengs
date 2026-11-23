import 'package:flutter/material.dart';
import '../../services/friend_repository.dart';
import '../../services/profile_repository.dart';
import '../../theme/app_colors.dart';
import '../../utils/whatsapp.dart';

/// Friends tab — unchanged from bengs01.pdf per CLAUDE.md. `friend` is a
/// one-directional follow (no mutual "request/accept" step in the schema),
/// so following someone is instant.
class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final _searchController = TextEditingController();
  String _query = '';
  late Future<List<Map<String, dynamic>>> _friendsFuture;
  Future<List<Map<String, dynamic>>>? _searchFuture;
  Set<String> _followedIds = {};

  // WA-01's gate also depends on the signed-in user's own toggle, fetched
  // once for the whole tab rather than per row.
  bool _myAllowsWhatsapp = false;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _loadFriends();
    ProfileRepository.getMyAllowCoolFriendsWhatsapp().then((value) {
      if (mounted) setState(() => _myAllowsWhatsapp = value);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadFriends() async {
    final friends = await FriendRepository.getMyFriends();
    _followedIds = friends.map((f) => f['id'] as String).toSet();
    return friends;
  }

  void _refreshFriends() => setState(() => _friendsFuture = _loadFriends());

  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      _searchFuture = value.trim().isEmpty ? null : FriendRepository.searchProfiles(value);
    });
  }

  Future<void> _toggleFollow(String profileId, bool isFollowing) async {
    setState(() => isFollowing ? _followedIds.remove(profileId) : _followedIds.add(profileId));
    try {
      if (isFollowing) {
        await FriendRepository.unfollow(profileId);
      } else {
        await FriendRepository.follow(profileId);
      }
      _refreshFriends();
    } catch (e) {
      if (!mounted) return;
      setState(() => isFollowing ? _followedIds.add(profileId) : _followedIds.remove(profileId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Find people to follow',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFFF1F1F1),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? FutureBuilder<List<Map<String, dynamic>>>(
                    future: _friendsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final friends = snapshot.data ?? [];
                      if (friends.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text("You're not following anyone yet. Search above to find people.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.mutedText)),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: friends.length,
                        itemBuilder: (context, index) => _FriendRow(
                          profile: friends[index],
                          myAllowsWhatsapp: _myAllowsWhatsapp,
                          onUnfollow: () => _toggleFollow(friends[index]['id'] as String, true),
                        ),
                      );
                    },
                  )
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: _searchFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final results = snapshot.data ?? [];
                      if (results.isEmpty) {
                        return const Center(child: Text('No one found', style: TextStyle(color: AppColors.mutedText)));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final profile = results[index];
                          final id = profile['id'] as String;
                          final isFollowing = _followedIds.contains(id);
                          return _ProfileRow(
                            profile: profile,
                            isFollowing: isFollowing,
                            onToggleFollow: () => _toggleFollow(id, isFollowing),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// bengs01.pdf's Friends list row — a green "Text in Whatsapp" pill per
/// followed friend (BR-11), not a Follow/Following toggle; unfollowing
/// lives behind the overflow icon since the mockup doesn't surface it on
/// this row at all (this app doesn't have the mockup's separate "Suggested
/// to Follow" dismiss-with-X section, so it needs to go somewhere).
///
/// WA-01: the button only ever *works* when mutual follow (is_mutual) AND
/// both parties' allow_cool_friends_whatsapp toggle are true — a phone
/// number alone is not enough. When any condition is missing the pill is
/// shown greyed out; tapping it explains which condition is unmet rather
/// than silently doing nothing.
class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.profile, required this.myAllowsWhatsapp, required this.onUnfollow});

  final Map<String, dynamic> profile;
  final bool myAllowsWhatsapp;
  final VoidCallback onUnfollow;

  @override
  Widget build(BuildContext context) {
    final firstName = profile['first_name'] as String? ?? '';
    final surname = profile['surname'] as String? ?? '';
    final fullName = [firstName, surname].where((s) => s.isNotEmpty).join(' ');
    final displayName = fullName.isEmpty ? 'BENGS user' : fullName;
    final phoneNumber = profile['phone_number'] as String?;
    final isMutual = profile['is_mutual'] == true;
    final theyAllowWhatsapp = profile['allow_cool_friends_whatsapp'] == true;
    final canWhatsApp = isMutual && theyAllowWhatsapp && myAllowsWhatsapp && phoneNumber != null;

    String blockedReason() {
      if (phoneNumber == null) return "$displayName hasn't added a phone number yet";
      if (!isMutual) return "You can text once $displayName follows you back";
      if (!theyAllowWhatsapp) return "$displayName hasn't turned on WhatsApp texting";
      return "Turn on \"Let cool friends message me\" in your own profile to text";
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryBlue,
        child: Text(firstName.isNotEmpty ? firstName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
      ),
      title: Text(displayName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: canWhatsApp
                ? () => WhatsAppLauncher.openChat(phoneNumber)
                : () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(blockedReason()))),
            style: ElevatedButton.styleFrom(
              backgroundColor: canWhatsApp ? const Color(0xFF25D366) : Colors.grey.shade300,
              foregroundColor: canWhatsApp ? Colors.white : AppColors.mutedText,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 15),
            label: const Text('Text in Whatsapp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          PopupMenuButton<void>(
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.mutedText),
            itemBuilder: (context) => [
              PopupMenuItem(onTap: onUnfollow, child: const Text('Unfollow')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.profile, required this.isFollowing, required this.onToggleFollow});

  final Map<String, dynamic> profile;
  final bool isFollowing;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final firstName = profile['first_name'] as String? ?? '';
    final surname = profile['surname'] as String? ?? '';
    final fullName = [firstName, surname].where((s) => s.isNotEmpty).join(' ');
    final driverRating = (profile['driver_rating'] as num?)?.toDouble();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryBlue,
        child: Text(firstName.isNotEmpty ? firstName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
      ),
      title: Text(fullName.isEmpty ? 'BENGS user' : fullName),
      subtitle: driverRating != null ? Text('★ ${driverRating.toStringAsFixed(1)} as driver', style: const TextStyle(fontSize: 12)) : null,
      trailing: OutlinedButton(
        onPressed: onToggleFollow,
        style: OutlinedButton.styleFrom(
          foregroundColor: isFollowing ? AppColors.mutedText : AppColors.primaryBlue,
          side: BorderSide(color: isFollowing ? const Color(0xFFDDDDDD) : AppColors.primaryBlue),
        ),
        child: Text(isFollowing ? 'Following' : 'Follow'),
      ),
    );
  }
}
