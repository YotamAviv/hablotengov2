import 'package:flutter/material.dart';
import 'package:hablotengo/paste_sign_in.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:hablotengo/ui/ht_logo.dart';
import 'package:hablotengo/ui/ht_theme.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHero(),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: kHeaderGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HtLogo(size: 48),
          const SizedBox(height: 24),
          const Text(
            'Your trusted\ncontact directory.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w300,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Privacy-first · Identity-verified · Open network',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Sign in with your identity key',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Use your ONE-OF-US.NET identity to create a delegate key for HabloTengo.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: const Icon(Icons.paste_rounded),
            label: const Text('Paste Credentials'),
            onPressed: () => pasteSignIn(context),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan QR Code'),
            onPressed: null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
          ),
          const SizedBox(height: 32),
          ListenableBuilder(
            listenable: signInState,
            builder: (context, _) {
              if (!signInState.hasPov) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(children: [
                  const Text('Signed in (read-only — no delegate key)',
                      style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: signInState.signOut,
                    child: const Text('Sign Out'),
                  ),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }
}
