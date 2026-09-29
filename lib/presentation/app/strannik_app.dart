import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/app_tokens.dart';
import '../home/home_controller.dart';
import 'app_shell.dart';
import '../onboarding/onboarding_controller.dart';
import '../onboarding/onboarding_flow.dart';
import '../components/strannik_button.dart';

class StrannikApp extends StatelessWidget {
  const StrannikApp({super.key, required this.controller, this.onboarding});
  final HomeController controller;
  final OnboardingController? onboarding;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Странник',
    theme: ThemeData(
      fontFamily: AppTypography.family,
      scaffoldBackgroundColor: AppColors.yellow,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
      textTheme: const TextTheme(bodyMedium: AppTypography.body),
    ),
    home: AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: onboarding == null
          ? _home()
          : ListenableBuilder(
              listenable: onboarding!,
              builder: (_, _) {
                final flow = onboarding!;
                if (flow.completed == true) return _home();
                if (flow.completed == false) {
                  return OnboardingFlow(controller: flow);
                }
                return Scaffold(
                  backgroundColor: AppColors.blue,
                  body: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              flow.error ?? 'Открываем игру…',
                              textAlign: TextAlign.center,
                              style: AppTypography.body.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                            if (flow.error != null) ...[
                              const SizedBox(height: 24),
                              StrannikButton(
                                label: 'Попробовать снова',
                                onPressed: flow.busy ? null : flow.load,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    ),
  );
  Widget _home() => ListenableBuilder(
    listenable: controller,
    builder: (_, _) => AppShell(controller: controller),
  );
}
