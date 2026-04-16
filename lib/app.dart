import 'package:flutter/material.dart';
import 'package:hablotengo/screens/contacts_screen.dart';
import 'package:hablotengo/screens/sign_in_screen.dart';
import 'package:hablotengo/sign_in_state.dart';

class HablotengoApp extends StatelessWidget {
  const HablotengoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabloTengo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _RootNavigator(),
    );
  }
}

class _RootNavigator extends StatefulWidget {
  const _RootNavigator();

  @override
  State<_RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<_RootNavigator> {
  @override
  void initState() {
    super.initState();
    signInState.addListener(_onSignInChanged);
  }

  @override
  void dispose() {
    signInState.removeListener(_onSignInChanged);
    super.dispose();
  }

  void _onSignInChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (signInState.hasPov) {
      return const ContactsScreen();
    }
    return const SignInScreen();
  }
}
