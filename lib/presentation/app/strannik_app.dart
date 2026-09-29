import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/app_tokens.dart';
import '../home/home_controller.dart';
import 'app_shell.dart';

class StrannikApp extends StatelessWidget {
  const StrannikApp({super.key, required this.controller});
  final HomeController controller;
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
      child: ListenableBuilder(
        listenable: controller,
        builder: (_, _) => AppShell(controller: controller),
      ),
    ),
  );
}
