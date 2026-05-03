import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nerdster_common/sign_in_session.dart';
import 'package:nerdster_common/ui/sign_in_dialog.dart';

import 'constants.dart';
import 'contacts_screen.dart';
import 'demo_sign_in_service.dart';
import 'equivalent_popup.dart';
import 'key_store.dart';
import 'my_contact_screen.dart';
import 'settings_screen.dart';
import 'settings_state.dart';
import 'sign_in_state.dart';

class HabloApp extends StatelessWidget {
  final FirebaseFirestore firestore;
  final bool emulator;
  final bool demoMode;
  final String? startupTarget;

  const HabloApp({super.key, required this.firestore, required this.emulator, this.demoMode = false, this.startupTarget});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabloTengo',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: _HabloHome(firestore: firestore, emulator: emulator, demoMode: demoMode, startupTarget: startupTarget),
    );
  }
}

class _HabloHome extends StatefulWidget {
  final FirebaseFirestore firestore;
  final bool emulator;
  final bool demoMode;
  final String? startupTarget;

  const _HabloHome({required this.firestore, required this.emulator, required this.demoMode, this.startupTarget});

  @override
  State<_HabloHome> createState() => _HabloHomeState();
}

class _HabloHomeState extends State<_HabloHome> {
  String _selectedCharacter = 'lisa';
  bool _demoSigningIn = false;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    signInState.addListener(_onSignInChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDialog());
  }

  @override
  void dispose() {
    signInState.removeListener(_onSignInChanged);
    super.dispose();
  }

  void _onSignInChanged() {
    if (!signInState.hasIdentity) {
      _maybeShowDialog();
    } else if (_dialogShowing && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_dialogShowing && mounted) Navigator.of(context).pop();
      });
    }
  }

  void _maybeShowDialog() {
    if (_dialogShowing || !mounted || signInState.hasIdentity || widget.demoMode) return;
    _dialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(child: SignInDialog(config: _buildSignInConfig())),
    ).then((_) {
      _dialogShowing = false;
      if (!signInState.hasIdentity && mounted) _maybeShowDialog();
    });
  }

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
          if (widget.demoMode) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _demoSigningIn ? null : _doDemoSignIn,
                      child: const Text('Sign in as Demo User'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedCharacter,
                      items: kSimpsonsKeyNames
                          .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCharacter = v!),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Scaffold(body: SizedBox.shrink());
        }
        settingsState.load(widget.emulator).then((_) {
          if (!context.mounted) return;
          final disabledBy = settingsState.disabledBy;
          if (disabledBy != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                showDisabledAccountAlert(context, disabledBy, widget.emulator, () {
                  settingsState.reset();
                  signInState.signOut();
                });
              }
            });
          }
        });
        return _SignedInScreen(
          onSignOut: () {
            settingsState.reset();
            signInState.signOut();
          },
          emulator: widget.emulator,
          startupTarget: widget.startupTarget,
        );
      },
    );
  }

  SignInConfig _buildSignInConfig() {
    return SignInConfig(
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
  }

}

class _SignedInScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  final bool emulator;
  final String? startupTarget;

  const _SignedInScreen({required this.onSignOut, required this.emulator, this.startupTarget});

  @override
  State<_SignedInScreen> createState() => _SignedInScreenState();
}

class _SignedInScreenState extends State<_SignedInScreen> {
  final _contactsKey = GlobalKey<ContactsScreenState>();

  void _openMyCard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => MyContactSheet(emulator: widget.emulator),
    ).then((_) => _contactsKey.currentState?.reload());
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsScreen(emulator: widget.emulator)),
    ).then((_) => _contactsKey.currentState?.reload());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HabloTengo'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _contactsKey.currentState?.reload()),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => _openSettings(context)),
          IconButton(icon: const Icon(Icons.person), onPressed: () => _openMyCard(context)),
          TextButton(onPressed: widget.onSignOut, child: const Text('Sign out')),
        ],
      ),
      body: ContactsScreen(key: _contactsKey, emulator: widget.emulator, startupTarget: widget.startupTarget),
    );
  }
}
