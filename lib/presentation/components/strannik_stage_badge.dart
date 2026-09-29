import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../assets/presentation_assets.dart';
import '../foundation/app_tokens.dart';
import 'strannik_tap_target.dart';

class StrannikStageBadge extends StatelessWidget {
  const StrannikStageBadge({
    super.key,
    required this.stageNumber,
    required this.progressLabel,
    required this.onTap,
    this.progressIsPlaceholder = true,
  });
  final int stageNumber;
  final String progressLabel;
  final bool progressIsPlaceholder;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => StrannikTapTarget(
    label:
        'Стадия $stageNumber. Прогресс${progressIsPlaceholder ? ', показатель пока демонстрационный' : ': $progressLabel'}',
    onTap: onTap,
    child: SizedBox(
      width: 126,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 22,
            right: 0,
            top: 8,
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.fromBorderSide(AppBorders.outlined),
                borderRadius: BorderRadius.circular(AppRadius.stageBadge),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 26, right: 8),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(progressLabel, style: AppTypography.counter),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -2,
            top: 1,
            width: 52,
            height: 50,
            child: Transform.rotate(
              angle: 15.73 * math.pi / 180,
              child: Image.asset(PresentationAssets.star),
            ),
          ),
          Positioned(
            left: 11,
            top: 8,
            width: 24,
            height: 34,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$stageNumber',
                  style: AppTypography.counter.copyWith(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
