import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nerdster_common/sign_in_session.dart';
import 'package:nerdster_common/ui/sign_in_dialog.dart';

import 'constants.dart';
import 'contacts_screen.dart';
import 'demo_sign_in_service.dart';
import 'key_store.dart';
import 'my_contact_screen.dart';
import 'settings_screen.dart';
import 'settings_state.dart';
import 'sign_in_state.dart';

class HabloApp extends StatelessWidget {
  final FirebaseFirestore firestore;
  final bool emulator;
  final bool demoMode;

  const HabloApp({super.key, required this.firestore, required this.emulator, this.demoMode = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabloTengo',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: _HabloHome(firestore: firestore, emulator: emulator, demoMode: demoMode),
    );
  }
}

class _HabloHome extends StatefulWidget {
  final FirebaseFirestore firestore;
  final bool emulator;
  final bool demoMode;

  const _HabloHome({required this.firestore, required this.emulator, required this.demoMode});

  @override
  State<_HabloHome> createState() => _HabloHomeState();
}

class _HabloHomeState extends State<_HabloHome> {
  String _selectedCharacter = 'lisa';
  bool _demoSigningIn = false;

  Future<void> _doDemoSignIn() async {
    setState(() => _demoSigningIn = true);
    try {
      await demoSignIn(_selectedCharacter, widget.emulator);
    } catch (e, st) {
      debugPrint('_doDemoSignIn error: $e\n$st');
    } finally {
      if (mounted) setState(() => _demoSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: signInState,
      builder: (context, _) {
        if (!signInState.hasIdentity) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _showSignIn(context),
                    child: const Text('Sign In'),
                  ),
                  if (widget.demoMode) ...[
                    const SizedBox(height: 24),
                    const Text('Demo sign-in:'),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedCharacter,
                      items: kSimpsonsDisplayNames.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCharacter = v!),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _demoSigningIn ? null : _doDemoSignIn,
                      child: const Text('Sign in as Demo User'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        settingsState.load(widget.emulator);
        return _SignedInScreen(
          onSignOut: () {
            settingsState.reset();
            signInState.signOut();
          },
          emulator: widget.emulator,
        );
      },
    );
  }

  Future<void> _showSignIn(BuildContext context) async {
    debugPrint('_showSignIn: opening sign-in dialog (emulator=${widget.emulator})');
    final config = SignInConfig(
      sessionFactory: () async {
        debugPrint('sessionFactory: creating session domain=$kHabloDomain signInUrl=${habloSignInUrl(widget.emulator)}');
        final session = await SignInSession.create(
          domain: kHabloDomain,
          signInUrl: habloSignInUrl(widget.emulator),
        );
        debugPrint('sessionFactory: session created forPhone=${session.forPhone}');
        return session;
      },
      onData: (data, pke) async {
        debugPrint('onData: received keys=${data.keys.toList()}');
        debugPrint('onData: identity=${data['identity']}');
        await signInState.onData(data, pke);
      },
      firestore: widget.firestore,
      stateNotifier: signInState,
      hasIdentity: () => signInState.hasIdentity,
      hasDelegate: () => signInState.hasDelegate,
      identityJson: () => signInState.identityJson,
      delegatePublicKeyJson: () => null,
      onSignOut: signInState.signOut,
      onForgetIdentity: signInState.signOut,
      showPasteInitially: widget.emulator,
      trailingWidget: ValueListenableBuilder<bool>(
        valueListenable: storeKeys,
        builder: (_, value, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => storeKeys.value = v ?? value,
            ),
            const Text('Store keys'),
          ],
        ),
      ),
    );
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(child: SignInDialog(config: config)),
    );
  }
}

class _SignedInScreen extends StatelessWidget {
  final VoidCallback onSignOut;
  final bool emulator;

  const _SignedInScreen({required this.onSignOut, required this.emulator});

  void _openMyCard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => MyContactSheet(emulator: emulator),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsScreen(emulator: emulator)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HabloTengo'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => _openSettings(context)),
          IconButton(icon: const Icon(Icons.person), onPressed: () => _openMyCard(context)),
          TextButton(onPressed: onSignOut, child: const Text('Sign out')),
        ],
      ),
      body: ContactsScreen(emulator: emulator),
    );
  }
}
