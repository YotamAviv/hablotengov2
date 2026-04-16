import 'package:flutter/material.dart';
import 'package:hablotengo/paste_sign_in.dart';
import 'package:hablotengo/sign_in_state.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HabloTengo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('HabloTengo', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Privacy-first contact directory', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 48),
            FilledButton.icon(
              icon: const Icon(Icons.paste),
              label: const Text('Paste Credentials'),
              onPressed: () => pasteSignIn(context),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('QR Scan (coming soon)'),
              onPressed: null,
            ),
            const SizedBox(height: 32),
            ListenableBuilder(
              listenable: signInState,
              builder: (context, _) {
                if (!signInState.hasPov) return const SizedBox.shrink();
                return Column(children: [
                  const Divider(),
                  const Text('Signed in (read-only — no delegate key)',
                      style: TextStyle(color: Colors.orange)),
                  TextButton(
                    onPressed: () {
                      signInState.signOut();
                    },
                    child: const Text('Sign Out'),
                  ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
