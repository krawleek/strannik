import 'package:flutter/material.dart';

import '../app/app_destination.dart';
import '../assets/presentation_assets.dart';
import '../foundation/app_tokens.dart';
import 'strannik_tap_target.dart';

class StrannikBottomNavigation extends StatelessWidget {
  const StrannikBottomNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final AppDestination selected;
  final ValueChanged<AppDestination> onSelected;
  static const _assets = [
    PresentationAssets.home,
    PresentationAssets.store,
    PresentationAssets.bank,
    PresentationAssets.learning,
  ];
  static const _sizes = [
    Size(67, 66),
    Size(56, 68),
    Size(66, 59),
    Size(67, 59),
  ];
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 88,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.navigationGap - 4),
              StrannikTapTarget(
                label: AppDestination.values[i].label,
                selected: selected == AppDestination.values[i],
                onTap: () => onSelected(AppDestination.values[i]),
                child: SizedBox(
                  width: _sizes[i].width,
                  height: 68,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Image.asset(
                      _assets[i],
                      width: _sizes[i].width,
                      height: _sizes[i].height,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
