import 'package:flutter/material.dart';
import 'package:hablotengo/logic/contact_repo.dart';
import 'package:hablotengo/ui/ht_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactDetailScreen extends StatelessWidget {
  final ContactEntry entry;
  const ContactDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final contact = entry.contact!;
    final name = contact.name ?? entry.networkMonikers.firstOrNull ?? 'Unknown';
    final initials = name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: avatarGradient(name)),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white24,
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      _VisibilityBadge(entry.visibilityLevel.name),
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: avatarGradient(name).colors.first,
            foregroundColor: Colors.white,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (contact.phones.isNotEmpty || contact.emails.isNotEmpty)
                  _Section('Contact Info', [
                    ...contact.emails.map((e) {
                      final addr = e['address'] ?? '';
                      return _LinkChip(Icons.email_rounded, addr, 'mailto:$addr',
                          badge: e['preferred'] == true ? '★' : null);
                    }),
                    ...contact.phones.map((p) {
                      final num = p['number'] ?? '';
                      return _LinkChip(Icons.phone_rounded, num, 'tel:$num',
                          badge: p['preferred'] == true ? '★' : null);
                    }),
                  ]),
                if (contact.contactPrefs.isNotEmpty)
                  _Section('Messaging', _buildContactPrefs(contact.contactPrefs)),
                if (contact.socialAccounts.isNotEmpty)
                  _Section('Social', _buildSocialAccounts(contact.socialAccounts)),
                if (contact.website != null)
                  _Section('Web', [_LinkChip(Icons.language_rounded, contact.website!, contact.website!)]),
                if (contact.other != null)
                  _Section('Other', [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(contact.other!, style: const TextStyle(fontSize: 14)),
                    ),
                  ]),
                const SizedBox(height: 8),
                Row(children: [
                  _MetaChip('Distance ${entry.distance}', Icons.hub_rounded),
                  const SizedBox(width: 8),
                  if (entry.canSeeYou == true)
                    _MetaChip('Can see your card', Icons.visibility_rounded, color: kGradientStart),
                  if (entry.canSeeYou == false)
                    _MetaChip('Cannot see your card', Icons.visibility_off_rounded, color: Colors.orange),
                ]),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static const _platformIcons = <String, IconData>{
    'whatsapp': Icons.chat_rounded,
    'telegram': Icons.send_rounded,
    'signal': Icons.lock_rounded,
    'instagram': Icons.camera_alt_rounded,
    'twitter_x': Icons.alternate_email_rounded,
    'threads': Icons.tag_rounded,
    'bluesky': Icons.cloud_rounded,
    'mastodon': Icons.public_rounded,
    'linkedin': Icons.work_rounded,
    'facebook': Icons.people_rounded,
  };

  static final _urlBuilders = <String, String Function(String)>{
    'whatsapp': (h) => 'https://wa.me/${h.replaceAll("+", "").replaceAll(" ", "")}',
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
    'linkedin': (h) => 'https://linkedin.com/in/$h',
    'facebook': (h) => 'https://facebook.com/$h',
  };

  List<Widget> _buildContactPrefs(Map<String, List<Map<String, dynamic>>> prefs) {
    final rows = <Widget>[];
    for (final entry in prefs.entries) {
      final icon = _platformIcons[entry.key] ?? Icons.link_rounded;
      final urlFn = _urlBuilders[entry.key];
      for (final handle in entry.value) {
        final h = handle['handle']?.toString() ?? '';
        if (h.isEmpty) continue;
        final preferred = handle['preferred'] == true;
        if (urlFn != null) {
          rows.add(_LinkChip(icon, h, urlFn(h),
              label: entry.key, badge: preferred ? '★' : null));
        } else {
          rows.add(_InfoChip(icon, h, label: entry.key));
        }
      }
    }
    return rows;
  }

  List<Widget> _buildSocialAccounts(Map<String, String> accounts) {
    return accounts.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) {
      final icon = _platformIcons[e.key] ?? Icons.link_rounded;
      final urlFn = _urlBuilders[e.key];
      if (urlFn != null) {
        return _LinkChip(icon, e.value, urlFn(e.value), label: e.key);
      }
      return _InfoChip(icon, e.value, label: e.key);
    }).toList();
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    final real = children.where((w) => w is! SizedBox || (w as SizedBox).width != null).toList();
    if (real.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 1.0)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? label;
  final String? badge;
  const _InfoChip(this.icon, this.value, {this.label, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: kGradientStart),
          const SizedBox(width: 10),
          if (label != null) ...[
            Text(label!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: kGradientStart.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge!,
                  style: const TextStyle(fontSize: 11, color: kGradientStart, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final IconData icon;
  final String displayText;
  final String url;
  final String? label;
  final String? badge;
  const _LinkChip(this.icon, this.displayText, this.url, {this.label, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => launchUrl(Uri.parse(url)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGradientStart.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: kGradientStart),
            const SizedBox(width: 10),
            if (label != null) ...[
              Text(label!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                displayText,
                style: const TextStyle(fontWeight: FontWeight.w500, color: kGradientStart),
              ),
            ),
            if (badge != null)
              Text(badge!, style: const TextStyle(color: kGradientEnd, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Icon(Icons.open_in_new_rounded, size: 14, color: Colors.grey.shade400),
          ]),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _MetaChip(this.label, this.icon, {this.color = const Color(0xFF999999)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  final String level;
  const _VisibilityBadge(this.level);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(level,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}
