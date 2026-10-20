import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../content/lessons/financial_safety_lesson.dart';
import '../assets/presentation_assets.dart';
import '../components/strannik_button.dart';
import '../components/strannik_speech_bubble.dart';
import '../components/strannik_tap_target.dart';
import '../foundation/app_tokens.dart';
import 'financial_safety_controller.dart';
import 'learning_screen.dart';

class FinancialSafetyScreen extends StatelessWidget {
  const FinancialSafetyScreen({
    super.key,
    required this.controller,
    required this.onClose,
    this.onGuide,
  });
  final FinancialSafetyController controller;
  final VoidCallback onClose;
  final VoidCallback? onGuide;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller, p = c.progress, n = p.node;
      final call = c.lesson.taskId == FinancialSafetyLesson.callId;
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
              if (!c.completed) const SafetyLessonBackground(),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          StrannikTapTarget(
                            label: 'Назад',
                            onTap: c.busy
                                ? null
                                : p.events.isEmpty || c.completed || p.ready
                                ? onClose
                                : c.back,
                            child: const SizedBox(
                              width: 32,
                              height: 52,
                              child: Icon(
                                Icons.chevron_left,
                                color: AppColors.black,
                                size: 28,
                              ),
                            ),
                          ),
                          if (!c.completed)
                            Expanded(
                              child: SafetyLessonProgress(value: n.progress),
                            )
                          else
                            const Spacer(),
                          if (onGuide != null)
                            IconButton(
                              tooltip: 'Справка',
                              onPressed: c.busy ? null : onGuide,
                              icon: const Icon(Icons.menu_book_outlined),
                            ),
                        ],
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) => SingleChildScrollView(
                            key: ValueKey('${n.id}:${p.feedback}'),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: box.maxHeight,
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (c.completed)
                                    SafetyReward(
                                      lesson: c.lesson,
                                      replay: c.rewardClaimed,
                                      rewardFira: c.game.context.content
                                          .task(c.lesson.taskId)!
                                          .rewardFira,
                                      rewardXp: c.game.context.content
                                          .task(c.lesson.taskId)!
                                          .rewardXp,
                                    )
                                  else
                                    _content(c, call, box.maxHeight),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (c.error != null)
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Semantics(
                                            liveRegion: true,
                                            child: Text(
                                              c.error!,
                                              style: AppTypography.body,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 14),
                                      if (c.completed)
                                        _button(c.lesson.exitLabel, onClose)
                                      else if (p.ready)
                                        _button(
                                          c.busy
                                              ? 'Сохраняем…'
                                              : 'Сохранить результат',
                                          c.busy ? null : c.finish,
                                        )
                                      else if (n.view == SafetyView.question &&
                                          !p.feedback)
                                        _button(
                                          'Проверить',
                                          c.busy || p.selectedId == null
                                              ? null
                                              : () => c.send('check_answer'),
                                        )
                                      else
                                        for (final a in n.actions) ...[
                                          if (a != n.actions.first)
                                            const SizedBox(height: 8),
                                          _button(
                                            a.label,
                                            c.busy || !p.canAdvance
                                                ? null
                                                : () => c.send(a.id),
                                            danger: a.id == 'hang_up',
                                          ),
                                        ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _button(String label, VoidCallback? onTap, {bool danger = false}) =>
      StrannikButton(
        label: label,
        onPressed: onTap,
        backgroundColor: danger ? const Color(0xFFD42D3D) : AppColors.blue,
      );
  Widget _content(FinancialSafetyController c, bool call, double height) {
    final p = c.progress, n = p.node;
    if (n.view == SafetyView.complete) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (n.view == SafetyView.question) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (call)
            SafetyCallCard(
              incoming: false,
              ended: p.events.contains('hang_up'),
              height: 202,
            )
          else if (!p.feedback)
            SafetyEmailCard(compact: true, onInspect: (_) {}, clues: const {}),
          SafetySpeechBubble(text: n.question, heading: true),
          for (var i = 0; i < n.answers.length; i++)
            if (!p.feedback || p.selectedId == n.answers[i].id)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SafetyAnswerChoice(
                  number: i + 1,
                  answer: n.answers[i],
                  selected: p.selectedId == n.answers[i].id,
                  revealed: p.feedback,
                  onTap: c.busy || p.feedback
                      ? null
                      : () => c.send('answer:${n.answers[i].id}'),
                ),
              ),
          if (p.feedback) SafetyAnswerFeedback(answer: p.selected!),
        ],
      );
    }
    Widget scenario = switch (n.view) {
      SafetyView.call => SafetyCallCard(
        incoming: n.id == 'incoming',
        ended: n.id == 'ended',
        caller: n.caller,
        height: math.max(280, height - (n.speech.isEmpty ? 150 : 240)),
      ),
      SafetyView.email || SafetyView.clues => SafetyEmailCard(
        clues: p.clues,
        investigating: n.view == SafetyView.clues,
        onInspect: (id) => c.send('inspect:$id'),
        onOpen: c.busy || n.view == SafetyView.clues
            ? null
            : () => c.send(n.actions.first.id),
      ),
      SafetyView.prize => SafetyPrizeCard(
        onDiscuss: c.busy ? null : () => c.send('discuss'),
      ),
      SafetyView.card => const SafetyMockCard(),
      SafetyView.conclusion =>
        call
            ? SafetyCallCard(
                incoming: false,
                ended: p.events.contains('hang_up'),
                height: 300,
              )
            : const SafetyMockCard(),
      _ => const SizedBox(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        scenario,
        if (n.speech.isNotEmpty || p.lastClue != null)
          SafetySpeechBubble(
            text: p.lastClue == null
                ? n.speech
                : FinancialSafetyLesson.clueText[p.lastClue]!,
          ),
        if (n.view == SafetyView.clues)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Улики: ${p.clues.length} из 3',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
          ),
      ],
    );
  }
}

