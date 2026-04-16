import 'package:flutter/material.dart';
import 'package:hablotengo/ui/ht_theme.dart';

class HtLogo extends StatelessWidget {
  final double size;
  final bool light;
  const HtLogo({super.key, this.size = 40, this.light = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _LogoMark(size: size),
        const SizedBox(width: 10),
        _LogoText(size: size, light: light),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.chat_bubble_rounded, color: Colors.white, size: size * 0.64),
          Positioned(
            bottom: size * 0.16,
            child: Icon(Icons.person, color: kGradientStart, size: size * 0.32),
          ),
        ],
      ),
    );
  }
}

class _LogoText extends StatelessWidget {
  final double size;
  final bool light;
  const _LogoText({required this.size, required this.light});

  @override
  Widget build(BuildContext context) {
    final baseColor = light ? Colors.white : kGradientStart;
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Hablo',
            style: TextStyle(
              color: baseColor,
              fontSize: size * 0.52,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: 'Tengo',
            style: TextStyle(
              color: light ? kAccent : kGradientEnd,
              fontSize: size * 0.52,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: '!',
            style: TextStyle(
              color: light ? kAccent : kGradientEnd,
              fontSize: size * 0.52,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient header widget used at the top of screens.
class HtHeader extends StatelessWidget {
  final List<Widget> actions;
  final Widget? bottom;
  const HtHeader({super.key, this.actions = const [], this.bottom});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: kHeaderGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  const HtLogo(size: 36),
                  const Spacer(),
                  ...actions,
                ],
              ),
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}
