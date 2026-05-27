import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';
import 'sign_in_state.dart';

class ExportKeysButton extends StatelessWidget {
  final Json rawStatement;
  const ExportKeysButton({super.key, required this.rawStatement});

  Uri _buildUrl() {
    final delegateToken = getToken(rawStatement['I'] as Map<String, dynamic>);
    final identityToken = (rawStatement['with'] as Map<String, dynamic>)['verifiedIdentity'] as String;
    final streamKey = '${delegateToken}_$identityToken';
    final authPacket = <String, dynamic>{
      'identity': signInState.identityJson!,
      if (!signInState.isDemo) ...{
        'sessionTime': signInState.sessionTime!,
        'sessionSignature': signInState.sessionSignature!,
      },
    };
    return Uri.parse(habloExportUrl).replace(queryParameters: {
      'spec': streamKey,
      'auth': jsonEncode(authPacket),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (ctx) {
      Offset tapPosition = Offset.zero;
      return GestureDetector(
        onTapDown: (d) => tapPosition = d.globalPosition,
        onTap: () {
          final uri = _buildUrl();
          final screenSize = MediaQuery.of(ctx).size;
          const dialogH = 60.0;
          final dialogW = (screenSize.width - 16).clamp(0.0, 420.0);
          double left = tapPosition.dx;
          double top = tapPosition.dy;
          if (left + dialogW > screenSize.width) left = tapPosition.dx - dialogW;
          if (top + dialogH > screenSize.height) top = tapPosition.dy - dialogH;
          if (left < 0) left = 0;
          if (top < 0) top = 0;
          showGeneralDialog<void>(
            context: ctx,
            barrierDismissible: true,
            barrierLabel: '',
            barrierColor: Colors.black12,
            transitionDuration: Duration.zero,
            pageBuilder: (context, a1, a2) => Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: Material(
                    elevation: 12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: dialogW,
                        child: InkWell(
                          onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
                          child: const Text(
                            'Private signed statements',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.key_outlined, size: 18, color: Colors.blue),
        ),
      );
    });
  }
}
