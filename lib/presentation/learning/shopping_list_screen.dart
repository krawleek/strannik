import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../content/lessons/shopping_list_lesson.dart';
import '../../content/localization/fira_format.dart';
import '../../domain/models/models.dart';
import '../assets/presentation_assets.dart';
import '../components/strannik_button.dart';
import '../components/strannik_speech_bubble.dart';
import '../components/strannik_tap_target.dart';
import '../foundation/app_tokens.dart';
import 'learning_screen.dart';
import 'shopping_list_controller.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({
    super.key,
    required this.controller,
    required this.onClose,
  });
  final ShoppingListController controller;
  final Future<void> Function() onClose;
  ShoppingListController get c => controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final story = c.step < 5;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || c.busy) return;
          if (c.backStack.isEmpty || c.step == 13) {
            onClose();
          } else {
            c.back();
          }
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: AppColors.yellow,
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (story)
                  lessonArt('living_room', fit: BoxFit.cover)
                else if (c.step != 13)
                  const LessonBackground(),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final extra =
                          math.max(
                            0.0,
                            MediaQuery.textScalerOf(context).scale(14) / 14 - 1,
                          ) *
                          300;
                      return SingleChildScrollView(
                        key: ValueKey(c.step),
                        child: SizedBox(
                          height: math.max(box.maxHeight, 724 + extra),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            child: Column(
                              children: [
                                _header(story),
                                Expanded(
                                  child: c.step == 11
                                      ? _exercise()
                                      : c.step == 13
                                      ? _reward()
                                      : _dialogue(story),
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
                                        textAlign: TextAlign.center,
                                        style: AppTypography.body,
                                      ),
                                    ),
                                  ),
                                _action(),
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
        ),
      );
    },
  );

  Widget _header(bool story) => SizedBox(
    height: 48,
    child: Row(
      children: [
        StrannikTapTarget(
          label: 'Назад',
          onTap: c.busy
              ? null
              : c.backStack.isEmpty || c.step == 13
              ? onClose
              : c.back,
          child: const SizedBox(
            width: 32,
            height: 48,
            child: Icon(Icons.chevron_left, size: 28, color: AppColors.black),
          ),
        ),
        if (!story && c.step != 13)
          Expanded(
            child: Semantics(
              label: 'Прогресс урока',
              value:
                  '${((c.step - 5).clamp(0, 7) / 7 * 100).round()} процентов',
              child: SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _bar((c.step - 5).clamp(0, 7) / 7, AppColors.darkOrange),
                    Positioned(
                      left: 120,
                      child: Image.asset(
                        PresentationAssets.star,
                        width: 43,
                        height: 41,
                        excludeFromSemantics: true,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: Image.asset(
                        PresentationAssets.star,
                        width: 43,
                        height: 41,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (story || c.step == 13) const Spacer(),
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

  Widget _bubble(String text, {bool human = false, double? width}) {
    final textWidget = Text(
      text,
      style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
    );
    final bubble = StrannikSpeechBubble(
      name: '',
      showName: false,
      compact: true,
      child: human
          ? Transform.flip(flipX: true, child: textWidget)
          : textWidget,
    );
    return SizedBox(
      width: width ?? 270,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          human ? Transform.flip(flipX: true, child: bubble) : bubble,
          if (human)
            Positioned(
              top: -30,
              right: 12,
              child: Image.asset(
                PresentationAssets.girlAvatar,
                width: 70,
                height: 56,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _cat({bool glasses = false, bool reward = false}) => SizedBox(
    width: reward ? 209 : 332,
    height: reward ? 265 : 300,
    child: Stack(
      children: [
        if (!reward)
          Positioned(
            left: 39,
            top: 261,
            width: 228,
            height: 39,
            child: lessonArt('cat_shadow'),
          ),
        Positioned.fill(
          child: reward
              ? lessonArt('reward_cat')
              : Image.asset(
                  'assets/onboarding/skin_gray.png',
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
        ),
        if (glasses)
          Positioned(
            left: reward ? 10 : 91,
            top: reward ? 23 : 43,
            width: 165,
            height: 74,
            child: lessonArt('glasses'),
          ),
      ],
    ),
  );

  Widget _dialogue(bool story) => LayoutBuilder(
    builder: (context, box) {
      final human = ShoppingListLesson.human(c.step);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: story ? box.maxHeight * .22 : 32,
            left: 17,
            right: 25,
            child: human
                ? const SizedBox()
                : _bubble(ShoppingListLesson.lines[c.step]),
          ),
          Positioned(
            left: story ? -8 : -3,
            right: story ? 70 : -8,
            top: story ? box.maxHeight * .50 : box.maxHeight * .29,
            height: story ? 222 : 300,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              child: _cat(glasses: !story),
            ),
          ),
          if (human)
            Positioned(
              left: 0,
              right: 0,
              bottom: 22,
              child: _bubble(
                ShoppingListLesson.lines[c.step],
                human: true,
                width: 328,
              ),
            ),
          if (c.step == 7)
            Positioned(
              right: 0,
              bottom: 6,
              child: lessonArt('shopping_cart', width: 150, height: 128),
            ),
          if (c.step == 8)
            Positioned(
              left: 0,
              bottom: 6,
              child: lessonArt('shopping_note', width: 160, height: 170),
            ),
          if (c.step == 9)
            Positioned(
              left: 80,
              right: 80,
              bottom: 28,
              child: _coin('${c.task.exerciseBudget}', fontSize: 30),
            ),
          if (c.step == 12)
            Positioned(
              left: 40,
              right: 40,
              bottom: -60,
              height: 240,
              child: lessonArt('popcorn_bucket', fit: BoxFit.contain),
            ),
        ],
      );
    },
  );

  Widget _exercise() => Column(
    children: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: _bubble(
              c.budget.shortfall > 0
                  ? ShoppingListLesson.overBudget
                  : ShoppingListLesson.instruction,
              width: 314,
            ),
          ),
          Positioned(
            left: -2,
            top: -24,
            width: 90,
            height: 66,
            child: lessonArt('cat_avatar'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) {
            final extent = math.min(174.0, (box.maxHeight - 8) / 2);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var row = 0; row < 2; row++) ...[
                  Row(
                    children: [
                      for (var col = 0; col < 2; col++) ...[
                        if (col == 1) const SizedBox(width: 8),
                        Expanded(
                          child: _product(
                            c.task.products[row * 2 + col],
                            extent,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (row == 0) const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 6,
        children: [
          Text(
            'Бюджет',
            style: AppTypography.button.copyWith(color: AppColors.black),
          ),
          _coin('${c.budget.remaining}'),
        ],
      ),
      const SizedBox(height: 10),
      Semantics(
        liveRegion: true,
        label: c.budget.shortfall > 0
            ? 'Не хватает ${formatFira(c.budget.shortfall)}'
            : 'Осталось ${formatFira(c.budget.remaining)}',
        child: _bar(
          (c.budget.remaining / c.task.exerciseBudget).clamp(0, 1),
          c.budget.shortfall > 0
              ? const Color(0xFFF02332)
              : AppColors.lightOrange,
        ),
      ),
      const SizedBox(height: 16),
    ],
  );

  Widget _product(LessonProduct product, double height) {
    final selected = c.selected.contains(product.id);
    final color = selected
        ? c.budget.shortfall > 0
              ? const Color(0xFFF02332)
              : AppColors.green
        : AppColors.black;
    return Semantics(
      selected: selected,
      button: true,
      label: '${product.title}, ${formatFira(product.price)}',
      child: StrannikTapTarget(
        label: '${product.title}, ${formatFira(product.price)}',
        onTap: c.busy ? null : () => c.toggle(product.id),
        child: SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned.fill(
                bottom: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected ? color : const Color(0xFFFFD9B3),
                      width: 4,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: lessonArt(product.assetId, fit: BoxFit.contain),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 4,
                right: 4,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(color: color, width: 3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${product.title} ${product.price}',
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(double value, Color color) => Container(
    height: 22,
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.black, width: 3),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value,
          heightFactor: 1,
          child: ColoredBox(color: color),
        ),
      ),
    ),
  );
  Widget _coin(String label, {double fontSize = 20}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.white,
      border: Border.all(color: AppColors.black, width: 3),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$label  фир',
      style: AppTypography.counter.copyWith(
        fontSize: fontSize,
        color: AppColors.black,
      ),
    ),
  );

  Widget _reward() => Column(
    children: [
      const Spacer(),
      Flexible(
        flex: 8,
        child: FittedBox(child: _cat(glasses: true, reward: true)),
      ),
      const SizedBox(height: 16),
      Text(
        'Задание\nвыполнено!',
        textAlign: TextAlign.center,
        style: AppTypography.heading.copyWith(
          fontSize: 36,
          color: AppColors.black,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        ShoppingListLesson.ending,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                c.rewardClaimed ? 'XP уже получен' : '+${c.task.rewardXp} XP',
                style: AppTypography.counter,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _coin(
              c.rewardClaimed ? 'Получено' : '+${c.task.rewardFira}',
            ),
          ),
        ],
      ),
      if (c.rewardClaimed)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Задание пройдено повторно. Награда уже получена.',
            style: AppTypography.body,
            textAlign: TextAlign.center,
          ),
        ),
      const Spacer(),
    ],
  );

  Widget _action() {
    if (c.step == 11 && c.budget.shortfall > 0) {
      return Semantics(
        button: true,
        enabled: false,
        label: 'Не хватает ${formatFira(c.budget.shortfall)}',
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF02332),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: const Text('Не хватает фир', style: AppTypography.button),
        ),
      );
    }
    final label = c.step == 11
        ? c.selected.isEmpty
              ? 'Оплатить'
              : 'Оплатить ${formatFira(c.budget.total)}'
        : ShoppingListLesson.actions[c.step];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StrannikButton(
          label: c.busy && c.step == 12 ? 'Сохраняем…' : label,
          onPressed: c.busy || (c.step == 11 && !c.budget.valid)
              ? null
              : c.step == 11
              ? c.confirm
              : c.step == 13
              ? onClose
              : c.advance,
          backgroundColor: c.step == 11
              ? AppColors.green
              : c.step == 0 || c.step >= 12
              ? AppColors.blue
              : AppColors.darkOrange,
        ),
        if (c.step == 0) ...[
          const SizedBox(height: 12),
          StrannikButton(
            label: 'Страшными, как в фильмах',
            onPressed: c.busy ? null : () => c.advance(scared: true),
            backgroundColor: AppColors.darkOrange,
          ),
        ],
      ],
    );
  }
}
