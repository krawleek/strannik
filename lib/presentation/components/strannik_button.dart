import 'package:flutter/material.dart';

import '../foundation/app_tokens.dart';
import 'strannik_tap_target.dart';

class StrannikButton extends StatelessWidget {
  const StrannikButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.backgroundColor,
    this.foregroundColor,
    this.child,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final Color? backgroundColor, foregroundColor;
  final Widget? child;
  @override
  Widget build(BuildContext context) => StrannikTapTarget(
    label: label,
    onTap: onPressed,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: CustomPaint(
        foregroundPainter: const _ButtonBevel(),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonHorizontal,
            vertical: AppSpacing.buttonVertical,
          ),
          color: onPressed == null
              ? AppColors.gray
              : backgroundColor ??
                    (secondary ? AppColors.yellow : AppColors.green),
          child:
              child ??
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.button.copyWith(
                  color:
                      foregroundColor ??
                      (secondary || onPressed == null
                          ? AppColors.blue
                          : AppColors.white),
                ),
              ),
        ),
      ),
    ),
  );
}

// Figma's paired inset highlights, without an audio/UI dependency or Material skin.
class _ButtonBevel extends CustomPainter {
  const _ButtonBevel();
  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final dark = Paint()
      ..color = const Color(0x40000000)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(2, size.height)
        ..lineTo(2, 12)
        ..quadraticBezierTo(2, 2, 12, 2)
        ..lineTo(size.width, 2),
      light,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - 2)
        ..lineTo(size.width - 12, size.height - 2)
        ..quadraticBezierTo(
          size.width - 2,
          size.height - 2,
          size.width - 2,
          size.height - 12,
        )
        ..lineTo(size.width - 2, 0),
      dark,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
