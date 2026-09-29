import 'package:flutter/material.dart';

import '../app/app_destination.dart';
import '../assets/presentation_assets.dart';
import '../components/strannik_button.dart';
import '../components/strannik_speech_bubble.dart';
import '../components/strannik_stage_badge.dart';
import '../components/strannik_tap_target.dart';
import '../foundation/app_tokens.dart';
import 'home_controller.dart';
import 'home_view_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onNavigate,
  });
  final HomeController controller;
  final ValueChanged<AppDestination> onNavigate;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final state = controller.state;
      if (state.status == HomeLoadStatus.loading) {
        return const Center(
          child: Text('Открываем дом…', style: AppTypography.body),
        );
      }
      if (state.status == HomeLoadStatus.failed ||
          state.status == HomeLoadStatus.needsOnboarding) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.status == HomeLoadStatus.failed
                      ? 'Не получилось открыть дом'
                      : 'Знакомство со Странником ещё впереди',
                  textAlign: TextAlign.center,
                  style: AppTypography.heading,
                ),
                const SizedBox(height: 24),
                if (state.status == HomeLoadStatus.failed)
                  StrannikButton(
                    label: 'Попробовать снова',
                    onPressed: controller.load,
                  ),
                if (state.status == HomeLoadStatus.needsOnboarding)
                  const Text(
                    'Экран знакомства появится на следующем этапе.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body,
                  ),
              ],
            ),
          ),
        );
      }
      return _Scene(
        controller: controller,
        state: state,
        onNavigate: onNavigate,
      );
    },
  );
}

class _Scene extends StatelessWidget {
  const _Scene({
    required this.controller,
    required this.state,
    required this.onNavigate,
  });
  final HomeController controller;
  final HomeViewState state;
  final ValueChanged<AppDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    final pet = state.snapshot?.pet;
    final profile = state.snapshot?.profile;
    final petAsset = pet == null
        ? const AssetChoice(PresentationAssets.orangeCat)
        : PresentationAssets.skin(pet.skinId);
    final avatar = profile == null
        ? const AssetChoice(PresentationAssets.girlAvatar)
        : PresentationAssets.avatar(profile.avatarId);
    final petName = pet?.childGivenName ?? DevelopmentHomePreview.petName;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Only the illustrative scene is positioned. Header/nav stay in normal flow.
        final petWidth = (constraints.maxWidth - 39).clamp(0.0, 380.0);
        final petHeight = petWidth * 350 / 321;
        final bottomGap = constraints.maxHeight >= 500 ? 39.0 : 12.0;
        final topOffset = (constraints.maxHeight - bottomGap - petHeight).clamp(
          75.0,
          double.infinity,
        );
        return Stack(
          children: [
            Positioned(
              left: (constraints.maxWidth - petWidth) / 2 + .5,
              top: topOffset,
              width: petWidth,
              height: petHeight,
              child: StrannikTapTarget(
                label: '$petName. Действия с питомцем',
                expanded: state.actionsOpen,
                onTap: state.busy ? null : controller.toggleActions,
                child: Image.asset(
                  petAsset.path,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 75,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: StrannikStageBadge(
                          stageNumber: state.effectiveStage.index + 1,
                          progressLabel: DevelopmentHomePreview.stageProgress,
                          onTap: () => onNavigate(AppDestination.stages),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 154,
                        height: 75,
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              width: 122,
                              height: 75,
                              child: IgnorePointer(
                                child: Image.asset(
                                  PresentationAssets.petAvatar,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 72,
                              top: 0,
                              width: 83,
                              height: 67,
                              child: IgnorePointer(
                                child: Image.asset(avatar.path),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 0,
                              width: 72,
                              height: 75,
                              child: StrannikTapTarget(
                                label: 'Профиль питомца',
                                onTap: () =>
                                    onNavigate(AppDestination.petProfile),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            Positioned(
                              left: 72,
                              top: 0,
                              width: 82,
                              height: 75,
                              child: StrannikTapTarget(
                                label: 'Профиль ребёнка',
                                onTap: () =>
                                    onNavigate(AppDestination.childProfile),
                                child: const SizedBox.expand(),
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
            if (state.isPreview)
              Positioned(
                left: 16,
                bottom: 0,
                child: Semantics(
                  label: 'Предпросмотр для разработки. Игровые данные не создаются.',
                  child: const Text(
                    'Предпросмотр',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue,
                    ),
                  ),
                ),
              ),
            if (state.actionsOpen || state.reaction != null) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: state.busy ? null : controller.dismissReaction,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 86,
                bottom: 16,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 328),
                    child: SingleChildScrollView(
                      child: StrannikSpeechBubble(
                        name: petName,
                        child: state.actionsOpen
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StrannikButton(
                                    label: state.busy ? 'Подожди…' : 'Угостить',
                                    onPressed: state.busy
                                        ? null
                                        : controller.giveTreat,
                                  ),
                                  const SizedBox(height: 10),
                                  StrannikButton(
                                    label: 'Поиграть',
                                    secondary: true,
                                    onPressed: state.busy
                                        ? null
                                        : controller.play,
                                  ),
                                  const SizedBox(height: 10),
                                  StrannikButton(
                                    label: 'Погладить',
                                    secondary: true,
                                    onPressed: state.busy
                                        ? null
                                        : controller.strokePet,
                                  ),
                                  if (pet?.equippedAccessoryId != null) ...[
                                    const SizedBox(height: 14),
                                    _AccessoryNote(
                                      id: pet!.equippedAccessoryId!,
                                    ),
                                  ],
                                  if (petAsset.isFallback || avatar.isFallback)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Text(
                                        'Внешний вид пока показан на примере.',
                                        textAlign: TextAlign.center,
                                        style: AppTypography.body,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  StrannikTapTarget(
                                    label: 'Закрыть действия',
                                    onTap: state.busy
                                        ? null
                                        : controller.dismissReaction,
                                    child: const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: Text(
                                        'Закрыть',
                                        style: AppTypography.body,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      state.reaction!,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.body,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  StrannikButton(
                                    label: 'Хорошо',
                                    secondary: true,
                                    onPressed: controller.dismissReaction,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AccessoryNote extends StatelessWidget {
  const _AccessoryNote({required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final asset = PresentationAssets.accessory(id);
    return Row(
      children: [
        Image.asset(
          asset.path,
          width: 32,
          height: 36,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            asset.isFallback
                ? 'Аксессуар надет. Его рисунок появится позже.'
                : 'Аксессуар надет.',
            style: AppTypography.body,
          ),
        ),
      ],
    );
  }
}
