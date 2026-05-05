import 'package:flutter/material.dart';
import 'package:nerdster_common/labeler.dart';
import 'package:nerdster_common/ui/json_interpreter.dart';
import 'package:oneofus_common/ui/json_display.dart';

class CryptoShieldButton extends StatelessWidget {
  final dynamic statement;
  final Labeler? labeler;
  const CryptoShieldButton({super.key, required this.statement, this.labeler});

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (ctx) {
      Offset tapPosition = Offset.zero;
      return GestureDetector(
        onTapDown: (d) => tapPosition = d.globalPosition,
        onTap: () {
          final screenSize = MediaQuery.of(ctx).size;
          final dialogW = (screenSize.width - 16).clamp(0.0, 420.0);
          final dialogH = (screenSize.height - 16).clamp(0.0, 390.0);
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
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: dialogW,
                        height: dialogH,
                        child: JsonDisplay(
                          statement,
                          interpret: ValueNotifier(true),
                          interpreter: labeler != null ? JsonInterpreter(labeler!) : null,
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
          child: Icon(Icons.verified_user_outlined, size: 18, color: Colors.blue),
        ),
      );
    });
  }
}
