import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../content/lessons/discount_traps_lesson.dart';
import '../assets/presentation_assets.dart';
import '../components/strannik_button.dart';
import '../components/strannik_speech_bubble.dart';
import '../components/strannik_tap_target.dart';
import '../foundation/app_tokens.dart';
import 'discount_traps_controller.dart';
import 'learning_screen.dart';

class DiscountTrapsScreen extends StatelessWidget {
  const DiscountTrapsScreen({
    super.key,
    required this.controller,
    required this.onClose,
  });
  final DiscountTrapsController controller;
  final Future<void> Function() onClose;
  DiscountTrapsController get c => controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final story = c.step <= 1;
      final playing = c.step == DiscountTrapsLesson.gameStep;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !c.busy) onClose();
        },
        child: Scaffold(
          backgroundColor: AppColors.yellow,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (story)
                lessonArt('discount_store', fit: BoxFit.cover)
              else if (c.step != DiscountTrapsLesson.rewardStep)
                const LessonBackground(patternColor: Color(0xFFF7D999)),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final extra =
                        math.max(
                          0.0,
                          MediaQuery.textScalerOf(context).scale(14) / 14 - 1,
                        ) *
                        420;
                    return SingleChildScrollView(
                      physics: playing
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      child: SizedBox(
                        height: math.max(
                          box.maxHeight,
                          playing ? box.maxHeight : 724 + extra,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _header(story),
                              Expanded(
                                child: switch (c.step) {
                                  DiscountTrapsLesson.rulesStep => _rules(),
                                  DiscountTrapsLesson.gameStep =>
                                    DiscountCatchingGame(controller: c),
                                  DiscountTrapsLesson.resultStep ||
                                  DiscountTrapsLesson.readyStep => _result(),
                                  DiscountTrapsLesson.rewardStep => _reward(),
                                  _ => _dialogue(story),
                                },
                              ),
                              if (c.error != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      c.error!,
                                      style: AppTypography.body,
                                    ),
                                  ),
                                ),
                              if (!playing)
                                StrannikButton(
                                  label: c.step < DiscountTrapsLesson.rulesStep
                                      ? DiscountTrapsLesson.actions[c.step]
                                      : c.step == DiscountTrapsLesson.rulesStep
                                      ? 'Начать ловить'
                                      : c.step == DiscountTrapsLesson.rewardStep
                                      ? 'Ура!'
                                      : 'Далее',
                                  backgroundColor:
                                      c.step == DiscountTrapsLesson.rewardStep
                                      ? AppColors.blue
                                      : AppColors.darkOrange,
                                  onPressed: c.busy
                                      ? null
                                      : c.step == DiscountTrapsLesson.rewardStep
                                      ? onClose
                                      : c.advance,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _header(bool story) => SizedBox(
    height: 48,
    child: Row(
      children: [
        StrannikTapTarget(
          label: 'Вернуться к заданиям этапа 2',
          onTap: c.busy ? null : onClose,
          child: const SizedBox(
            width: 32,
            height: 48,
            child: Icon(Icons.chevron_left, color: AppColors.black, size: 28),
          ),
        ),
        if (!story && c.step < DiscountTrapsLesson.gameStep)
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(width: 3),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (c.step / 18).clamp(0, 1),
                      heightFactor: 1,
                      child: const ColoredBox(color: AppColors.darkOrange),
                    ),
                  ),
                ),
                Positioned(
                  left: 120,
                  child: Image.asset(
                    PresentationAssets.star,
                    width: 43,
                    height: 41,
                  ),
                ),
                Positioned(
                  right: 0,
                  child: Image.asset(
                    PresentationAssets.star,
                    width: 43,
                    height: 41,
                  ),
                ),
              ],
            ),
          ),
        if (story) const Spacer(),
        if (story)
          StrannikTapTarget(
            label: 'Закрыть урок',
            onTap: c.busy ? null : onClose,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.close, color: AppColors.black),
            ),
          ),
      ],
    ),
  );

  Widget _bubble(String text, {bool human = false}) => StrannikSpeechBubble(
    name: '',
    showName: false,
    compact: true,
    child: Text(
      text,
      style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  Widget _dialogue(bool story) => LayoutBuilder(
    builder: (context, box) {
      final human = DiscountTrapsLesson.human(c.step);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: story ? box.maxHeight * .28 : 32,
            left: 36,
            right: 22,
            child: human
                ? const SizedBox()
                : _bubble(DiscountTrapsLesson.lines[c.step]),
          ),
          Positioned(
            left: story ? 90 : 11,
            right: story ? 30 : -16,
            top: story ? box.maxHeight * .46 : box.maxHeight * .29,
            height: story ? 190 : 300,
            child: _storeCat(),
          ),
          if (human)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _bubble(DiscountTrapsLesson.lines[c.step], human: true),
                  Positioned(
                    top: -38,
                    right: 8,
                    child: Image.asset(
                      PresentationAssets.girlAvatar,
                      width: 70,
                      height: 56,
                    ),
                  ),
                ],
              ),
            ),
          if ({3, 4, 8, 12, 13, 14}.contains(c.step))
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              height: 205,
              child: _example(),
            ),
          if (c.step == 15)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: _bubble(
                'Я больше никогда не буду смотреть на магазин теми же глазами что и раньше...',
                human: true,
              ),
            ),
        ],
      );
    },
  );

  Widget _storeCat() => FittedBox(
    child: SizedBox(
      width: 331,
      height: 300,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 38,
            top: 261,
            width: 228,
            height: 39,
            child: lessonArt('cat_shadow'),
          ),
          Positioned(
            left: -17.56,
            top: -32.25,
            width: 366,
            height: 367.1,
            child: Image.asset(
              'assets/onboarding/skin_gray.png',
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            left: 91,
            top: 43,
            width: 165,
            height: 74,
            child: lessonArt('glasses'),
          ),
        ],
      ),
    ),
  );

  Widget _example() {
    if (c.step == 14) {
      return Row(
        children: [
          Expanded(
            child: _exampleProduct('discount_gummy_big', '10 фир\n100 граммов'),
          ),
          Expanded(
            child: _exampleProduct(
              'discount_gummy_small',
              '10 фир\n80 граммов',
            ),
          ),
        ],
      );
    }
    if (c.step == 8) {
      return Column(
        children: [
          Expanded(child: lessonArt('discount_two_chips')),
          const Text(
            'Чипсы 1+1\n75 фир',
            textAlign: TextAlign.center,
            style: AppTypography.counter,
          ),
        ],
      );
    }
    return _exampleProduct('discount_dialogue_juice', switch (c.step) {
      3 => '50',
      4 => '50 фир\n100',
      12 => '10 фир\nскидка по карте',
      _ => '15 фир\nобычная цена',
    });
  }

  Widget _exampleProduct(String asset, String label) => Column(
    children: [
      Expanded(child: lessonArt(asset)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(width: 3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(fontSize: 18),
        ),
      ),
    ],
  );

  Widget _rules() => Column(
    children: [
      const SizedBox(height: 16),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text('Поймай нужную скидку!', style: AppTypography.heading),
      ),
      const SizedBox(height: 28),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: _bubble(DiscountTrapsLesson.avoid),
      ),
      Expanded(child: _storeCat()),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            DiscountPriceTag(offer: DiscountTrapsLesson.offers[2], large: true),
            DiscountPriceTag(offer: DiscountTrapsLesson.offers[3], large: true),
            DiscountPriceTag(offer: DiscountTrapsLesson.offers[1], large: true),
          ],
        ),
      ),
      const SizedBox(height: 44),
    ],
  );

  Widget _result() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            lessonArt('discount_cat', width: 331, height: 300),
            lessonArt('discount_basket', width: 159, height: 125),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text('10 из 10!', style: AppTypography.heading.copyWith(fontSize: 36)),
      const SizedBox(height: 20),
      const Text('Игра окончена!', style: AppTypography.counter),
      const SizedBox(height: 20),
      const Text('Готово! Переходим к награде…', style: AppTypography.body),
      const SizedBox(height: 28),
    ],
  );

  Widget _reward() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        child: lessonArt('discount_reward_cat', width: 209, height: 265),
      ),
      const SizedBox(height: 20),
      Text(
        'Задание\nвыполнено!',
        style: AppTypography.heading.copyWith(
          fontSize: 36,
          color: AppColors.black,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(
            child: _rewardLabel(
              c.rewardClaimed ? 'XP уже получен' : '+${c.task.rewardXp}',
              AppColors.lightOrange,
              xp: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _rewardLabel(
              c.rewardClaimed ? 'Получено' : '+${c.task.rewardFira}',
              AppColors.white,
              xp: false,
            ),
          ),
        ],
      ),
      if (c.rewardClaimed)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Задание пройдено повторно. Награда уже получена.',
            style: AppTypography.body,
            textAlign: TextAlign.center,
          ),
        ),
      const SizedBox(height: 48),
    ],
  );
  Widget _rewardLabel(
    String label,
    Color color, {
    required bool xp,
  }) => Semantics(
    label: xp ? '${c.task.rewardXp} XP' : '${c.task.rewardFira} фир',
    child: SizedBox(
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 4,
            bottom: 4,
            child: Container(
              padding: EdgeInsets.only(left: xp ? 48 : 8, right: xp ? 8 : 36),
              alignment: xp ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                gradient: xp
                    ? const LinearGradient(
                        colors: [Color(0xFFFFB783), AppColors.darkOrange],
                      )
                    : null,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AppTypography.counter.copyWith(color: AppColors.black),
                ),
              ),
            ),
          ),
          if (xp)
            Positioned(
              left: -2,
              top: 0,
              child: Image.asset(
                PresentationAssets.star,
                width: 43,
                height: 41,
                excludeFromSemantics: true,
              ),
            )
          else
            Positioned(
              right: 0,
              top: 0,
              child: lessonArt('safety_coin', width: 32, height: 42),
            ),
        ],
      ),
    ),
  );
}

