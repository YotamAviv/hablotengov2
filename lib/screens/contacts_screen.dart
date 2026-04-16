import 'package:flutter/material.dart';
import 'package:hablotengo/logic/contact_repo.dart';
import 'package:hablotengo/main.dart';
import 'package:hablotengo/models/hablo_model.dart';
import 'package:hablotengo/screens/contact_detail_screen.dart';
import 'package:hablotengo/screens/my_card_screen.dart';
import 'package:hablotengo/sign_in_state.dart';
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
      final pov = IdentityKey(signInState.pov);
      final result = await repo.loadContacts(pov);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(icon: const Icon(Icons.person), onPressed: _goToMyCard, tooltip: 'My Card'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => signInState.signOut(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Future<void> _goToMyCard() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MyCardScreen()),
    );
    if (changed == true) _load();
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    final filtered = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search contacts…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchCtrl.clear())
                  : null,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (filtered.isEmpty)
          const Expanded(child: Center(child: Text('No matching contacts.')))
        else
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final entry = filtered[index];
                return _ContactTile(
                  entry: entry,
                  pov: IdentityKey(signInState.pov),
                  graph: _graph,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  final ContactEntry entry;
  final IdentityKey pov;
  final TrustGraph? graph;
  const _ContactTile({required this.entry, required this.pov, required this.graph});

  @override
  Widget build(BuildContext context) {
    final name = graph != null ? entry.displayName(pov, graph!) : '…';
    final hasDetails = entry.contact != null;
    final canSee = entry.canSeeYou;
    final grayed = canSee == false;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: entry.isYou ? Colors.teal : Colors.blueGrey,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(name, style: TextStyle(color: grayed ? Colors.grey : null)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Distance: ${entry.distance}', style: const TextStyle(fontSize: 12)),
        if (!hasDetails)
          const Text('No card submitted', style: TextStyle(fontSize: 11, color: Colors.grey)),
        if (canSee == false)
          const Text('Cannot see your card', style: TextStyle(fontSize: 11, color: Colors.orange)),
      ]),
      trailing: entry.isYou ? const Chip(label: Text('You')) : null,
      onTap: hasDetails
          ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ContactDetailScreen(entry: entry)),
              )
          : null,
    );
  }
}
