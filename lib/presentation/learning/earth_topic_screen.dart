import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../content/economy_config.dart';
import '../../content/lessons/earth_topic_one.dart';
import '../../domain/models/models.dart';
import '../../domain/models/budget_category.dart';
import '../assets/presentation_assets.dart';
import '../bank/bank_screen.dart' show categoryColor, categoryName;
import '../components/strannik_button.dart';
import '../components/strannik_speech_bubble.dart';
import '../components/strannik_tap_target.dart';
import '../foundation/app_tokens.dart';
import 'earth_topic_controller.dart';
import 'learning_screen.dart' show LessonBackground, lessonArt;

Widget earthArt(
  String name, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
}) => Image.asset(
  'assets/earth/$name.png',
  width: width,
  height: height,
  fit: fit,
  filterQuality: FilterQuality.high,
  excludeFromSemantics: true,
);

class EarthTopicScreen extends StatefulWidget {
  const EarthTopicScreen({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onNext,
    required this.onHome,
  });
  final EarthTopicController controller;
  final Future<void> Function() onClose, onNext, onHome;
  @override
  State<EarthTopicScreen> createState() => _EarthTopicScreenState();
}

class _EarthTopicScreenState extends State<EarthTopicScreen> {
  EarthTopicController get c => widget.controller;
  final answer = TextEditingController(),
      amount = TextEditingController(),
      need = TextEditingController(),
      want = TextEditingController();
  @override
  void initState() {
    super.initState();
    answer.text = c.answer;
    if (!c.needs && !c.weekly) c.refreshGoal();
  }

  @override
  void dispose() {
    answer.dispose();
    amount.dispose();
    need.dispose();
    want.dispose();
    super.dispose();
  }

