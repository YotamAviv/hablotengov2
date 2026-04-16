import 'package:flutter/material.dart';
import 'package:hablotengo/logic/contact_repo.dart';
import 'package:hablotengo/main.dart';
import 'package:hablotengo/models/hablo_model.dart';
import 'package:hablotengo/screens/contact_detail_screen.dart';
import 'package:hablotengo/screens/my_card_screen.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:hablotengo/ui/ht_logo.dart';
import 'package:hablotengo/ui/ht_theme.dart';
import 'package:oneofus_common/keys.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  bool _loading = true;
  String? _error;
  TrustGraph? _graph;
  List<ContactEntry> _contacts = [];
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ContactRepo(
          oneofusFirestore: oneofusFirestore, habloFirestore: habloFirestore);
      final result = await repo.loadContacts(IdentityKey(signInState.pov));
      setState(() {
        _graph = result.graph;
        _contacts = result.contacts;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<ContactEntry> get _filtered {
    if (_query.isEmpty) return _contacts;
    final pov = IdentityKey(signInState.pov);
    final graph = _graph;
    return _contacts.where((e) {
      if (graph == null) return false;
      final names = e.allNames(pov, graph)..add(e.displayName(pov, graph));
      return names.any((n) => n.toLowerCase().contains(_query));
    }).toList();
  }

  Future<void> _goToMyCard() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MyCardScreen()),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          HtHeader(
            actions: [
              IconButton(
                icon: const Icon(Icons.person_rounded, color: Colors.white),
                onPressed: _goToMyCard,
                tooltip: 'My Card',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _loading ? null : _load,
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: () => signInState.signOut(),
                tooltip: 'Sign Out',
              ),
            ],
            bottom: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search…',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.7)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: Colors.white.withOpacity(0.7)),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Colors.white54),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _query.isNotEmpty ? 'No matching contacts.' : 'No contacts in trust graph yet.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: filtered.length,
      itemBuilder: (context, i) => _ContactCard(
        entry: filtered[i],
        pov: IdentityKey(signInState.pov),
        graph: _graph,
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final ContactEntry entry;
  final IdentityKey pov;
  final TrustGraph? graph;
  const _ContactCard({required this.entry, required this.pov, required this.graph});

  @override
  Widget build(BuildContext context) {
    final name = graph != null ? entry.displayName(pov, graph!) : '…';
    final hasDetails = entry.contact != null;
    final canSee = entry.canSeeYou;
    final grayed = canSee == false && !entry.isYou;
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: hasDetails
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ContactDetailScreen(entry: entry)),
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _GradientAvatar(initials: initials, seed: name, grayed: grayed, isYou: entry.isYou),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: grayed ? Colors.grey.shade400 : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(children: [
                        _DistanceBadge(entry.distance),
                        const SizedBox(width: 6),
                        if (entry.isYou) _Tag('You', kGradientStart),
                        if (!hasDetails && !entry.isYou)
                          _Tag('No card', Colors.grey),
                        if (canSee == false && !entry.isYou)
                          _Tag('Cannot see you', Colors.orange.shade700),
                      ]),
                    ],
                  ),
                ),
                if (hasDetails && !grayed)
                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientAvatar extends StatelessWidget {
  final String initials;
  final String seed;
  final bool grayed;
  final bool isYou;
  const _GradientAvatar({required this.initials, required this.seed, required this.grayed, required this.isYou});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: grayed
            ? const LinearGradient(colors: [Color(0xFFCCCCCC), Color(0xFFAAAAAA)])
            : isYou
                ? const LinearGradient(colors: [kGradientStart, kGradientEnd])
                : avatarGradient(seed),
        shape: BoxShape.circle,
        boxShadow: grayed ? null : [
          BoxShadow(
            color: avatarGradient(seed).colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  final int distance;
  const _DistanceBadge(this.distance);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: kGradientStart.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'd$distance',
        style: const TextStyle(fontSize: 11, color: kGradientStart, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
