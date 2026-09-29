import 'package:flutter/material.dart';

import '../assets/presentation_assets.dart';
import '../components/strannik_bottom_navigation.dart';
import '../foundation/app_tokens.dart';
import '../home/home_controller.dart';
import '../home/home_screen.dart';
import '../placeholders/destination_placeholder.dart';
import 'app_destination.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final HomeController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppDestination _destination = AppDestination.home;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.load();
  }

  void _navigate(AppDestination destination) {
    if (_destination == destination) return;
    widget.controller.dismissReaction();
    setState(() => _destination = destination);
    if (destination == AppDestination.home) widget.controller.load();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop:
        _destination == AppDestination.home &&
        !widget.controller.state.actionsOpen &&
        widget.controller.state.reaction == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        widget.controller.dismissReaction();
        setState(() => _destination = AppDestination.home);
      }
    },
    child: Scaffold(
      backgroundColor: AppColors.yellow,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            PresentationAssets.room,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.high,
            excludeFromSemantics: true,
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _destination == AppDestination.home
                      ? HomeScreen(
                          controller: widget.controller,
                          onNavigate: _navigate,
                        )
                      : DestinationPlaceholder(
                          destination: _destination,
                          onHome: () => _navigate(AppDestination.home),
                        ),
                ),
                StrannikBottomNavigation(
                  selected: _destination,
                  onSelected: _navigate,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
