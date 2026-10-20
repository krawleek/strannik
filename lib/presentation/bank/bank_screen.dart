import 'package:flutter/material.dart';

import '../../content/economy_config.dart';

import '../../app/bootstrap.dart';
import '../../content/localization/fira_format.dart';
import '../../domain/models/budget_category.dart';
import '../../domain/models/models.dart';
import '../components/strannik_button.dart';
import '../components/strannik_speech_bubble.dart';
import '../components/strannik_tap_target.dart';
import '../foundation/app_tokens.dart';
import 'bank_controller.dart';

const _mint = Color(0xFFE9FFF5);
const _historyBlue = Color(0xFFE2EEFD);
const _errorRed = Color(0xFFB71C1C);
const _track = Color(0xFFEDEDED);
const _income = Color(0xFF1E7638);

String categoryName(BudgetCategory category) => switch (category) {
  BudgetCategory.need => 'Нужно',
  BudgetCategory.want => 'Хочу',
  BudgetCategory.save => 'Коплю',
};
Color categoryColor(BudgetCategory category) => switch (category) {
  BudgetCategory.need => AppColors.pink,
  BudgetCategory.want => AppColors.yellow,
  BudgetCategory.save => _mint,
};
Color categoryAccent(BudgetCategory category) => switch (category) {
  BudgetCategory.need => const Color(0xFFEF2F3D),
  BudgetCategory.want => AppColors.lightOrange,
  BudgetCategory.save => AppColors.green,
};
String categoryAsset(BudgetCategory category) =>
    'assets/bank/${category.name}.png';
TextStyle _type(
  double size, {
  FontWeight weight = FontWeight.w800,
  Color color = AppColors.ink,
}) => AppTypography.body.copyWith(
  fontSize: size,
  fontWeight: weight,
  color: color,
);
Widget _art(String name, {double? width, double? height}) => Image.asset(
  'assets/bank/$name.png',
  width: width,
  height: height,
  fit: BoxFit.contain,
  excludeFromSemantics: true,
);

class BankScreen extends StatefulWidget {
  const BankScreen({
    super.key,
    required this.game,
    required this.onHome,
    required this.onStore,
    this.controller,
  });
  final GameServices game;
  final VoidCallback onHome, onStore;