  Widget text(String s, {double size = 14, Color? color, TextAlign? align}) =>
      Text(
        s,
        textAlign: align,
        style: AppTypography.body.copyWith(fontSize: size, color: color),
      );
  Widget button(String s, VoidCallback? action, {bool secondary = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: StrannikButton(
          label: s,
          onPressed: c.busy ? null : action,
          backgroundColor: secondary ? const Color(0xFFEEEEEE) : AppColors.blue,
          foregroundColor: secondary ? AppColors.blue : AppColors.white,
        ),
      );
  Widget bubble(String s, {bool avatar = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      if (avatar) lessonArt('cat_avatar', width: 64, height: 74),
      Expanded(
        child: StrannikSpeechBubble(
          name: 'Странник',
          showName: false,
          compact: true,
          child: text(s),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final intro = c.needs && c.step == 0;
      final dream = !c.needs && !c.weekly && c.step == 0;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !c.busy) widget.onClose();
        },
        child: Scaffold(
          backgroundColor: AppColors.yellow,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (intro)
                LayoutBuilder(
                  builder: (_, box) => ClipRect(
                    child: OverflowBox(
                      maxWidth: box.maxWidth * 3.3333,
                      maxHeight: box.maxHeight,
                      alignment: const Alignment(.0608, 0),
                      child: earthArt(
                        'intro',
                        width: box.maxWidth * 3.3333,
                        height: box.maxHeight,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                )
              else if (dream) ...[
                earthArt('stars', fit: BoxFit.cover),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: earthArt('cat_back', height: 440),
                ),
              ] else
                const LessonBackground(),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: c.busy ? null : widget.onClose,
                            tooltip: 'Закрыть задание',
                            icon: const Icon(
                              Icons.chevron_left,
                              color: AppColors.black,
                            ),
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: c.done
                                          ? 1
                                          : c.needs
                                          ? c.step / 5
                                          : c.weekly
                                          ? c.simulation.step.index / 7
                                          : c.step / 3,
                                      minHeight: 16,
                                      color: AppColors.darkOrange,
                                      backgroundColor: AppColors.white,
                                    ),
                                  ),
                                  for (final x in [.28, .61, .94])
                                    Align(
                                      alignment: Alignment(x * 2 - 1, 0),
                                      child: Image.asset(
                                        PresentationAssets.star,
                                        width: 40,
                                        height: 40,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        key: ValueKey(
                          '${c.step}-${c.simulation.step}-${c.done}',
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        child: c.done
                            ? _completion()
                            : c.needs
                            ? _needs()
                            : c.weekly
                            ? _weekly()
                            : _goal(),
                      ),
                    ),
                    if (c.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: text(c.error!, color: Colors.red.shade900),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _actions(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _needs() => switch (c.step) {
    0 => Padding(
      padding: const EdgeInsets.only(top: 60, left: 28, right: 28),
      child: bubble(
        'На Земле столько классных штук! Хочу всё, но много я не унесу... Помоги понять, что нужно',
      ),
    ),
    1 => Column(
      children: [
        const SizedBox(height: 34),
        text(
          'Карточка ${c.card + 1} из 6 · Нужно: ${c.selected.length} из 3',
          align: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Transform.rotate(
          angle: -.04,
          child: Container(
            width: 270,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(width: 3),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                earthArt(EarthTopicOne.items[c.card].id, height: 235),
                const SizedBox(height: 24),
                text(EarthTopicOne.items[c.card].title, size: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: button('Нет', () => c.classify(false), secondary: true),
            ),
            const SizedBox(width: 12),
            Expanded(child: button('Нужно', () => c.classify(true))),
          ],
        ),
      ],
    ),
    2 || 3 => Column(
      children: [
        bubble(
          c.step == 2
              ? 'Вот что мы положили в корзину. Ничего не забыли?'
              : 'Я слежу... Нажми на вещь, чтобы взять её или убрать.',
        ),
        earthArt('cat_counter', height: 145),
        Container(
          decoration: const BoxDecoration(
            color: AppColors.lightOrange,
            border: Border(top: BorderSide(width: 4)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 12,
            children: [
              for (final item in EarthTopicOne.items)
                if (c.step == 3 || c.selected.contains(item.id))
                  _itemTile(item),
            ],
          ),
        ),
        if (c.step == 2)
          button(
            'Изменить выбор',
            () => c.change(() {
              c.step = 3;
            }),
            secondary: true,
          ),
      ],
    ),
    _ => Column(
      children: [
        bubble(
          c.wrong
              ? 'Хм, у меня получилось по-другому. Давай сложим цены ещё раз?'
              : 'Я думал, в магазине бесплатно всё раздают... Сколько монет нам нужно?',
        ),
        earthArt('cat_calculate', height: 150),
        for (final item in EarthTopicOne.items.where(
          (i) => EarthTopicOne.necessary.contains(i.id),
        ))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                earthArt(item.id, width: 48, height: 48),
                const SizedBox(width: 12),
                Expanded(child: text(item.title)),
                text('${EarthTopicOne.itemCost} ₣', size: 20),
              ],
            ),
          ),
        _answerField('Всего фир'),
      ],
    ),
  };
  Widget _itemTile(EarthItem item) {
    final selected = c.selected.contains(item.id);
    return StrannikTapTarget(
      label: '${item.title}${selected ? ', выбрано' : ''}',
      selected: selected,
      onTap: c.busy ? null : () => c.toggle(item.id),
      child: Container(
        width: 99,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE9FFF5) : AppColors.yellow,
          border: Border.all(
            width: 3,
            color: selected ? AppColors.green : AppColors.black,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Text(
                selected ? '✓' : ' ',
                style: AppTypography.body.copyWith(color: AppColors.green),
              ),
            ),
            earthArt(item.id, height: 55),
            const SizedBox(height: 4),
            text(item.title, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _answerField(String label) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: answer,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _check(),
      style: AppTypography.counter,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        errorText: c.wrong ? 'Попробуй сложить ещё раз' : null,
      ),
    ),
  );
  void _check() {
    FocusScope.of(context).unfocus();
    c.check(answer.text);
  }

  Widget _weekly() {
    final s = c.simulation;
    switch (s.step) {
      case WeeklyStep.calculate:
        return Column(
          children: [
            bubble(
              c.wrong
                  ? 'Хм, у меня получилось по-другому. Давай сложим цены ещё раз?'
                  : 'Давай посчитаем, сколько фир нужно на еду на неделю.',
              avatar: true,
            ),
            for (var i = 0; i < 7; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: text(EarthTopicOne.days[i], size: 18),
                    ),
                    Expanded(child: earthArt('food_${i % 4}', height: 38)),
                    text('${EarthTopicOne.foodPrices[i]} ₣', size: 20),
                  ],
                ),
              ),
            _answerField('Всего за неделю'),
          ],
        );
      case WeeklyStep.income:
      case WeeklyStep.nextIncome:
        return Padding(
          padding: const EdgeInsets.only(top: 90),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                lessonArt('safety_coin', height: 100),
                const SizedBox(height: 24),
                text(
                  s.step == WeeklyStep.income
                      ? 'Деньги на неделю'
                      : 'Новая неделя',
                  size: 24,
                ),
                const SizedBox(height: 16),
                text('+${s.income} ₣', size: 40),
                const SizedBox(height: 16),
                text(
                  'Это учебные фиры. Распределим их на еду и накопления.',
                  align: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      case WeeklyStep.allocate:
        return Column(
          children: [
            bubble(
              'Сначала отложи на еду. Что останется, клади в копилку!',
              avatar: true,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < s.unallocated ~/ EarthTopicOne.coin; i++)
                  Container(
                    width: 72,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.lightOrange,
                      border: Border.all(width: 2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: text('${EarthTopicOne.coin} ₣', size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _allocationTarget('На еду', s.food, 'wallet', true),
                ),
                Expanded(
                  child: _allocationTarget(
                    'В копилку',
                    s.savings,
                    'piggy',
                    false,
                  ),
                ),
              ],
            ),
            button(
              'Начать распределение заново',
              () => c.change(() {
                s.food = 0;
                s.savings = 0;
              }),
              secondary: true,
            ),
          ],
        );
      case WeeklyStep.shop:
      case WeeklyStep.secondShop:
        final second = s.step == WeeklyStep.secondShop;
        return Column(
          children: [
            bubble(
              second ? 'Посмотрим, что теперь можно купить на накопления.' : 'Хочу игрушку! Можем купить мышку, потратить деньги на еду или подождать.',
              avatar: true,
            ),
            text('В копилке: ${s.savings} ₣', size: 24),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _toy(
                    'mouse',
                    'Мышка',
                    EarthTopicOne.mouseCost,
                    s.savings,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _toy(
                    'rocket',
                    'Крутая ракета',
                    EarthTopicOne.rocketCost,
                    s.savings,
                  ),
                ),
              ],
            ),
            if (!second) ...[
              button(
                'Купить мышку',
                () => c.change(() => s.choose(WeeklyBranch.mouse)),
              ),
              button(
                'Взять ${EarthTopicOne.rocketCost - s.savings} ₣ из денег на еду',
                () => c.change(() => s.choose(WeeklyBranch.expensive)),
                secondary: true,
              ),
              button(
                'Подождать и копить',
                () => c.change(() => s.choose(WeeklyBranch.wait)),
                secondary: true,
              ),
            ],
          ],
        );
      case WeeklyStep.summary:
        return Column(
          children: [
            bubble(
              s.branch == WeeklyBranch.mouse
                  ? 'Я сыт, а мышка — просто супер! Что на этой неделе?'
                  : s.branch == WeeklyBranch.expensive
                  ? 'Мур... я так проголодался, что теперь ем больше обычного.'
                  : 'На прошлой неделе ничего не покупали — 60 монет остались в копилке. Добавим новые 60, и будет 120.',
              avatar: true,
            ),
            const SizedBox(height: 24),
            text('Неделя ${s.week}', size: 24),
            const SizedBox(height: 20),
            _summaryRow('Доход', s.income),
            _summaryRow('Еда', s.food),
            _summaryRow('В копилке', s.savings),
            const SizedBox(height: 24),
            text(
              s.branch == WeeklyBranch.mouse
                  ? 'Прошлая неделя прошла по плану: еды хватило, а мышку купили на отложенные 60. Эта неделя начинается как обычно.'
                  : s.branch == WeeklyBranch.expensive
                  ? 'На ракету ушли 60 монет из денег на еду — Странник недоедал. Теперь ему нужно больше еды: 240 вместо 180.'
                  : 'Ожидание помогло накопить 120 фир — теперь хватит на крутую ракету.',
              size: 16,
            ),
          ],
        );
      case WeeklyStep.ready:
        return _completion();
    }
  }

  Widget _allocationTarget(String label, int value, String art, bool food) =>
      StrannikTapTarget(
        label: '$label: добавить ${EarthTopicOne.coin} фир',
        onTap: c.busy || c.simulation.unallocated == 0
            ? null
            : () => c.change(() => c.simulation.allocate(food)),
        child: Column(
          children: [
            earthArt(art, height: 170),
            text(label, size: 16),
            text('$value ₣', size: 28),
          ],
        ),
      );
  Widget _toy(String art, String title, int price, int savings) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.white,
      border: Border.all(width: 2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        earthArt(art, height: 140),
        text(title, size: 16),
        text('$price ₣', size: 24),
        if (savings < price) text('Не хватает ${price - savings} ₣', size: 12),
      ],
    ),
  );
  Widget _summaryRow(String label, int value) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Expanded(child: text(label, size: 20)),
        text('$value ₣', size: 24),
      ],
    ),
  );
  Widget _goal() {
    if (c.step == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 50, left: 16, right: 16),
        child: bubble(
          'Спасибо за то, что помогаешь мне... Я тут подумал, что на самом деле есть несколько способов вернуться домой',
        ),
      );
    }
    if (c.step == 1) {
      return Column(
        children: [
          earthArt('taxi', height: 155),
          bubble(
            'Способов много, но для них нужны фиры. Давай накопим? Выбери цель и откладывай монеты в копилку',
            avatar: true,
          ),
          for (final type in [
            BigGoalType.spaceTaxi,
            BigGoalType.repairShip,
            BigGoalType.contactHome,
          ])
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: StrannikTapTarget(
                label: EconomyConfig.goals[type]!.title,
                selected: c.goalType == type,
                onTap: c.busy || c.persistedGoal?.isConfirmed == true
                    ? null
                    : () => c.chooseGoal(type),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(
                      color: c.goalType == type
                          ? AppColors.green
                          : AppColors.black,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      earthArt(
                        EconomyConfig.goals[type]!.art,
                        width: 72,
                        height: 65,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            text(switch (type) {
                              BigGoalType.spaceTaxi => 'Вызвать космо-такси',
                              BigGoalType.repairShip => 'Ремонт ракеты',
                              BigGoalType.contactHome => 'Попросить друзей',
                            }, size: 16),
                            text(
                              EconomyConfig.goals[type]!.description,
                              size: 12,
                            ),
                            text('${EconomyConfig.goals[type]!.target} ₣'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }
    final definition =
        EconomyConfig.goals[c.goalType ?? BigGoalType.spaceTaxi]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        text('Коплю на цель', size: 24, align: TextAlign.center),
        earthArt(definition.art, height: 140),
        text(definition.title, size: 20, align: TextAlign.center),
        text(
          '${c.plan.remainder}/${definition.target} ₣',
          size: 28,
          align: TextAlign.center,
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: math.min(1, c.plan.remainder / definition.target),
          minHeight: 12,
          color: AppColors.green,
        ),
        const SizedBox(height: 20),
        if (c.plan.mandatory + c.plan.optional == 0) ...[
          text(
            'На общем балансе ${c.wallet} ₣. Сначала запланируй суммы для «Нужно» и «Хочу», затем выбери, сколько отложить на цель.',
          ),
          _moneyField(need, 'Нужно'),
          _moneyField(want, 'Хочу'),
          button(
            'Сохранить план',
            () => c.initialPlan(
              int.tryParse(need.text) ?? 0,
              int.tryParse(want.text) ?? 0,
            ),
          ),
        ] else ...[
          text('Откуда переложить запланированные фиры?'),
          for (final source in [BudgetCategory.need, BudgetCategory.want])
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ChoiceChip(
                label: text(
                  '${categoryName(source)}: ${c.plan.amountFor(source)} ₣',
                ),
                selected: c.source == source,
                onSelected: c.busy
                    ? null
                    : (_) {
                        setState(() {
                          c.source = source;
                          amount.clear();
                        });
                      },
                selectedColor: categoryColor(source),
              ),
            ),
          _moneyField(amount, 'Сколько отложить'),
          Slider(
            value: (int.tryParse(amount.text) ?? 0)
                .clamp(0, c.plan.amountFor(c.source))
                .toDouble(),
            max: math.max(1, c.plan.amountFor(c.source)).toDouble(),
            activeColor: AppColors.blue,
            onChanged: c.busy
                ? null
                : (v) => setState(() => amount.text = v.round().toString()),
          ),
          text('Фиры останутся на общем балансе. Изменится только план.'),
        ],
      ],
    );
  }

  Widget _moneyField(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
  Widget _completion() => Column(
    children: [
      const SizedBox(height: 24),
      lessonArt('reward_cat', height: 240),
      const SizedBox(height: 24),
      text(
        c.needs
            ? 'Ура! Мы купили всё необходимое'
            : c.weekly
            ? 'Планы на неделю'
            : 'Цель поставлена',
        size: 24,
        align: TextAlign.center,
      ),
      const SizedBox(height: 16),
      text(
        c.needs
            ? 'Ты показал Страннику магазин и научил его выбирать нужное!'
            : c.weekly
            ? 'Ты научил Странника планировать бюджет на неделю!'
            : 'Теперь вы копите на своё первое космическое путешествие!',
        size: 16,
        align: TextAlign.center,
      ),
      const SizedBox(height: 24),
      text(
        c.rewardClaimed ? 'Задание уже выполнено' : '+${c.task.rewardFira} ₣',
        size: 32,
        align: TextAlign.center,
      ),
    ],
  );
  Widget _actions() {
    if (c.done) {
      return button(
        'Следующее задание',
        c.task.id == EarthTopicOne.goalId ? widget.onHome : widget.onNext,
      );
    }
    if (c.needs) {
      return switch (c.step) {
        0 => button(
          'Начать',
          () => c.change(() {
            c.step = 1;
          }),
          secondary: true,
        ),
        1 => const SizedBox.shrink(),
        2 || 3 => button('Всё необходимое взяли', c.confirmBasket),
        4 => button('Проверить', _check),
        _ => button('Сохранить результат', c.finish),
      };
    }
    if (c.weekly) {
      return switch (c.simulation.step) {
        WeeklyStep.calculate => button('Проверить', _check),
        WeeklyStep.shop => const SizedBox.shrink(),
        WeeklyStep.secondShop => button(
          c.simulation.branch == WeeklyBranch.expensive
              ? 'Продолжить'
              : c.simulation.branch == WeeklyBranch.wait
              ? 'Купить крутую ракету'
              : 'Купить вторую мышку',
          c.advanceWeekly,
        ),
        WeeklyStep.ready => button('Сохранить результат', c.finish),
        _ => button('Продолжить', c.advanceWeekly),
      };
    }
    return switch (c.step) {
      0 => button(
        'Какие?',
        () => c.change(() {
          c.step = 1;
        }),
        secondary: true,
      ),
      1 => button('Выбрать', c.goalType == null ? null : c.confirmGoal),
      2 => button(
        'Сохранить',
        c.plan.mandatory + c.plan.optional > 0 &&
                (int.tryParse(amount.text) ?? 0) > 0 &&
                (int.tryParse(amount.text) ?? 0) <= c.plan.amountFor(c.source)
            ? () {
                FocusScope.of(context).unfocus();
                c.allocateGoal(int.parse(amount.text));
              }
            : null,
      ),
      _ => button('Сохранить результат', c.finish),
    };
  }
}