class SafetyLessonProgress extends StatelessWidget {
  const SafetyLessonProgress({super.key, required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Прогресс урока',
    value: '${(value * 100).round()} процентов',
    child: LayoutBuilder(
      builder: (_, box) => SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 20,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.lightOrange, AppColors.darkOrange],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            for (final fraction in [.31, .62, .93])
              Positioned(
                left: (box.maxWidth - 40) * fraction,
                child: Image.asset(
                  PresentationAssets.star,
                  width: 40,
                  height: 42,
                  excludeFromSemantics: true,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class SafetySpeechBubble extends StatelessWidget {
  const SafetySpeechBubble({
    super.key,
    required this.text,
    this.heading = false,
    this.artwork = 'assets/learning/safety_bubble.png',
  });
  final String text;
  final bool heading;
  final String artwork;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 34),
          child: StrannikSpeechBubble(
            name: '',
            artwork: artwork,
            showName: false,
            compact: true,
            child: Text(
              text,
              style: heading
                  ? AppTypography.counter.copyWith(color: AppColors.black)
                  : AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: lessonArt('cat_avatar', width: 94, height: 70),
        ),
      ],
    ),
  );
}

class SafetyScenarioCard extends StatelessWidget {
  const SafetyScenarioCard({
    super.key,
    required this.child,
    this.navy = false,
    this.padding = 20,
  });
  final Widget child;
  final bool navy;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: navy ? AppColors.blue : AppColors.white,
      border: Border.all(color: AppColors.black, width: navy ? 3 : 2),
      borderRadius: BorderRadius.circular(navy ? 28 : 20),
    ),
    child: child,
  );
}

