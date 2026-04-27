import 'package:flutter/material.dart';
import 'package:hablotengo/main.dart' show habloFirestore;
import 'package:hablotengo/paste_sign_in.dart';
import 'package:hablotengo/sign_in_session.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:hablotengo/ui/ht_logo.dart';
import 'package:hablotengo/ui/ht_theme.dart';
import 'package:nerdster_common/ui/sign_in_dialog.dart';

SignInConfig _buildHabloSignInConfig() => SignInConfig(
      sessionFactory: createHabloSignInSession,
      firestore: habloFirestore,
      onData: habloOnSessionData,
      stateNotifier: signInState,
      hasIdentity: () => signInState.hasIdentity,
      hasDelegate: () => signInState.delegate != null,
      identityJson: () => signInState.hasIdentity ? signInState.identityJson : null,
      delegatePublicKeyJson: () => signInState.delegatePublicKeyJson,
      onSignOut: signInState.signOut,
      onForgetIdentity: signInState.signOut,
      onPasteSignIn: pasteSignIn,
    );

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
              color: Colors.white.withValues(alpha: 0.7),
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
            icon: const Icon(Icons.login),
            label: const Text('Sign In'),
            onPressed: () => showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                child: SignInDialog(config: _buildHabloSignInConfig()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
