import 'package:flutter/material.dart';
import 'package:hablotengo/logic/contact_repo.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactDetailScreen extends StatelessWidget {
  final ContactEntry entry;
  const ContactDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final contact = entry.contact!;
    final name = contact.name ?? entry.networkMonikers.firstOrNull ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section('Contact Info', [
            if (contact.name != null) _InfoRow('Name', contact.name!),
            if (contact.phone != null) _InfoRow('Phone', contact.phone!),
            ...contact.emails.map((e) => _InfoRow(
                  e['preferred'] == true ? 'Email (preferred)' : 'Email',
                  e['address'] ?? '',
                )),
          ]),
          if (contact.contactPrefs.isNotEmpty)
            _Section('Messaging', _buildContactPrefs(contact.contactPrefs)),
          if (contact.socialAccounts.isNotEmpty)
            _Section('Social', _buildSocialAccounts(contact.socialAccounts)),
          if (contact.website != null)
            _Section('Web', [_LinkRow('Website', contact.website!)]),
          if (contact.other != null)
            _Section('Other', [_InfoRow('', contact.other!)]),
          const SizedBox(height: 16),
          Text('Trust distance: ${entry.distance}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text('Visibility: ${entry.visibilityLevel.name}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  List<Widget> _buildContactPrefs(Map<String, dynamic> prefs) {
    final rows = <Widget>[];
    final urlMap = {
      'whatsapp': (h) => 'https://wa.me/${h.replaceAll('+', '').replaceAll(' ', '')}',
      'telegram': (h) => 'https://t.me/$h',
      'signal': (h) => 'https://signal.me/#p/$h',
      'instagram': (h) => 'https://instagram.com/$h',
      'twitter_x': (h) => 'https://x.com/$h',
      'threads': (h) => 'https://threads.net/@$h',
      'bluesky': (h) => 'https://bsky.app/profile/$h',
      'mastodon': (h) {
        final parts = h.split('@').where((s) => s.isNotEmpty).toList();
        if (parts.length == 2) return 'https://${parts[1]}/@${parts[0]}';
        return 'https://mastodon.social/@$h';
      },
    };
    for (final entry in prefs.entries) {
      final handle = entry.value is Map ? entry.value['handle'] : entry.value?.toString();
      if (handle == null || handle.isEmpty) continue;
      final preferred = entry.value is Map ? entry.value['preferred'] == true : false;
      final label = '${entry.key}${preferred ? ' ★' : ''}';
      final urlFn = urlMap[entry.key];
      if (urlFn != null) {
        rows.add(_LinkRow(label, urlFn(handle), displayText: handle));
      } else {
        rows.add(_InfoRow(label, handle));
      }
    }
    return rows;
  }

  List<Widget> _buildSocialAccounts(Map<String, dynamic> accounts) {
    final urlMap = {
      'linkedin': (h) => 'https://linkedin.com/in/$h',
      'facebook': (h) => 'https://facebook.com/$h',
    };
    return accounts.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) {
      final urlFn = urlMap[e.key];
      if (urlFn != null) {
        return _LinkRow(e.key, urlFn(e.value), displayText: e.value.toString());
      }
      return _InfoRow(e.key, e.value.toString());
    }).toList();
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      ...children,
      const Divider(),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        if (label.isNotEmpty) ...[
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
        ],
        Expanded(child: Text(value)),
      ]),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final String url;
  final String? displayText;
  const _LinkRow(this.label, this.url, {this.displayText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(
          child: InkWell(
            onTap: () => launchUrl(Uri.parse(url)),
            child: Text(
              displayText ?? url,
              style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
            ),
          ),
        ),
      ]),
    );
  }
}
