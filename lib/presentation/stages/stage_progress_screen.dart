import 'package:flutter/material.dart';

import '../../app/bootstrap.dart';
import '../../content/economy_config.dart';
import '../../core/result.dart';
import '../../domain/models/models.dart';
import '../../domain/models/stage_progress.dart';
import '../components/strannik_button.dart';
import '../components/strannik_tap_target.dart';
import '../components/strannik_stage_badge.dart';
import '../foundation/app_tokens.dart';

String stageTitle(Stage stage) => switch (stage) {
  Stage.earth => 'Планета Земля',
  Stage.space => 'Ракета',
  Stage.homePlanet => 'Родная планета',
};

class StageProgressScreen extends StatefulWidget {
  const StageProgressScreen({
    super.key,
    required this.game,
    required this.onHome,
    required this.onLearning,
    required this.onStore,
    required this.onBank,
  });
  final GameServices game;
  final VoidCallback onHome, onLearning, onStore, onBank;
  @override
  State<StageProgressScreen> createState() => _StageProgressScreenState();
}

class _StageProgressScreenState extends State<StageProgressScreen> {
  StageProgress? progress;
  Stage? selected;
  bool busy = false, confirming = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final result = await widget.game.progression.progress();
    if (!mounted) return;
    setState(() {
      if (result case Success(value: final p)) {
        progress = p;
        selected ??= p.pet.currentStage;
      } else {
        error = 'Не удалось загрузить прогресс. Попробуй ещё раз.';
      }
    });
  }

  Future<void> advance() async {
    if (busy || progress?.eligible != true) return;
    final from = progress!.pet.currentStage;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await widget.game.progression.advanceStage(fromStage: from);
    if (!mounted) return;
    if (result is Success) {
      widget.onHome();
      return;
    }
    await load();
    if (!mounted) return;
    setState(() {
      busy = false;
      confirming = false;
      error = 'Условия изменились. Проверь прогресс и попробуй ещё раз.';
    });
  }

  Widget button(String label, VoidCallback? onTap) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: StrannikButton(
      label: label,
      onPressed: busy ? null : onTap,
      backgroundColor: AppColors.blue,
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !busy) widget.onHome();
    },
    child: Scaffold(
      backgroundColor: const Color(0xFF071E39),
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (_, box) => ClipRect(
              child: OverflowBox(
                maxWidth: box.maxWidth * 1.2944,
                maxHeight: box.maxHeight * 1.2973,
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                  'assets/stages/map.png',
                  width: box.maxWidth * 1.2944,
                  height: box.maxHeight * 1.2973,
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 220,
            width: 180,
            height: 160,
            child: StrannikTapTarget(
              label: 'Выбрать стадию 2: Ракета',
              onTap: busy
                  ? null
                  : () => setState(() {
                      selected = Stage.space;
                      confirming = false;
                    }),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            right: 0,
            top: 115,
            width: 170,
            height: 188,
            child: StrannikTapTarget(
              label: 'Выбрать стадию 3: Родная планета',
              onTap: busy
                  ? null
                  : () => setState(() {
                      selected = Stage.homePlanet;
                      confirming = false;
                    }),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.ink,
                      ),
                      onPressed: busy ? null : widget.onHome,
                      tooltip: 'Вернуться домой',
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
                const Spacer(),
                Flexible(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7E7E7),
                      border: Border.all(width: 5),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: progress == null
                            ? Column(
                                children: [
                                  Text(
                                    error ?? 'Открываем стадии…',
                                    style: AppTypography.body,
                                  ),
                                  if (error != null) button('Повторить', load),
                                ],
                              )
                            : details(),
                      ),
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
  Widget details() {
    final p = progress!, stage = selected!;
    if (stage != p.pet.currentStage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stageTitle(stage),
            style: AppTypography.heading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            stage.index < p.pet.currentStage.index
                ? 'Стадия пройдена. Твои задания и накопления сохранены.'
                : 'Эта стадия впереди. Сначала заверши переход с текущей стадии.',
            style: AppTypography.body,
          ),
          button(
            'Текущая стадия',
            () => setState(() => selected = p.pet.currentStage),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Этап ${stage.index + 1} · ${stageTitle(stage)}',
          style: AppTypography.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (p.requirements == null) ...[
          const Text('Вы на родной планете!', style: AppTypography.body),
          button('Открыть задания', widget.onLearning),
        ] else ...[
          Text(
            'Дальше: этап ${p.requirements!.to.index + 1} · ${stageTitle(p.requirements!.to)}',
            style: AppTypography.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            confirming
                ? 'Готовы отправиться дальше?'
                : p.eligible
                ? 'Всё готово для следующей стадии!'
                : 'Для перехода на следующую стадию не хватает:',
            style: AppTypography.body.copyWith(color: AppColors.blue),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Center(
            child: StrannikStageBadge(
              stageNumber: stage.index + 1,
              progressLabel: '${p.pet.xp}/${p.requirements!.requiredXp} XP',
              progressIsPlaceholder: false,
              onTap: widget.onStore,
            ),
          ),
          condition(
            p.goalMet,
            p.goal == null
                ? 'Выбери цель в задании «Цель»'
                : 'Цель: ${EconomyConfig.goals[p.goal!.type]!.title}',
            p.goalMet ? null : widget.onLearning,
          ),
          condition(
            p.xpMet,
            'Опыт: ${p.pet.xp}/${p.requirements!.requiredXp} XP',
            p.xpMet ? null : widget.onStore,
          ),
          for (final resource in p.requirements!.resources)
            condition(
              p.owned(resource.resourceId) >= resource.amount,
              '${resourceTitle(resource.resourceId)}: ${p.owned(resource.resourceId)}/${resource.amount}',
              p.owned(resource.resourceId) >= resource.amount
                  ? null
                  : widget.onStore,
            ),
          const SizedBox(height: 8),
          Text(
            'Задания стадии: ${p.completedLessons}/${p.requiredLessons}',
            style: AppTypography.body,
          ),
          button('Задания этапа', widget.onLearning),
          if (!p.xpMet)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Опыт дают угощения и игры с игрушкой. Купи предмет в магазине и используй его в шкафу.',
                style: AppTypography.body,
              ),
            ),
          if (p.goalMet) ...[
            Text(
              'На цель выделено: ${p.goal!.isCompleted ? EconomyConfig.goals[p.goal!.type]!.target : p.budget?.remainder ?? 0}/${EconomyConfig.goals[p.goal!.type]!.target} фир',
              style: AppTypography.body,
            ),
            button('Моя цель в Банке', widget.onBank),
          ],
          if (p.eligible) ...[
            if (confirming)
              Text(
                'Будут использованы: ${p.requirements!.resources.map((r) => '${r.amount} × ${resourceTitle(r.resourceId)}').join(', ')}. Баланс, план и накопления сохранятся.',
                style: AppTypography.body,
              ),
            button(
              confirming
                  ? 'Подтвердить переход'
                  : 'Перейти на стадию ${p.requirements!.to.index + 1}',
              confirming ? advance : () => setState(() => confirming = true),
            ),
            if (confirming)
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() => confirming = false),
                child: const Text('Остаться пока здесь'),
              ),
          ] else ...[
            button(
              p.goalMet ? 'В магазин' : 'Пройти задание «Цель»',
              p.goalMet ? widget.onStore : widget.onLearning,
            ),
            button('Перейти на стадию ${p.requirements!.to.index + 1}', null),
          ],
        ],
        if (error != null)
          Text(
            error!,
            style: AppTypography.body.copyWith(color: Colors.red.shade900),
          ),
      ],
    );
  }

  String resourceTitle(String id) =>
      widget.game.context.content.resources.firstWhere((v) => v.id == id).title;
  Widget condition(bool met, String label, VoidCallback? action) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(
          met ? '✓' : '○',
          style: AppTypography.counter.copyWith(
            color: met ? AppColors.green : AppColors.ink,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppTypography.body)),
        if (action != null)
          TextButton(
            onPressed: busy ? null : action,
            child: const Text('Открыть'),
          ),
      ],
    ),
  );
}