class SafetyCallCard extends StatelessWidget {
  const SafetyCallCard({
    super.key,
    required this.incoming,
    this.ended = false,
    this.caller = '',
    required this.height,
  });
  final bool incoming, ended;
  final String caller;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: SafetyScenarioCard(
      navy: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                lessonArt('safety_unknown', width: 84, height: 84),
                if (!incoming)
                  Positioned(
                    left: -7,
                    top: -12,
                    width: 99,
                    height: 110,
                    child: lessonArt('safety_scammer'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Неизвестный номер',
            textAlign: TextAlign.center,
            style: AppTypography.counter.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 4),
          Text(
            ended
                ? 'Разговор окончен'
                : incoming
                ? 'Входящий звонок…'
                : 'идёт разговор...',
            style: AppTypography.body.copyWith(
              color: AppColors.lightBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (caller.isNotEmpty) ...[
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(caller, style: AppTypography.body),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class SafetyAnswerChoice extends StatelessWidget {
  const SafetyAnswerChoice({
    super.key,
    required this.number,
    required this.answer,
    required this.selected,
    required this.revealed,
    required this.onTap,
  });
  final int number;
  final SafetyAnswer answer;
  final bool selected, revealed;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final color = revealed
        ? answer.correct
              ? AppColors.green
              : const Color(0xFFDA3346)
        : selected
        ? AppColors.blue
        : AppColors.gray;
    return Semantics(
      selected: selected,
      child: StrannikTapTarget(
        label: '$number. ${answer.text}',
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(minHeight: 68),
          decoration: BoxDecoration(
            color: revealed
                ? answer.correct
                      ? const Color(0xFFA8EAC6)
                      : const Color(0xFFF9C8CC)
                : selected
                ? AppColors.lightBlue
                : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: selected && !revealed
                ? Border.all(color: color, width: 3)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$number', style: AppTypography.badge),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  answer.text,
                  style: AppTypography.badge.copyWith(color: AppColors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SafetyAnswerFeedback extends StatelessWidget {
  const SafetyAnswerFeedback({super.key, required this.answer});
  final SafetyAnswer answer;
  @override
  Widget build(BuildContext context) {
    final color = answer.correct
        ? const Color(0xFF07823D)
        : const Color(0xFFB11F30);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: answer.correct
              ? const Color(0xFFE9FFF5)
              : const Color(0xFFFFEFF1),
          border: Border.all(
            color: answer.correct ? AppColors.green : color,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  answer.correct ? Icons.check_circle : Icons.info,
                  color: color,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    answer.correct ? 'Верно!' : 'Давай разберёмся',
                    style: AppTypography.heading.copyWith(
                      color: color,
                      fontSize: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              answer.feedback,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class SafetyEmailCard extends StatelessWidget {
  const SafetyEmailCard({
    super.key,
    required this.onInspect,
    required this.clues,
    this.investigating = false,
    this.onOpen,
    this.compact = false,
  });
  final void Function(String) onInspect;
  final Set<String> clues;
  final bool investigating, compact;
  final VoidCallback? onOpen;
  Widget hotspot(String id, Widget child) => StrannikTapTarget(
    label: 'Проверить: ${FinancialSafetyLesson.clueLabels[id]}',
    onTap: investigating
        ? () => onInspect(id)
        : id == 'link'
        ? onOpen
        : null,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: id == 'sender' ? AppColors.lightBlue : Colors.transparent,
        border: Border.all(
          color: investigating ? const Color(0xFF0088BB) : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          if (clues.contains(id))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.blue,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Улика: ${FinancialSafetyLesson.clueLabels[id]}',
                      style: AppTypography.body.copyWith(
                        color: AppColors.blue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => SafetyScenarioCard(
    padding: compact ? 12 : 16,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Новое письмо!',
          style: AppTypography.heading.copyWith(
            color: AppColors.blue,
            fontSize: compact ? 20 : 24,
          ),
        ),
        const SizedBox(height: 8),
        hotspot(
          'sender',
          const Text(
            'От: Супершоп / mail@supersshope.ru',
            style: AppTypography.body,
          ),
        ),
        const SizedBox(height: 8),
        hotspot(
          'prize',
          Text(
            'Поздравляем! Вы выиграли 10 000 ₽!',
            style: AppTypography.counter.copyWith(color: AppColors.blue),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          const Text(
            'Вы стали победителем нашей случайной лотереи! Ваш приз уже ждёт вас. Чтобы забрать выигрыш, перейдите на сайт и подтвердите получение подарка',
            style: AppTypography.body,
          ),
        ],
        const SizedBox(height: 12),
        hotspot(
          'link',
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Забрать выигрыш', style: AppTypography.button),
          ),
        ),
      ],
    ),
  );
}

class SafetyPrizeCard extends StatelessWidget {
  const SafetyPrizeCard({super.key, required this.onDiscuss});
  final VoidCallback? onDiscuss;
  @override
  Widget build(BuildContext context) => SafetyScenarioCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Супершоп · Подарки', style: AppTypography.body),
        const SizedBox(height: 20),
        Text(
          'Заберите выигрыш 10 000 ₽',
          style: AppTypography.heading.copyWith(color: AppColors.blue),
        ),
        const SizedBox(height: 28),
        const Text(
          'Для получения приза необходимо оплатить сервисный сбор',
          style: AppTypography.body,
        ),
        const SizedBox(height: 16),
        Text(
          '30 F',
          textAlign: TextAlign.center,
          style: AppTypography.heading.copyWith(
            color: AppColors.darkOrange,
            fontSize: 36,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'После оплаты приз будет отправлен вам!',
          style: AppTypography.body,
        ),
        const SizedBox(height: 20),
        StrannikButton(
          label: 'Оплатить сбор',
          onPressed: onDiscuss,
          backgroundColor: AppColors.gray,
          foregroundColor: AppColors.blue,
        ),
      ],
    ),
  );
}

/// Display-only lesson artwork: deliberately contains no editable or focusable
/// input, platform link, payment handler, or entered-card-value state.
class SafetyMockCard extends StatelessWidget {
  const SafetyMockCard({super.key});
  @override
  Widget build(BuildContext context) => SafetyScenarioCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Оплата сбора',
          style: AppTypography.heading.copyWith(color: AppColors.black),
        ),
        const SizedBox(height: 42),
        for (final field in const [
          ('Номер карты', '0000 0000 0000 0000'),
          ('Срок действия', 'ММ/ГГ'),
          ('Код с обратной стороны', '• • •'),
        ]) ...[
          Text(
            field.$1,
            style: AppTypography.body.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.gray, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              field.$2,
              style: AppTypography.button.copyWith(
                color: const Color(0xFF626773),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    ),
  );
}

class SafetyReward extends StatelessWidget {
  const SafetyReward({
    super.key,
    required this.lesson,
    required this.replay,
    required this.rewardFira,
    required this.rewardXp,
  });
  final FinancialSafetyLesson lesson;
  final bool replay;
  final int rewardFira, rewardXp;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 40),
      SizedBox(
        width: 209,
        height: 265,
        child: Stack(
          children: [
            Positioned.fill(child: lessonArt('reward_cat')),
            Positioned(
              left: 10,
              top: 23,
              width: 165,
              height: 74,
              child: lessonArt('glasses'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(
        lesson.title,
        textAlign: TextAlign.center,
        style: AppTypography.heading.copyWith(
          fontSize: 36,
          color: AppColors.black,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        lesson.ending,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 36),
      if (replay)
        const Text('Награда уже получена', style: AppTypography.counter)
      else
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.lightOrange, AppColors.darkOrange],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$rewardXp XP',
                  textAlign: TextAlign.center,
                  style: AppTypography.counter,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$rewardFira фир',
                  textAlign: TextAlign.center,
                  style: AppTypography.counter,
                ),
              ),
            ),
          ],
        ),
    ],
  );
}

class SafetyLessonBackground extends StatelessWidget {
  const SafetyLessonBackground({
    super.key,
    this.tint = const Color(0xFFF7D88E),
  });
  final Color tint;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) => ClipRect(
      child: OverflowBox(
        maxWidth: box.maxWidth * 2.2889,
        maxHeight: box.maxHeight * 1.9989,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
          child: lessonArt(
            'learning_background',
            width: box.maxWidth * 2.2889,
            height: box.maxHeight * 1.9989,
            fit: BoxFit.fill,
          ),
        ),
      ),
    ),
  );
}
