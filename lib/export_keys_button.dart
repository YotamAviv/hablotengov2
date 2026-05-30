import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/ui/json_qr_display.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';
import 'error_dialog.dart';
import 'sign_in_state.dart';

class ExportKeysButton extends StatelessWidget {
  final Json rawStatement;
  const ExportKeysButton({super.key, required this.rawStatement});

  Future<Uri> _buildUrl() async {
    final delegateToken = getToken(rawStatement['I'] as Map<String, dynamic>);
    final identityToken = (rawStatement['with'] as Map<String, dynamic>)['verifiedIdentity'] as String;
    final streamKey = '${delegateToken}_$identityToken';
    final authPacket = signInState.isDemo
        ? <String, dynamic>{'identity': signInState.identityJson!}
        : await signInState.requestCredential() ?? signInState.authPayload()!;
    return Uri.parse(habloExportUrl).replace(queryParameters: {
      'spec': streamKey,
      'auth': jsonEncode(authPacket),
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final keyJson = rawStatement['I'] as Map<String, dynamic>;
        showDialog<void>(
          context: context,
          builder: (ctx) {
            const double width = 300;
            const double height = 400;
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: SizedBox(
                width: width,
                height: height,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Expanded(
                        child: JsonQrDisplay(keyJson, interpret: ValueNotifier(true)),
                      ),
                      InkWell(
                        onTap: () async {
                          try {
                            final uri = await _buildUrl();
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (e, st) {
                            if (ctx.mounted) ErrorDialog.show(ctx, 'Export failed', e, st);
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Private signed statements',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.key_outlined, size: 18, color: Colors.blue),
      ),
    );
  }
}
