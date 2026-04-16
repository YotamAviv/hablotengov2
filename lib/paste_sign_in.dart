import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hablotengo/constants.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart' show FedKey;

Future<void> pasteSignIn(BuildContext context) async {
  final credentials = await showDialog<Json>(
      context: context,
      builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: const _PasteSignInWidget(),
          ));
  if (credentials == null) return;

  final Json identityPayload = credentials['identity']!;
  final FedKey fedKey = FedKey.fromPayload(identityPayload) ?? FedKey(identityPayload);
  final OouPublicKey identityPublicKey = await crypto.parsePublicKey(fedKey.pubKeyJson);
  final Json? habloJson = credentials[kHablotengo];
  OouKeyPair? habloKeyPair;
  if (habloJson != null) {
    habloKeyPair = await crypto.parseKeyPair(habloJson);
  }

  await signInUiHelper(identityPublicKey, habloKeyPair,
      endpoint: fedKey.endpoint, method: SignInMethod.paste);
}

class _PasteSignInWidget extends StatefulWidget {
  const _PasteSignInWidget();

  @override
  State<_PasteSignInWidget> createState() => _PasteSignInWidgetState();
}

class _PasteSignInWidgetState extends State<_PasteSignInWidget> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      final Json credentials = jsonDecode(_controller.text);
      Json? identityPayload;
      if (credentials.containsKey('identity')) {
        identityPayload = credentials['identity'];
      } else {
        // Bare key or {key, url}
        identityPayload = credentials;
      }
      final FedKey fedKey = FedKey.fromPayload(identityPayload!) ?? FedKey(identityPayload);
      await crypto.parsePublicKey(fedKey.pubKeyJson);

      final Map<String, dynamic> result = {'identity': fedKey.pubKeyJson};
      if (credentials.containsKey(kHablotengo)) {
        await crypto.parseKeyPair(credentials[kHablotengo]);
        result[kHablotengo] = credentials[kHablotengo];
      }
      if (context.mounted) Navigator.of(context).pop(result);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: MediaQuery.of(context).size.width / 2,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Paste Credentials', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 15,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: '{\n  "identity": { ... },\n  "$kHablotengo": { ... }\n}',
                errorText: _error,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _submit, child: const Text('Sign In')),
          ]),
        ),
      ),
    );
  }
}
