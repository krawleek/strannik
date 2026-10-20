import 'package:flutter/material.dart';

import '../../app/bootstrap.dart';
import '../../content/lessons/shopping_list_lesson.dart';
import '../../core/result.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../components/strannik_button.dart';
import '../components/strannik_tap_target.dart';
import '../foundation/app_tokens.dart';
import 'shopping_list_controller.dart';
import '../../content/lessons/discount_traps_lesson.dart';
import 'discount_traps_controller.dart';
import 'discount_traps_screen.dart';
import '../../content/lessons/financial_safety_lesson.dart';
import 'financial_safety_controller.dart';
import 'financial_safety_screen.dart';
import 'financial_safety_topic_screen.dart';
import '../../content/lessons/financial_safety_topic.dart';
import 'shopping_list_screen.dart';
import '../../content/lessons/earth_topic_one.dart';
import 'earth_topic_controller.dart';
import 'earth_topic_screen.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({
    super.key,
    required this.unitOfWork,
    required this.content,
    required this.onBack,
    required this.onChanged,
  });
  final UnitOfWork unitOfWork;
  final ContentRepository content;
  final VoidCallback onBack;
  final Future<void> Function() onChanged;
  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  late final game = GameServices(
    unitOfWork: widget.unitOfWork,
    content: widget.content,
  );
  bool loading = true, busy = false;
  int balance = 0, xp = 0;
  Stage stage = Stage.earth;
  Set<String> unlocked = {}, completed = {};
  String? error;
  ShoppingListController? lesson;
  DiscountTrapsController? discounts;
  FinancialSafetyController? safety;
  EarthTopicController? earth;
  LearningTopicProgress? finale;
  bool topicReady = false;
  Future<void> openGuide() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const FinancialSafetyGuide()),
    );
  }

  Future<void> openFinale() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await game.learning.beginSafetyFinale();
    if (!mounted) return;
    setState(() {
      busy = false;
      if (result is Success<LearningTopicProgress>) {
        finale = result.value;
      } else {
        error = 'Не удалось открыть финал. Попробуй ещё раз.';
      }
    });
    await load();
    await widget.onChanged();
  }

  Future<void> nextFinale() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await game.learning.advanceSafetyFinale();
    if (!mounted) return;
    setState(() {
      busy = false;
      if (result is Success<LearningTopicProgress>) {
        finale = result.value.finaleStep == 2 ? null : result.value;
      } else {
        error = 'Не удалось сохранить финал. Попробуй ещё раз.';
      }
    });
    await load();
    await widget.onChanged();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    lesson?.dispose();
    discounts?.dispose();
    safety?.dispose();
    earth?.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final tasks = await game.learning.availableTasks();
    final snapshot = await game.context.run((r) async {
      final pet = await r.pets.pet();
      final app = await r.system.appState();
      final done = <String>{};
      for (final task in widget.content.tasks) {
        if ((await r.learning.learningProgress(task.id)).completed) {
          done.add(task.id);
        }
      }
      return (
        stage: pet == null ? Stage.earth : app.effectiveStage(pet),
        completed: done,
        balance: (await r.economy.wallet()).firaAmount,
        xp: pet?.xp ?? 0,
      );
    });
    if (!mounted) return;
    setState(() {
      loading = false;
      if (tasks is Success<List<LearningTask>> &&
          snapshot
              is Success<
                ({Stage stage, Set<String> completed, int balance, int xp})
              >) {
        unlocked = tasks.value.map((t) => t.id).toSet();
        completed = snapshot.value.completed;
        final required = FinancialSafetyTopic.requiredTasks(widget.content);
        topicReady =
            required.isNotEmpty &&
            required.every((t) => t.implemented && completed.contains(t.id));
        stage = snapshot.value.stage;
        balance = snapshot.value.balance;
        xp = snapshot.value.xp;
        error = null;
      } else {
        error = 'Не удалось открыть задания. Попробуй ещё раз.';
      }
    });
  }

  Future<void> start(LearningTask task) async {
    if (busy || !unlocked.contains(task.id)) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final result = await game.learning.beginTask(task.id, replay: true);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (result is Success<LearningAttempt>) {
        if (EarthTopicOne.ids.contains(task.id)) {
          earth = EarthTopicController(
            game,
            result.value,
            rewardClaimed: completed.contains(task.id),
          );
        } else if (FinancialSafetyLesson.forTask(task.id) != null) {
          safety = FinancialSafetyController(
            game,
            result.value,
            rewardClaimed: completed.contains(task.id),
          );
        } else if (task.id == DiscountTrapsLesson.taskId) {
          discounts = DiscountTrapsController(
            game,
            result.value,
            rewardClaimed: completed.contains(task.id),
          );
        } else {
          lesson = ShoppingListController(
            game,
            result.value,
            rewardClaimed: completed.contains(task.id),
          );
        }
      } else {
        error = 'Задание пока недоступно. Попробуй ещё раз.';
      }
    });
  }

  Future<void> closeLesson() async {
    if (lesson?.busy == true ||
        safety?.busy == true ||
        earth?.busy == true ||
        discounts?.busy == true) {
      return;
    }
    final oldDiscounts = discounts;
    discounts = null;
    oldDiscounts?.dispose();
    final oldEarth = earth;
    earth = null;
    oldEarth?.dispose();
    final finishedSafety = safety?.completed == true;
    final oldSafety = safety;
    safety = null;
    final old = lesson;
    setState(() => lesson = null);
    old?.dispose();
    oldSafety?.dispose();
    await load();
    await widget.onChanged();
    if (finishedSafety && topicReady && mounted) {
      final state = await game.context.run(
        (r) => r.learning.topicProgress(FinancialSafetyTopic.id),
      );
      if (state is Success<LearningTopicProgress> &&
          state.value.finaleStep < 2) {
        await openFinale();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (finale != null) {
      return FinancialSafetyFinale(
        progress: finale!,
        xp: xp,
        busy: busy,
        error: error,
        onNext: nextFinale,
        onClose: () => setState(() => finale = null),
      );
    }
    if (discounts != null) {
      return DiscountTrapsScreen(controller: discounts!, onClose: closeLesson);
    }
    if (earth != null) {
      return EarthTopicScreen(
        controller: earth!,
        onClose: closeLesson,
        onNext: () async {
          final index = EarthTopicOne.ids.indexOf(earth!.task.id);
          await closeLesson();
          if (mounted && index < 2) {
            await start(widget.content.task(EarthTopicOne.ids[index + 1])!);
          }
        },
        onHome: () async {
          await closeLesson();
          widget.onBack();
        },
      );
    }
    if (safety != null) {
      return FinancialSafetyScreen(
        controller: safety!,
        onClose: closeLesson,
        onGuide: openGuide,
      );
    }
    if (lesson != null) {
      return ShoppingListScreen(controller: lesson!, onClose: closeLesson);
    }
    final topics = widget.content.themes.where((t) => t.stage == stage).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.yellow,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (stage == Stage.homePlanet)
              const SafetyLessonBackground()
            else
              const LessonBackground(),
            SafeArea(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              StrannikTapTarget(
                                label: 'Вернуться домой',
                                onTap: widget.onBack,
                                child: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(
                                    Icons.chevron_left,
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Этап ${stage.index + 1}',
                                  style: AppTypography.counter,
                                ),
                              ),
                              Text(
                                '$balance фир',
                                style: AppTypography.counter,
                              ),
                            ],
                          ),
                          Text(
                            '$xp XP',
                            style: AppTypography.body,
                            textAlign: TextAlign.right,
                          ),
                          for (final topic in topics) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.darkOrange,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ТЕМА ${topic.order + 1}${topic.id == FinancialSafetyTopic.id && topicReady ? ' · ПРОЙДЕНА' : ''}',
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.white,
                                    ),
                                  ),
                                  if (topic.id == DiscountTrapsLesson.topicId &&
                                      _tasks(topic)
                                          .where(
                                            (t) =>
                                                t.rewardPolicy ==
                                                RewardPolicy.oneTime,
                                          )
                                          .every(
                                            (t) => completed.contains(t.id),
                                          ))
                                    const Text(
                                      'Тема завершена ✓',
                                      style: AppTypography.badge,
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          topic.title,
                                          style: AppTypography.badge,
                                        ),
                                      ),
                                      if (topic.id == FinancialSafetyTopic.id)
                                        IconButton(
                                          tooltip: 'Справка',
                                          onPressed: openGuide,
                                          icon: const Icon(
                                            Icons.menu_book_outlined,
                                            color: AppColors.white,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (topic.id == FinancialSafetyTopic.id)
                                    Text(
                                      '${FinancialSafetyTopic.requiredTasks(widget.content).where((t) => completed.contains(t.id)).length} из ${FinancialSafetyTopic.requiredTasks(widget.content).length} заданий завершены',
                                      style: AppTypography.body.copyWith(
                                        color: AppColors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            for (final task in _tasks(topic)) ...[
                              const SizedBox(height: 16),
                              _taskCard(task),
                            ],
                            if (topic.id == FinancialSafetyTopic.id) ...[
                              const SizedBox(height: 24),
                              StrannikButton(
                                backgroundColor: AppColors.blue,
                                label: 'Узнать больше',
                                onPressed: openGuide,
                              ),
                              const SizedBox(height: 16),
                              StrannikButton(
                                backgroundColor: AppColors.blue,
                                label: topicReady
                                    ? 'Финал темы'
                                    : 'Финал после всех заданий',
                                onPressed: topicReady && !busy
                                    ? openFinale
                                    : null,
                              ),
                              const SizedBox(height: 24),
                              Semantics(
                                label:
                                    '${FinancialSafetyTopic.plannedTitle}. Задание пока недоступно',
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFBEBEBE),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.lightBlue,
                                      width: 4,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        FinancialSafetyTopic.plannedTitle,
                                        style: AppTypography.counter,
                                      ),
                                      const Text(
                                        FinancialSafetyTopic.plannedDescription,
                                        style: AppTypography.body,
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: lessonArt(
                                          'safety_locked',
                                          width: 130,
                                          height: 100,
                                        ),
                                      ),
                                      const Text(
                                        'Задание пока недоступно',
                                        style: AppTypography.body,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                          if (topics.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Задания этого этапа пока готовятся.',
                                style: AppTypography.body,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (error != null) ...[
                            Text(error!, style: AppTypography.body),
                            StrannikButton(
                              label: 'Попробовать снова',
                              onPressed: load,
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<LearningTask> _tasks(LearningTheme topic) =>
      widget.content.tasks
          .where(
            (t) =>
                t.enabled &&
                t.themeId == topic.id &&
                t.stage == stage &&
                t.id != 'practice',
          )
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
  Widget _taskCard(LearningTask task) {
    final done = completed.contains(task.id);
    final open = unlocked.contains(task.id);
    final playable =
        (task.id == ShoppingListLesson.taskId ||
            task.id == DiscountTrapsLesson.taskId ||
            EarthTopicOne.ids.contains(task.id) ||
            FinancialSafetyLesson.forTask(task.id) != null) &&
        task.implemented &&
        task.stage == stage;
    final status = done
        ? 'Выполнено ✓\nПройти ещё раз'
        : !open
        ? 'Пока закрыто'
        : playable
        ? 'Начать задание'
        : 'Продолжение скоро';
    return Transform.rotate(
      angle: const [-.025, .04, -.025][task.order % 3],
      child: StrannikTapTarget(
        label: '${task.title}. $status',
        onTap: playable && open && !busy ? () => start(task) : null,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: stage == Stage.homePlanet && task.order == 1
                ? AppColors.lightOrange
                : const [
                    AppColors.lightBlue,
                    AppColors.pink,
                    AppColors.lightOrange,
                  ][task.order % 3],
            border: Border.all(color: AppColors.white, width: 4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: AppTypography.badge.copyWith(color: AppColors.black),
              ),
              if (task.description.isNotEmpty)
                Text(
                  done && stage == Stage.homePlanet
                      ? task.id == FinancialSafetyLesson.callId
                            ? 'Распознали угрозы и узнали, к кому обратиться за помощью'
                            : 'Раскрыли ловушку с призом, картой и секретным кодом'
                      : task.description,
                  style: AppTypography.body,
                ),
              if (done && stage == Stage.homePlanet)
                Align(
                  alignment: Alignment.centerRight,
                  child: lessonArt(
                    task.id == FinancialSafetyLesson.callId
                        ? 'safety_map_call'
                        : 'safety_map_email',
                    width: 62,
                    height: 62,
                  ),
                ),
              Row(
                children: [
                  Expanded(child: Text(status, style: AppTypography.body)),
                  if (stage == Stage.homePlanet && !done)
                    Text(
                      '${task.rewardFira} фир · ${task.rewardXp} XP',
                      style: AppTypography.body,
                    ),
                  if (stage == Stage.space)
                    lessonArt(
                      const [
                        'shopping_note',
                        'shopping_cart',
                        'apples',
                      ][task.order % 3],
                      width: 100,
                      height: 110,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget lessonArt(
  String name, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
}) => Image.asset(
  'assets/learning/$name.png',
  width: width,
  height: height,
  fit: fit,
  filterQuality: FilterQuality.high,
  excludeFromSemantics: true,
  errorBuilder: (_, _, _) => SizedBox(
    width: width,
    height: height,
    child: const Center(
      child: Text(
        'Иллюстрация недоступна',
        style: AppTypography.body,
        textAlign: TextAlign.center,
      ),
    ),
  ),
);

class LessonBackground extends StatelessWidget {
  const LessonBackground({super.key, this.patternColor});
  final Color? patternColor;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ClipRect(
      child: OverflowBox(
        maxWidth: box.maxWidth * 2.2889,
        maxHeight: box.maxHeight * 1.9989,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            patternColor ?? AppColors.yellow,
            patternColor == null ? BlendMode.overlay : BlendMode.srcIn,
          ),
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
