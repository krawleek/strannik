import 'package:flutter/material.dart';

import '../app/app_destination.dart';
import '../components/strannik_button.dart';
import '../foundation/app_tokens.dart';

/// Temporary destination, not a proposal for any final product screen.
class DestinationPlaceholder extends StatelessWidget {
  const DestinationPlaceholder({
    super.key,
    required this.destination,
    required this.onHome,
  });
  final AppDestination destination;
  final VoidCallback onHome;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.yellow,
    child: Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.group),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                destination.label,
                style: AppTypography.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Временный экран разработки.',
                style: AppTypography.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              StrannikButton(label: 'Вернуться домой', onPressed: onHome),
            ],
          ),
        ),
      ),
    ),
  );
}