class DiscountPriceTag extends StatelessWidget {
  const DiscountPriceTag({super.key, required this.offer, this.large = false});
  final DiscountOffer offer;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final (fill, border) = switch (offer.tag) {
      DiscountTag.yellow => (const Color(0xFFFBD200), const Color(0xFFEC2C2F)),
      DiscountTag.blue => (AppColors.lightBlue, AppColors.blue),
      DiscountTag.orange => (AppColors.lightOrange, AppColors.darkOrange),
      DiscountTag.green => (const Color(0xFFA8EAC6), AppColors.green),
    };
    final lines = offer.label.split('\n');
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 6,
          vertical: large ? 6 : 4,
        ),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border, width: 2.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lines.first,
              style: AppTypography.body.copyWith(
                fontSize: large ? 20 : 13,
                color: offer.tag == DiscountTag.yellow
                    ? border
                    : AppColors.black,
              ),
            ),
            if (lines.length > 1)
              Text(
                lines.last,
                style: AppTypography.body.copyWith(
                  fontSize: large ? 12 : 9,
                  color: offer.tag == DiscountTag.orange
                      ? const Color(0xFFEC2C2F)
                      : AppColors.black,
                  decoration: offer.tag == DiscountTag.orange
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Basket movement and elapsed frames are ephemeral. Every resolved falling
/// item is saved before another can score, including after an app restart.
class DiscountCatchingGame extends StatefulWidget {
  const DiscountCatchingGame({super.key, required this.controller});
  final DiscountTrapsController controller;
  @override
  State<DiscountCatchingGame> createState() => _DiscountCatchingGameState();
}

class _DiscountCatchingGameState extends State<DiscountCatchingGame>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker ticker;
  Duration? previous;
  double fall = 0, basket = .5;
  bool foreground = true, paused = false, resolving = false;
  int shownRound = 0;
  DiscountTrapsController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    shownRound = c.progress.round;
    WidgetsBinding.instance.addObserver(this);
    ticker = createTicker(_tick)..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    previous = null;
  }

  double lane(int round) =>
      const [.1, .55, .9, .3, .7, .12, .5, .85][round % 8];
  void _tick(Duration elapsed) {
    final delta = previous == null
        ? 0.0
        : (elapsed - previous!).inMicroseconds / 1000000;
    previous = elapsed;
    if (!foreground ||
        paused ||
        c.busy ||
        c.progress.feedback ||
        c.error != null ||
        resolving ||
        c.step != DiscountTrapsLesson.gameStep) {
      return;
    }
    if (shownRound != c.progress.round) {
      shownRound = c.progress.round;
      fall = 0;
    }
    setState(() => fall += delta.clamp(0, .05) / 4.5);
    if (fall >= 1) _resolve((basket - lane(shownRound)).abs() < .19);
  }

  Future<void> _resolve(bool caught) async {
    if (resolving || c.busy) return;
    resolving = true;
    await c.resolve(shownRound, caught: caught);
    if (!mounted) return;
    setState(() {
      resolving = false;
      if (c.progress.round != shownRound) {
        shownRound = c.progress.round;
        fall = 0;
      }
    });
  }

  @override
  void dispose() {
    ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        label: 'Собрано ${c.progress.caught} из 10',
        liveRegion: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 10; i++)
              Opacity(
                opacity: i < c.progress.caught ? 1 : .35,
                child: Image.asset(
                  PresentationAssets.star,
                  width: 25,
                  height: 24,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          DiscountTrapsLesson.rule,
          style: AppTypography.badge.copyWith(color: AppColors.black),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          DiscountPriceTag(offer: DiscountTrapsLesson.offers.first),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Нужны только желтые', style: AppTypography.body),
          ),
          IconButton(
            tooltip: paused ? 'Продолжить' : 'Пауза',
            onPressed: () => setState(() => paused = !paused),
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
          ),
        ],
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) => GestureDetector(
            key: const ValueKey('discount-field'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) => setState(
              () => basket = (basket + details.delta.dx / (box.maxWidth - 112))
                  .clamp(0, 1),
            ),
            onTapDown: (details) => setState(
              () => basket =
                  ((details.localPosition.dx - 56) / (box.maxWidth - 112))
                      .clamp(0, 1),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (var offset = 3; offset >= 0; offset--)
                  if (fall - offset * .25 >= 0)
                    Positioned(
                      left: lane(shownRound + offset) * (box.maxWidth - 84),
                      top: (fall - offset * .25) * (box.maxHeight - 190),
                      child: Semantics(
                        label:
                            '${DiscountTrapsLesson.offers[(shownRound + offset) % 8].name}, ${DiscountTrapsLesson.offers[(shownRound + offset) % 8].label}, ${DiscountTrapsLesson.offers[(shownRound + offset) % 8].tag == DiscountTag.yellow ? 'желтый ценник' : 'другой ценник'}',
                        child: SizedBox(
                          width: 84,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              lessonArt(
                                DiscountTrapsLesson
                                    .offers[(shownRound + offset) % 8]
                                    .asset,
                                width: 80,
                                height: 80,
                              ),
                              DiscountPriceTag(
                                offer: DiscountTrapsLesson
                                    .offers[(shownRound + offset) % 8],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                Positioned(
                  left: basket * (box.maxWidth - 112),
                  bottom: 16,
                  child: Semantics(
                    label: 'Корзина',
                    onIncrease: () =>
                        setState(() => basket = (basket + .2).clamp(0, 1)),
                    onDecrease: () =>
                        setState(() => basket = (basket - .2).clamp(0, 1)),
                    child: lessonArt('discount_basket', width: 112, height: 88),
                  ),
                ),
                if (paused || c.progress.feedback || c.error != null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppColors.yellow.withValues(alpha: .94),
                      child: Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  paused ? 'Пауза' : DiscountTrapsLesson.rule,
                                  style: AppTypography.heading,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                if (!paused)
                                  Text(
                                    c.progress.missedTarget
                                        ? 'Нужны только желтые'
                                        : DiscountTrapsLesson.avoid,
                                    style: AppTypography.body,
                                    textAlign: TextAlign.center,
                                  ),
                                const SizedBox(height: 24),
                                StrannikButton(
                                  label: 'Продолжить',
                                  onPressed: c.busy
                                      ? null
                                      : () async {
                                          if (paused) {
                                            setState(() => paused = false);
                                          } else if (c.progress.feedback) {
                                            await c.retry();
                                          } else {
                                            await _resolve(
                                              (basket - lane(shownRound))
                                                      .abs() <
                                                  .19,
                                            );
                                          }
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      const Text(
        'Свайпай корзину влево и вправо',
        style: AppTypography.body,
        textAlign: TextAlign.center,
      ),
    ],
  );
}
