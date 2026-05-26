import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nerdster_common/sign_in_session.dart';
import 'package:nerdster_common/ui/sign_in_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import 'version.dart';
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
  final String? startupTarget;
  final GlobalKey<NavigatorState>? navigatorKey;

  const HabloApp({super.key, required this.firestore, required this.emulator, this.demoMode = false, this.startupTarget, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabloTengo',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      navigatorKey: navigatorKey,
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
    }
    // No auto-close: user sees key arrival animation and closes manually.
  }

  void _maybeShowDialog() {
    if (_dialogShowing || !mounted || signInState.hasIdentity || widget.demoMode) return;
    _dialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: SignInDialog(config: _buildSignInConfig()),
      ),
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
            return _DemoLanding(
              selectedCharacter: _selectedCharacter,
              onCharacterChanged: (v) => setState(() => _selectedCharacter = v),
              onSignIn: _demoSigningIn ? null : _doDemoSignIn,
            );
          }
          return const Scaffold(body: SizedBox.shrink());
        }
        settingsState.load();
        return _SignedInScreen(
          onSignOut: () {
            settingsState.reset();
            signInState.signOut();
          },
          emulator: widget.emulator,
          demoMode: widget.demoMode,
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
      delegatePublicKeyJson: () => signInState.delegatePublicKeyJson,
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

// ---------------------------------------------------------------------------

class _DemoLanding extends StatelessWidget {
  final String selectedCharacter;
  final ValueChanged<String> onCharacterChanged;
  final VoidCallback? onSignIn;

  const _DemoLanding({
    required this.selectedCharacter,
    required this.onCharacterChanged,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HabloTengo Demo', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Uses the Simpsons Bot Farm from '),
                    WidgetSpan(child: InkWell(
                      onTap: () => launchUrl(Uri.parse('https://nerdster.org'), mode: LaunchMode.externalApplication),
                      child: Text('nerdster.org', style: TextStyle(color: cs.primary, decoration: TextDecoration.underline)),
                    )),
                    const TextSpan(text: '.'),
                  ])),
                  const SizedBox(height: 6),
                  const Text('Data is read only. No authorization required.'),
                  const SizedBox(height: 28),
                  Text('Sign in as', style: tt.labelLarge),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: selectedCharacter,
                        items: kSimpsonsKeyNames
                            .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                            .toList(),
                        onChanged: (v) => onCharacterChanged(v!),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: onSignIn,
                        child: const Text('Go'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('Sign in to your HabloTengo', style: tt.labelLarge),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse('https://hablotengo.com/app'), mode: LaunchMode.externalApplication),
                    child: Text(
                      'hablotengo.com/app',
                      style: TextStyle(color: cs.primary, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SignedInScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  final bool emulator;
  final bool demoMode;
  final String? startupTarget;

  const _SignedInScreen({required this.onSignOut, required this.emulator, required this.demoMode, this.startupTarget});

  @override
  State<_SignedInScreen> createState() => _SignedInScreenState();
}

class _SignedInScreenState extends State<_SignedInScreen> with SingleTickerProviderStateMixin {
  final _contactsKey = GlobalKey<ContactsScreenState>();
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final ValueNotifier<bool> _isDelegateError = ValueNotifier(false);
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool? _hasContactCard; // null = loading, true = has card, false = no card

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _isLoading.dispose();
    _isDelegateError.dispose();
    super.dispose();
  }

  void _openMyCard(BuildContext context) {
    final preloaded = _contactsKey.currentState?.myContactResult;
    if (preloaded == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => MyContactSheet(emulator: widget.emulator, monikers: _contactsKey.currentState?.myMonikers ?? [], preloaded: preloaded, onContactSaved: (contact) => _contactsKey.currentState?.updateMyContact(contact)),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SettingsScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Tooltip(
          message: kAppVersion,
          child: Image.asset('assets/images/hablo.png', height: 32),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (_, loading, _) => loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal)),
                  )
                : IconButton(icon: const Icon(Icons.refresh), onPressed: () => _contactsKey.currentState?.reload()),
          ),
          if (signInState.hasIdentity)
            ValueListenableBuilder<bool>(
              valueListenable: _isDelegateError,
              builder: (_, error, _) => IconButton(
                icon: const Icon(Icons.settings),
                onPressed: error ? null : () => _openSettings(context),
              ),
            ),
          ValueListenableBuilder<bool>(
            valueListenable: _isDelegateError,
            builder: (_, error, _) => AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) {
                final pulse = _hasContactCard == false && !error;
                return IconButton(
                  icon: Icon(
                    Icons.person,
                    color: pulse
                        ? Colors.red.withValues(alpha: 0.3 + 0.7 * _pulseAnimation.value)
                        : null,
                  ),
                  onPressed: error ? null : () => _openMyCard(context),
                );
              },
            ),
          ),
          TextButton(onPressed: widget.onSignOut, child: const Text('Sign out')),
        ],
      ),
      body: ContactsScreen(key: _contactsKey, emulator: widget.emulator, startupTarget: widget.startupTarget, isLoading: _isLoading, isDelegateError: _isDelegateError, onContactCardStatus: (hasCard) => setState(() => _hasContactCard = hasCard)),
    );
  }
}