  /// Optional for tests; production owns a controller for this screen's lifetime.
  final BankController? controller;
  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> with WidgetsBindingObserver {
  late final c = widget.controller ?? BankController(widget.game);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (c.snapshot == null) c.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !c.busy) c.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  Future<void> back() async {
    if (c.busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (c.explanationStep != null) {
      await c.dismissExplanation();
    } else if (c.page == BankPage.home) {
      widget.onHome();
    } else {
      // Draft fields are discarded without touching the saved plan.
      c.home();
    }
  }

  String get title => switch (c.page) {
    BankPage.home => 'Денежный счёт',
    BankPage.allocation => 'План расходов',
    BankPage.reallocation => 'Изменить план',
    BankPage.history => 'История',
    BankPage.success => '',
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        backgroundColor: c.page == BankPage.success
            ? AppColors.yellow
            : AppColors.lightBlue,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 22),
                    child: Row(
                      children: [
                        IconButton(
                          key: const ValueKey('bank-back'),
                          tooltip: 'Назад',
                          onPressed: c.busy ? null : back,
                          icon: const Icon(
                            Icons.chevron_left,
                            color: AppColors.black,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: _type(24),
                          ),
                        ),
                        if (c.page == BankPage.home)
                          IconButton(
                            tooltip: 'Как устроен план',
                            onPressed: c.explain,
                            icon: const Icon(
                              Icons.help_outline,
                              color: AppColors.blue,
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: c.snapshot == null
                        ? _loading()
                        : c.page == BankPage.success
                        ? _success()
                        : SingleChildScrollView(
                            key: ValueKey('bank-${c.page.name}'),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (c.error != null) _notice(c.error!),
                                if (c.page == BankPage.home) ..._home(),
                                if (c.page == BankPage.allocation)
                                  ..._allocation(),
                                if (c.page == BankPage.reallocation)
                                  ..._reallocation(),
                                if (c.page == BankPage.history)
                                  _history(all: true),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                  ),
                  if (c.snapshot != null && c.page != BankPage.history)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                      child: _cta(),
                    ),
                ],
              ),
            ),
            if (c.explanationStep != null && c.snapshot != null) _explanation(),
          ],
        ),
      ),
    ),
  );

  Widget _loading() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            c.error ?? 'Открываем счёт…',
            style: _type(18),
            textAlign: TextAlign.center,
          ),
          if (c.error != null) ...[
            const SizedBox(height: 16),
            StrannikButton(
              label: 'Попробовать снова',
              onPressed: c.load,
              backgroundColor: AppColors.blue,
            ),
          ],
        ],
      ),
    ),
  );

  List<Widget> _home() {
    final s = c.snapshot!;
    return [
      _balance(),
      const SizedBox(height: 10),
      if (s.shortfall > 0) ...[
        _notice(
          'В плане на ${formatFira(s.shortfall)} больше, чем осталось. '
          'Покупки уже учтены в балансе. Давай изменим план.',
        ),
        const SizedBox(height: 10),
      ],
      LayoutBuilder(
        builder: (context, box) {
          final cards = [
            for (final category in [BudgetCategory.need, BudgetCategory.want])
              _category(
                category,
                s.plan.amountFor(category),
                onTap: () => c.openReallocation(category),
                compact: true,
              ),
          ];
          if (box.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(18) > 23) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [cards[0], const SizedBox(height: 10), cards[1]],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ],
          );
        },
      ),
      const SizedBox(height: 10),
      _category(
        BudgetCategory.save,
        s.plan.remainder,
        onTap: () => c.openReallocation(BudgetCategory.save),
        footer: s.goal == null ? _planBar(s.plan) : _goalProgress(),
      ),
      const SizedBox(height: 10),
      _history(),
      const SizedBox(height: 12),
      TextButton(
        onPressed: widget.onStore,
        child: Text('В магазин', style: _type(16, color: AppColors.blue)),
      ),
    ];
  }

  Widget _goalProgress() {
    final s = c.snapshot!;
    final goal = s.goal!;
    final definition = EconomyConfig.goals[goal.type]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/earth/${definition.art}.png',
              width: 88,
              height: 90,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(definition.title, style: _type(18)),
                  Text(
                    goal.isCompleted
                        ? 'Цель выполнена'
                        : '${s.plan.remainder}/${definition.target} ₣',
                    style: _type(20),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!goal.isCompleted) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (s.plan.remainder / definition.target).clamp(0, 1),
            minHeight: 10,
            color: AppColors.green,
          ),
          if (s.plan.remainder >= definition.target && s.shortfall == 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: StrannikButton(
                label: 'Осуществить цель за ${definition.target} ₣',
                onPressed: c.busy ? null : c.fulfilGoal,
                backgroundColor: AppColors.blue,
              ),
            ),
        ] else
          Text(switch (goal.type) {
            BigGoalType.spaceTaxi => 'Космо-такси вызвано!',
            BigGoalType.contactHome => 'Приёмник готов. Можно позвать друзей!',
            BigGoalType.repairShip => 'Ремонт ракеты оплачен!',
          }, style: _type(16)),
      ],
    );
  }

  Widget _balance() => Container(
    constraints: const BoxConstraints(minHeight: 136),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text('Баланс', style: _type(20)),
            Semantics(
              label: 'Доступный баланс: ${formatFira(c.available)}',
              excludeSemantics: true,
              child: _coins(c.available, big: true),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _planBar(c.page == BankPage.allocation ? c.draft : c.snapshot!.plan),
        if ((c.snapshot!.savings?.savedAmount ?? 0) > 0) ...[
          const SizedBox(height: 12),
          Text(
            'В цели отдельно: ${formatFira(c.snapshot!.savings!.savedAmount)}. '
            'Они не входят в этот баланс.',
            style: _type(12, weight: FontWeight.w600),
          ),
          TextButton(
            onPressed: c.busy ? null : c.returnLegacySavings,
            child: const Text('Вернуть фиры на баланс'),
          ),
        ],
      ],
    ),
  );

  Widget _planBar(BudgetAllocation plan) => Semantics(
    label:
        'Запланировано ${formatFira(plan.total)} из ${formatFira(c.available)}',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: LayoutBuilder(
          builder: (context, box) {
            final denominator = c.available > plan.total
                ? c.available
                : plan.total;
            return Row(
              children: [
                for (final category in BudgetCategory.values)
                  if (plan.amountFor(category) > 0 && denominator > 0)
                    SizedBox(
                      width:
                          box.maxWidth * plan.amountFor(category) / denominator,
                      child: ColoredBox(color: categoryColor(category)),
                    ),
                const Expanded(child: ColoredBox(color: _track)),
              ],
            );
          },
        ),
      ),
    ),
  );

  List<Widget> _allocation() => [
    _balance(),
    const SizedBox(height: 10),
    for (final category in BudgetCategory.values) ...[
      _category(
        category,
        c.draft.amountFor(category),
        footer: BankAmountControl(
          key: ValueKey('allocation-${category.name}'),
          label: categoryName(category),
          value: c.invalidFields.contains(category)
              ? null
              : c.draft.amountFor(category),
          maximum: (c.available - (c.draft.total - c.draft.amountFor(category)))
              .clamp(0, c.available),
          enabled: !c.busy,
          color: categoryAccent(category),
          onChanged: (value) => c.setAllocation(category, value),
        ),
      ),
      const SizedBox(height: 10),
    ],
    Text(
      c.remaining >= 0
          ? 'Осталось распределить: ${formatFira(c.remaining)}'
          : 'План больше баланса на ${formatFira(-c.remaining)}',
      style: _type(16, color: c.remaining < 0 ? _errorRed : AppColors.blue),
    ),
    if (c.invalidFields.isNotEmpty) ...[
      const SizedBox(height: 8),
      _notice('Введи целое неотрицательное количество фир.'),
    ],
    const SizedBox(height: 12),
    Text(
      'Это твой план. Деньги остаются на общем балансе. '
      '«Коплю» — сколько ты планируешь отложить, а не взнос в цель.',
      style: _type(12, weight: FontWeight.w600),
    ),
  ];

  List<Widget> _reallocation() => [
    _category(c.destination, c.snapshot!.plan.amountFor(c.destination)),
    const SizedBox(height: 24),
    Text('Откуда возьмём монетки?', style: _type(18)),
    const SizedBox(height: 10),
    for (final category in BudgetCategory.values.where(
      (v) => v != c.destination,
    )) ...[
      _category(
        category,
        c.snapshot!.plan.amountFor(category),
        onTap: () => c.selectSource(category),
        selected: c.source == category,
      ),
      const SizedBox(height: 10),
    ],
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Сколько перераспределить?', style: _type(18)),
          BankAmountControl(
            key: ValueKey('move-${c.source?.name ?? 'none'}'),
            label: 'Сумма перераспределения',
            value: c.moveAmount,
            maximum: c.source == null
                ? 0
                : c.snapshot!.plan.amountFor(c.source!),
            enabled: c.source != null && !c.busy,
            color: categoryAccent(c.destination),
            onChanged: c.setMoveAmount,
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    if (c.source == null)
      Text('Выбери, из какой категории взять фиры.', style: _type(14))
    else if (!c.validMove)
      _notice(
        c.moveAmount == null || c.moveAmount! <= 0
            ? 'Введи целое число больше нуля.'
            : 'В категории «${categoryName(c.source!)}» не хватает запланированных фир.',
      )
    else
      Text(
        '${categoryName(c.source!)} → ${categoryName(c.destination)}: ${formatFira(c.moveAmount!)}',
        style: _type(16),
      ),
    const SizedBox(height: 12),
    Text(
      'Меняем только план. Общий баланс и деньги в цели не изменятся.',
      style: _type(12, weight: FontWeight.w600),
    ),
  ];

  Widget _category(
    BudgetCategory category,
    int amount, {
    VoidCallback? onTap,
    Widget? footer,
    bool compact = false,
    bool selected = false,
  }) {
    final content = Container(
      constraints: BoxConstraints(
        minHeight: compact
            ? 145
            : footer == null
            ? 72
            : 136,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: categoryColor(category),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: selected ? Border.all(color: AppColors.blue, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact) ...[
            _categoryHeading(category),
            const SizedBox(height: 38),
            Align(alignment: Alignment.centerRight, child: _coins(amount)),
          ] else
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [_categoryHeading(category), _coins(amount)],
            ),
          if (footer != null) ...[const SizedBox(height: 22), footer],
        ],
      ),
    );
    return onTap == null
        ? content
        : StrannikTapTarget(
            label:
                '${categoryName(category)}: ${formatFira(amount)}. ${c.page == BankPage.reallocation ? 'Выбрать источник' : 'Изменить план'}',
            onTap: c.busy ? null : onTap,
            selected: selected,
            child: content,
          );
  }

  Widget _categoryHeading(BudgetCategory category) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        categoryAsset(category),
        width: 32,
        height: 32,
        excludeFromSemantics: true,
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          categoryName(category),
          style: _type(18, color: AppColors.black),
        ),
      ),
    ],
  );
  Widget _coins(int value, {bool big = false}) => Container(
    padding: big ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text('$value', style: _type(big ? 40 : 24))),
        const SizedBox(width: 4),
        _art('coin', width: big ? 34 : 26),
      ],
    ),
  );

  Widget _history({bool all = false}) {
    final history = c.snapshot!.history;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _historyBlue,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'История',
                  style: _type(18, weight: FontWeight.w600),
                ),
              ),
              if (!all)
                TextButton(
                  onPressed: c.showHistory,
                  child: Text(
                    'Вся история',
                    style: _type(12, color: AppColors.blue),
                  ),
                ),
            ],
          ),
          if (history.isEmpty)
            Text(
              'Здесь появятся подарки, награды и покупки.',
              style: _type(14, weight: FontWeight.w600),
            ),
          for (final tx in all ? history : history.take(2)) ...[
            const SizedBox(height: 10),
            _historyRow(tx),
          ],
        ],
      ),
    );
  }

  Widget _historyRow(Transaction tx) {
    final title = switch (tx.type) {
      TransactionType.initialGrant => 'Подарок за знакомство',
      TransactionType.parentReward => 'Подарок от родителей',
      TransactionType.learningReward => tx.title ?? 'Награда за задание',
      TransactionType.purchase => tx.title ?? 'Покупка в магазине',
      TransactionType.savingsDeposit => 'Взнос в цель',
      TransactionType.savingsWithdrawal => 'Возврат из цели',
    };
    final detail = switch (tx.type) {
      TransactionType.initialGrant => 'первые фиры',
      TransactionType.parentReward => 'подарок',
      TransactionType.learningReward => 'награда за задание',
      TransactionType.purchase => tx.description ?? 'покупка',
      TransactionType.savingsDeposit => 'в накопления · ${tx.title ?? 'цель'}',
      TransactionType.savingsWithdrawal =>
        'на общий баланс · ${tx.title ?? 'цель'}',
    };
    final delta = tx.availableDelta;
    final date = tx.createdAt.toLocal();
    final now = widget.game.context.clock.now().toLocal();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final dateText = day == today
        ? 'сегодня'
        : day == DateTime(now.year, now.month, now.day - 1)
        ? 'вчера'
        : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _type(14, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '$dateText · $detail',
                  style: _type(12, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${delta < 0 ? '−' : '+'}${formatFira(tx.amount)}',
              style: _type(
                16,
                color: tx.direction == FinancialDirection.internalTransfer
                    ? AppColors.blue
                    : delta < 0
                    ? _errorRed
                    : _income,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(String text) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: _type(14, color: _errorRed, weight: FontWeight.w700),
      ),
    ),
  );
  Widget _cta() {
    final label = switch (c.page) {
      BankPage.home =>
        c.snapshot!.shortfall > 0
            ? 'Исправить план'
            : c.snapshot!.unallocated > 0
            ? 'Распределить ${formatFira(c.snapshot!.unallocated)}'
            : 'Изменить план',
      BankPage.allocation ||
      BankPage.reallocation => c.busy ? 'Сохраняем…' : 'Сохранить',
      BankPage.success => 'Отлично',
      BankPage.history => '',
    };
    final enabled =
        !c.busy &&
        switch (c.page) {
          BankPage.allocation => c.validDraft,
          BankPage.reallocation => c.validMove,
          _ => true,
        };
    return StrannikButton(
      label: label,
      backgroundColor: AppColors.blue,
      onPressed: !enabled
          ? null
          : () async {
              FocusManager.instance.primaryFocus?.unfocus();
              switch (c.page) {
                case BankPage.home:
                  c.openAllocation();
                case BankPage.allocation || BankPage.reallocation:
                  await c.save();
                case BankPage.success:
                  c.home();
                  await c.load();
                case BankPage.history:
                  break;
              }
            },
    );
  }

  Widget _success() => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BankSuccessArtwork(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Готово! Фиры распределены',
                style: _type(32, color: AppColors.black),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 42),
              child: Text(
                'Ты обновил свой план. Общий баланс не изменился.',
                style: _type(14, weight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            if (c.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: _notice(c.error!),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );

  Widget _explanation() {
    final step = c.explanationStep!;
    const texts = [
      'У нас есть фиры! Но не стоит тратить их все сразу. Давай разделим деньги, чтобы их точно хватило на всё важное.',
      'Нужно — это вещи, которые нужны нам каждый день. О нас заботятся родители, но здорово, когда мы можем и сами купить что-то необходимое!',
      'Хочу — иногда хочется побаловать себя и купить что-нибудь вкусное! И это тоже важно. Главное — не потратить на это всё, что есть в кармане.',
      'Коплю — а ещё полезно планировать, сколько фир отложить на будущее. Это пока только план: деньги остаются на общем балансе.',
    ];
    return Positioned.fill(
      child: BlockSemantics(
        child: ColoredBox(
          color: const Color(0x4D000000),
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 24, 14, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Закрыть подсказку',
                        onPressed: c.dismissExplanation,
                        icon: const Icon(Icons.close, color: AppColors.white),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _art('cat_avatar', width: 107, height: 80),
                    ),
                    StrannikSpeechBubble(
                      name: '',
                      showName: false,
                      compact: true,
                      child: Text(
                        texts[step],
                        style: _type(14, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StrannikButton(
                      label: step == 3 ? 'Всё понятно' : 'Далее',
                      backgroundColor: AppColors.blue,
                      onPressed: c.nextExplanation,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma illustration only; text, CTA and financial state stay native widgets.
class BankSuccessArtwork extends StatelessWidget {
  const BankSuccessArtwork({super.key});
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 360 / 390,
    child: LayoutBuilder(
      builder: (context, box) {
        final k = box.maxWidth / 360;
        const slots = [
          (178.475, 197.523, 181.525, 167.160),
          (178.5, 197.5, 90.25, 180.5),
          (73.671, 197.527, 104.804, 143.164),
          (0.0, 197.5, 178.5, 90.25),
          (0.0, 30.367, 178.475, 167.156),
          (79.75, 0.0, 98.75, 197.5),
          (178.475, 54.363, 104.804, 143.164),
          (178.5, 107.25, 180.5, 90.25),
        ];
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (var i = 0; i < slots.length; i++)
              Positioned(
                left: slots[i].$1 * k,
                top: slots[i].$2 * k,
                width: slots[i].$3 * k,
                height: slots[i].$4 * k,
                child: _art('ray_$i'),
              ),
            Positioned(
              left: 47 * k,
              top: 0,
              width: 266.53 * k,
              height: 356.78 * k,
              child: _art('success_wallet'),
            ),
          ],
        );
      },
    ),
  );
}

class BankAmountControl extends StatefulWidget {
  const BankAmountControl({
    super.key,
    required this.label,
    required this.value,
    required this.maximum,
    required this.enabled,
    required this.color,
    required this.onChanged,
  });
  final String label;
  final int? value;
  final int maximum;
  final bool enabled;
  final Color color;
  final ValueChanged<int?> onChanged;
  @override
  State<BankAmountControl> createState() => _BankAmountControlState();
}

class _BankAmountControlState extends State<BankAmountControl> {
  late final field = TextEditingController(text: '${widget.value ?? ''}');
  @override
  void didUpdateWidget(BankAmountControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        widget.value != null &&
        int.tryParse(field.text) != widget.value) {
      field.value = TextEditingValue(
        text: '${widget.value}',
        selection: TextSelection.collapsed(offset: '${widget.value}'.length),
      );
    }
  }

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CoinPlanSlider(
        label: widget.label,
        value: (widget.value ?? 0).clamp(0, widget.maximum),
        maximum: widget.maximum,
        enabled: widget.enabled,
        color: widget.color,
        onChanged: (value) => widget.onChanged(value),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: field,
        enabled: widget.enabled,
        key: ValueKey('amount-${widget.label}'),
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        textInputAction: TextInputAction.done,
        style: _type(18),
        decoration: InputDecoration(
          labelText: '${widget.label}, фиры',
          labelStyle: _type(12, weight: FontWeight.w600),
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          errorText:
              widget.value == null ||
                  widget.value! < 0 ||
                  widget.value! > widget.maximum
              ? 'Проверь сумму'
              : null,
        ),
        onChanged: (text) => widget.onChanged(int.tryParse(text.trim())),
      ),
    ],
  );
}

class CoinPlanSlider extends StatefulWidget {
  const CoinPlanSlider({
    super.key,
    required this.label,
    required this.value,
    required this.maximum,
    required this.enabled,
    required this.color,
    required this.onChanged,
  });
  final String label;
  final int value, maximum;
  final bool enabled;
  final Color color;
  final ValueChanged<int> onChanged;
  @override
  State<CoinPlanSlider> createState() => _CoinPlanSliderState();
}

class _CoinPlanSliderState extends State<CoinPlanSlider> {
  ImageStream? _stream;
  ImageInfo? _coin;
  late final listener = ImageStreamListener((image, _) {
    _coin?.dispose();
    setState(() => _coin = image);
  });
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(listener);
    _stream = const AssetImage(
      'assets/bank/coin.png',
    ).resolve(createLocalImageConfiguration(context))..addListener(listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(listener);
    _coin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    child: SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 12,
        activeTrackColor: widget.color,
        inactiveTrackColor: AppColors.white,
        disabledActiveTrackColor: widget.color,
        disabledInactiveTrackColor: AppColors.white,
        thumbShape: _CoinThumb(_coin),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: widget.value.toDouble(),
        min: 0,
        max: widget.maximum == 0 ? 1 : widget.maximum.toDouble(),
        // Small budgets have one stop per fira; large ones use integer rounding.
        divisions: widget.maximum > 0 && widget.maximum <= 10000
            ? widget.maximum
            : null,
        semanticFormatterCallback: (value) => formatFira(value.round()),
        onChanged: widget.enabled && widget.maximum > 0
            ? (value) => widget.onChanged(value.round())
            : null,
      ),
    ),
  );
}

class _CoinThumb extends SliderComponentShape {
  const _CoinThumb(this.coin);
  final ImageInfo? coin;
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(34, 34);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final image = coin?.image;
    if (image == null) return;
    context.canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: center, width: 33.7, height: 34),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}
