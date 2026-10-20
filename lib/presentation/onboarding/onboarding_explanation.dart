import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../components/strannik_button.dart';
import '../components/strannik_tap_target.dart';
import '../foundation/app_tokens.dart';
import 'onboarding_assets.dart';

/// The exported artwork contains only lines, coins and illustrations.
/// Paper, copy and navigation remain responsive Flutter widgets.
class OnboardingExplanation extends StatelessWidget {
  const OnboardingExplanation({
    super.key,
    required this.index,
    required this.onNext,
    required this.onSkip,
  });

  final int index;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;

  static const _titles = [
    'Покажу как управлять деньгами',
    'Знания в деле',
    'Следите\nза успехами',
  ];
  static const _bodies = [
    'Планировать бюджет, копить, выбирать покупки и безопасно тратить игровую валюту',
    'Ребёнок распределяет игровую валюту на нужды, желания и накопления и видит последствия своих решений',
    'В родительском разделе вы увидите, чему научился ребёнок, и сможете поощрять его игровой валютой',
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = constraints.maxWidth / 360;
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final height = math.max(constraints.maxHeight, 724 * scale);
      final safeTop = MediaQuery.viewPaddingOf(context).top;
      final paperTop = [405.4844, 130.0, 335.9067][index] * scale - safeTop;
      final paperLeft = [-21.0, 76.7602, 11.0][index] * scale;
      final paperWidth = 420 * scale;
      final paperHeight =
          [260.0, 233.0, 214.0][index] * scale +
          math.max(0, textScale - 1) * 180;
      return SingleChildScrollView(
        child: SizedBox(
          height: height + math.max(0, textScale - 1) * 180,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: paperLeft,
                top: paperTop,
                width: paperWidth,
                child: Transform.rotate(
                  angle: [-9.66, 4.96, -5.73][index] * math.pi / 180,
                  alignment: Alignment.topLeft,
                  child: Container(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFDED8E1),
                          offset: Offset(0, 8),
                        ),
                      ],
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          OnboardingAssets.image('receipt_edge'),
                          width: paperWidth,
                          height: 43.291 * scale,
                          fit: BoxFit.fill,
                          excludeFromSemantics: true,
                        ),
                        Container(
                          width: paperWidth,
                          constraints: BoxConstraints(
                            minHeight: paperHeight - 43.291 * scale,
                          ),
                          padding: EdgeInsets.fromLTRB(
                            [27.0, 25.0, 29.0][index] * scale,
                            16 * scale,
                            [107.0, 126.0, 80.0][index] * scale,
                            24 * scale,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(24),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _titles[index],
                                style: AppTypography.heading.copyWith(
                                  fontSize: 28,
                                  height: 1,
                                  color: AppColors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _bodies[index],
                                style: AppTypography.body.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Keep the illustration's 360:800 aspect ratio at both heights.
              Positioned(
                left: 0,
                right: 0,
                top: -safeTop,
                height: 800 * scale,
                child: Image.asset(
                  OnboardingAssets.image(
                    const [
                      'parent_money',
                      'parent_care_backdrop',
                      'parent_results',
                    ][index],
                  ),
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned(
                left: AppSpacing.screen,
                top: math.max(0, 52 - safeTop),
                child: StrannikTapTarget(
                  label: 'Пропустить',
                  onTap: onSkip,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Пропустить',
                      style: AppTypography.body.copyWith(color: AppColors.blue),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 28,
                child: Column(
                  children: [
                    Semantics(
                      label: 'Объяснение для родителя: ${index + 1} из 3',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (i) => Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == index
                                  ? AppColors.blue
                                  : AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    StrannikButton(label: 'Далее', onPressed: onNext),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
