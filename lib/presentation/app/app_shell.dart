import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap.dart';
import '../../content/lessons/earth_topic_one.dart';
import '../components/strannik_button.dart';
import '../components/strannik_speech_bubble.dart';
import '../../core/result.dart';
import '../bank/bank_screen.dart';
import '../stages/stage_progress_screen.dart';

import '../profile/profile_controller.dart';
import '../learning/learning_screen.dart';
import '../profile/profile_screen.dart';
import '../store/store_controller.dart';
import '../store/store_screen.dart';

import '../assets/presentation_assets.dart';
import '../components/strannik_bottom_navigation.dart';
import '../foundation/app_tokens.dart';
import '../home/home_controller.dart';
import '../home/home_screen.dart';
import '../placeholders/destination_placeholder.dart';
import 'app_destination.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.controller,
    this.profile,
    this.store,
    this.onReset,
  });
  final HomeController controller;
  final ProfileController? profile;
  final StoreController? store;
  final Future<void> Function()? onReset;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppDestination _destination = AppDestination.home;
  AppDestination _storeReturn = AppDestination.home;
  Timer? _checkpoint;
  bool _goalTutorial = false;
  static const _goalTutorialId = 'earth_goal_bank_tutorial_v1';
  Future<void> _checkGoalTutorial() async {
    final result = await widget.controller.unitOfWork.run(
      (r) async =>
          (await r.learning.learningProgress(EarthTopicOne.goalId)).completed &&
          !(await r.system.shownTooltips()).contains(_goalTutorialId),
    );
    if (mounted && result is Success<bool>) {
      setState(() => _goalTutorial = result.value);
    }
  }

  Future<void> _dismissGoalTutorial({bool openBank = false}) async {
    final result = await widget.controller.unitOfWork.run(
      (r) => r.system.markTooltipShown(_goalTutorialId),
    );
    if (!mounted) return;
    if (result is Success) {
      setState(() => _goalTutorial = false);
      if (openBank) _navigate(AppDestination.bank);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.profile?.playtime.start();
    _checkpoint = Timer.periodic(const Duration(seconds: 15), (_) {
      widget.profile?.playtime.checkpoint().catchError((Object _) {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.load();
      _checkGoalTutorial();
    });
  }

  @override
  void dispose() {
    _checkpoint?.cancel();
    widget.profile?.playtime.checkpoint(stop: true).catchError((Object _) {});
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.profile?.overview == null ||
          widget.profile?.overview?.profile?.onboardingCompleted == true) {
        widget.profile?.playtime.start();
      }
      widget.controller.load();
    } else {
      widget.profile?.playtime.checkpoint(stop: true).catchError((Object _) {});
      widget.profile?.logout();
    }
  }

  void _navigate(AppDestination destination) {
    if (_destination == destination) return;
    if (destination == AppDestination.store) {
      _storeReturn = _destination == AppDestination.bank
          ? AppDestination.bank
          : AppDestination.home;
    }
    widget.profile?.logout();
    widget.profile?.playtime.start();
    widget.controller.dismissReaction();
    setState(() => _destination = destination);
    if (destination == AppDestination.home) {
      widget.controller.load();
      _checkGoalTutorial();
    }
    if (destination == AppDestination.store) {
      widget.store?.select(null);
      widget.store?.load();
    }
  }

  @override
  Widget build(BuildContext context) =>
      _destination == AppDestination.stages && widget.controller.content != null
      ? StageProgressScreen(
          game: GameServices(
            unitOfWork: widget.controller.unitOfWork,
            content: widget.controller.content!,
          ),
          onHome: () => _navigate(AppDestination.home),
          onLearning: () => _navigate(AppDestination.learning),
          onStore: () => _navigate(AppDestination.store),
          onBank: () => _navigate(AppDestination.bank),
        )
      : _destination == AppDestination.bank && widget.controller.content != null
      ? BankScreen(
          game: GameServices(
            unitOfWork: widget.controller.unitOfWork,
            content: widget.controller.content!,
          ),
          onHome: () => _navigate(AppDestination.home),
          onStore: () => _navigate(AppDestination.store),
        )
      : _destination == AppDestination.learning &&
            widget.controller.content != null
      ? LearningScreen(
          unitOfWork: widget.controller.unitOfWork,
          content: widget.controller.content!,
          onBack: () => _navigate(AppDestination.home),
          onChanged: () async {
            await widget.controller.load();
            await widget.profile?.load();
          },
        )
      : _destination == AppDestination.childProfile && widget.profile != null
      ? Scaffold(
          backgroundColor: AppColors.lightBlue,
          body: SafeArea(
            child: ProfileScreen(
              controller: widget.profile!,
              onBack: () => _navigate(AppDestination.home),
              onReset: () async {
                setState(() => _destination = AppDestination.home);
                await widget.onReset?.call();
              },
            ),
          ),
        )
      : _destination == AppDestination.store && widget.store != null
      ? StoreScreen(
          controller: widget.store!,
          onHome: () => _navigate(_storeReturn),
          onLearning: () => _navigate(AppDestination.learning),
        )
      : PopScope(
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
                  PresentationAssets.backgroundFor(
                    widget.controller.state.effectiveStage,
                  ),
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
                if (_destination == AppDestination.home && _goalTutorial) ...[
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0x73001A33)),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 96,
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const StrannikSpeechBubble(
                            name: 'Странник',
                            compact: true,
                            showName: false,
                            child: Text(
                              'Твоя цель теперь живёт в кошельке. Заглядывай туда, чтобы закидывать монеты!',
                              style: AppTypography.body,
                            ),
                          ),
                          StrannikButton(
                            label: 'Открыть Банк',
                            backgroundColor: AppColors.blue,
                            onPressed: () =>
                                _dismissGoalTutorial(openBank: true),
                          ),
                          TextButton(
                            onPressed: _dismissGoalTutorial,
                            child: const Text(
                              'Понятно',
                              style: AppTypography.badge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
}
