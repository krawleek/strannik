import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../content/localization/fira_format.dart';
import '../../core/result.dart';
import '../../domain/models/models.dart';
import '../../domain/models/store_snapshot.dart';
import '../components/pet_appearance.dart';
import '../components/strannik_button.dart';
import '../components/strannik_stage_badge.dart';
import '../components/strannik_tap_target.dart';
import '../foundation/app_tokens.dart';
import 'store_assets.dart';
import 'store_controller.dart';

const _sheetColor = Color(0xFFF3F4F6);
TextStyle _type(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.ink,
}) => TextStyle(
  fontFamily: AppTypography.family,
  fontSize: size,
  height: 1.2,
  fontWeight: weight,
  color: color,
);
Widget _image(String path, {double? width, double? height}) => Image.asset(
  path,
  width: width,
  height: height,
  fit: BoxFit.contain,
  excludeFromSemantics: true,
);

class StoreScreen extends StatefulWidget {
  const StoreScreen({
    super.key,
    required this.controller,
    required this.onHome,
    required this.onLearning,
  });
  final StoreController controller;
  final VoidCallback onHome, onLearning;
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with WidgetsBindingObserver {
  StoreController get c => widget.controller;
  String? reaction;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (c.snapshot == null) c.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) c.load();
  }

  void back() {
    if (c.busy) return;
    if (c.selectedId != null) {
      c.select(null);
      setState(() => reaction = null);
    } else if (c.closet) {
      c.showCloset(false);
    } else {
      widget.onHome();
    }
  }

  Future<void> select(StoreItem item) async {
    if (c.busy) return;
    c.select(item.id);
    setState(() => reaction = null);
    if (c.closet && item.category == ItemCategory.accessory) await c.use(item);
  }

  Future<void> useSelected() async {
    final item = c.selected;
    if (item == null || c.busy) return;
    final before = c.snapshot?.pet?.xp ?? 0;
    final ok = await c.use(item);
    if (!mounted || !ok) return;
    final earned = (c.snapshot?.pet?.xp ?? 0) - before;
    setState(
      () => reaction = earned > 0
          ? 'Здорово! +$earned опыта'
          : 'Рад поиграть с тобой ещё!',
    );
  }

  Future<void> checkout() async {
    final item = c.selected;
    if (item == null ||
        c.busy ||
        c.closet ||
        c.locked(item) ||
        (item.permanent && c.owned(item))) {
      return;
    }
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: _sheetColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => _CheckoutSheet(controller: c, item: item),
    );
    if (!mounted) return;
    c.select(null);
    if (result == 'learning') widget.onLearning();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        backgroundColor: AppColors.yellow,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              c.closet ? StoreAssets.closetRoom : StoreAssets.room,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              excludeFromSemantics: true,
            ),
            SafeArea(
              child: c.snapshot == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: c.error == null
                            ? const CircularProgressIndicator()
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    c.error!,
                                    style: _type(18),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  StrannikButton(
                                    label: 'Попробовать снова',
                                    onPressed: c.load,
                                  ),
                                ],
                              ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final contentHeight = math.max(
                          600.0,
                          constraints.maxHeight,
                        );
                        final selected = c.selected;
                        return SingleChildScrollView(
                          physics: constraints.maxHeight >= 600
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          child: SizedBox(
                            height: contentHeight,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    8,
                                    12,
                                    0,
                                  ),
                                  child: Row(
                                    children: [
                                      StrannikTapTarget(
                                        label: 'Назад',
                                        onTap: c.busy ? null : back,
                                        child: SizedBox(
                                          width: 48,
                                          height: 56,
                                          child: Center(
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: _image(
                                                  'assets/profile/back.png',
                                                  width: 24,
                                                  height: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Flexible(
                                        flex: 4,
                                        child: StrannikStageBadge(
                                          stageNumber: c.stage.index + 1,
                                          progressLabel: c.requiredXp == null
                                              ? '${c.snapshot!.pet?.xp ?? 0} XP'
                                              : '${c.snapshot!.pet?.xp ?? 0}/${c.requiredXp}',
                                          progressIsPlaceholder: false,
                                          onTap: () {
                                            setState(
                                              () => reaction =
                                                  'Опыт: ${c.snapshot!.pet?.xp ?? 0}${c.requiredXp == null ? '' : '. Для следующего этапа: ${c.requiredXp}'}',
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        flex: 3,
                                        child: _MoneyBadge(
                                          amount: c.snapshot!.wallet.firaAmount,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, area) {
                                      final width = math.min(
                                        330.0,
                                        math.min(
                                          area.maxWidth - 69,
                                          area.maxHeight * 291 / 310,
                                        ),
                                      );
                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => c.select(null),
                                        child: Stack(
                                          children: [
                                            Align(
                                              alignment: const Alignment(0, .5),
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 9,
                                                ),
                                                child: SizedBox(
                                                  width: width,
                                                  child: PetAppearance(
                                                    pet: c.snapshot!.pet,
                                                    accessoryId:
                                                        c.shownAccessory,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (c.error != null ||
                                                reaction != null ||
                                                (selected != null &&
                                                    c.locked(selected)))
                                              Positioned(
                                                left: 16,
                                                right: 16,
                                                top: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: AppColors.ink,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    c.error ??
                                                        reaction ??
                                                        '${selected!.title}: нужно ${selected.requiredXp} опыта и этап ${selected.requiredStage.index + 1}.',
                                                    style: _type(14),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            if (c.closet &&
                                                selected != null &&
                                                selected.category !=
                                                    ItemCategory.accessory)
                                              Positioned(
                                                left: 24,
                                                right: 24,
                                                bottom: 12,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (selected.category ==
                                                        ItemCategory
                                                            .shipMaterial)
                                                      Container(
                                                        color: Colors.white,
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        child: Text(
                                                          'Материал для большой цели. В наличии: ${c.quantity(selected)}',
                                                          style: _type(14),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      )
                                                    else
                                                      StrannikButton(
                                                        label: c.busy
                                                            ? 'Подожди…'
                                                            : c.useLabel(
                                                                selected,
                                                              ),
                                                        onPressed: c.busy
                                                            ? null
                                                            : useSelected,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(
                                  height: 78,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _StoreTab(
                                        label: 'Магазин',
                                        asset: 'assets/store/shop.png',
                                        color: AppColors.pink,
                                        onTap: c.busy
                                            ? null
                                            : () => c.showCloset(false),
                                        selected: !c.closet,
                                      ),
                                      _StoreTab(
                                        label: 'Шкаф',
                                        asset: 'assets/store/closet.png',
                                        color: AppColors.lightBlue,
                                        onTap: c.busy
                                            ? null
                                            : () => c.showCloset(true),
                                        selected: c.closet,
                                      ),
                                      const Spacer(),
                                      if (!c.closet)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            0,
                                            0,
                                            12,
                                            8,
                                          ),
                                          child: SizedBox(
                                            width: 80,
                                            child: StrannikButton(
                                              label: 'Корзина',
                                              onPressed:
                                                  selected == null ||
                                                      c.busy ||
                                                      c.locked(selected) ||
                                                      (selected.permanent &&
                                                          c.owned(selected))
                                                  ? null
                                                  : checkout,
                                              child: _image(
                                                'assets/store/cart.png',
                                                width: 52,
                                                height: 42,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                ColoredBox(
                                  color: c.closet
                                      ? AppColors.lightBlue
                                      : AppColors.pink,
                                  child: SizedBox(
                                    height: 136,
                                    child: c.closet && c.visibleItems.isEmpty
                                        ? Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 25,
                                            ),
                                            child: Row(
                                              children: [
                                                _image(
                                                  'assets/store/closet.png',
                                                  width: 48,
                                                  height: 56,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Шкаф пока пуст. Но скоро тут появится твоя первая покупка!',
                                                    style: _type(14),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              24,
                                              16,
                                              10,
                                            ),
                                            itemCount: c.visibleItems.length,
                                            separatorBuilder: (_, _) =>
                                                const SizedBox(width: 8),
                                            itemBuilder: (context, index) {
                                              final item =
                                                  c.visibleItems[index];
                                              return _ProductCard(
                                                item: item,
                                                selected:
                                                    c.selectedId == item.id,
                                                closet: c.closet,
                                                quantity: c.quantity(item),
                                                locked: c.locked(item),
                                                equipped:
                                                    c
                                                        .snapshot!
                                                        .pet
                                                        ?.equippedAccessoryId ==
                                                    item.id,
                                                onTap: c.busy
                                                    ? null
                                                    : () => select(item),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                              ],
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
}

class _StoreTab extends StatelessWidget {
  const _StoreTab({
    required this.label,
    required this.asset,
    required this.color,
    required this.onTap,
    required this.selected,
  });
  final String label, asset;
  final Color color;
  final VoidCallback? onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => StrannikTapTarget(
    label: label,
    selected: selected,
    onTap: onTap,
    child: Container(
      width: 100,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(12),
      child: _image(asset, width: label == 'Магазин' ? 60 : 40, height: 54),
    ),
  );
}

class _MoneyBadge extends StatelessWidget {
  const _MoneyBadge({required this.amount});
  final int amount;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Баланс: ${formatFira(amount)}',
    child: Container(
      constraints: const BoxConstraints(minWidth: 50, minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.ink, width: 3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$amount ₣',
        style: _type(20, weight: FontWeight.w800),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

class _ProductArt extends StatelessWidget {
  const _ProductArt(this.item);
  final StoreItem item;
  @override
  Widget build(BuildContext context) {
    final asset = StoreAssets.product(item);
    return asset == null
        ? Center(
            child: Text(
              '${item.title}\nНет изображения',
              style: _type(12),
              textAlign: TextAlign.center,
            ),
          )
        : Image.asset(
            asset,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => Center(
              child: Text(
                '${item.title}\nНет изображения',
                style: _type(12),
                textAlign: TextAlign.center,
              ),
            ),
          );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.item,
    required this.selected,
    required this.closet,
    required this.quantity,
    required this.locked,
    required this.equipped,
    required this.onTap,
  });
  final StoreItem item;
  final bool selected, closet, locked, equipped;
  final int quantity;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => StrannikTapTarget(
    label:
        '${item.title}. ${closet ? 'В наличии: $quantity' : formatFira(item.price)}${equipped ? '. Надето' : ''}${locked ? '. Пока недоступно' : ''}',
    selected: selected,
    onTap: onTap,
    child: SizedBox(
      width: 102,
      height: 102,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 102,
            height: 102,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.yellow
                  : closet
                  ? Colors.white
                  : AppColors.lightOrange,
              borderRadius: BorderRadius.circular(16),
              border: equipped
                  ? Border.all(color: AppColors.green, width: 3)
                  : null,
            ),
            child: _ProductArt(item),
          ),
          if (!closet)
            Positioned(
              right: -6,
              top: -10,
              child: _MoneyBadge(amount: item.price),
            ),
          if (closet && (!item.permanent || quantity > 1))
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(3),
                child: Text('×$quantity', style: _type(12)),
              ),
            ),
          if (locked)
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .8),
                  shape: BoxShape.circle,
                ),
                child: _image('assets/profile/lock.png', width: 20, height: 26),
              ),
            ),
        ],
      ),
    ),
  );
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({required this.controller, required this.item});
  final StoreController controller;
  final StoreItem item;
  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  StoreController get c => widget.controller;
  String step = 'cart';
  PurchasePurpose? purpose;
  late final String operationId = c.game.context.ids.next();
  Future<void> pay() async {
    if (c.busy) return;
    if (c.snapshot!.wallet.firaAmount < widget.item.price) {
      setState(() => step = 'insufficient');
      return;
    }
    final ok = await c.buy(widget.item, operationId, purpose: purpose);
    if (!mounted) return;
    if (ok) {
      setState(() => step = 'success');
    } else if (c.failure == Failure.insufficientFunds) {
      setState(() => step = 'insufficient');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => PopScope(
      canPop: !c.busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 48),
                        Expanded(
                          child: Text(
                            switch (step) {
                              'cart' => 'Корзина',
                              'accounts' => 'Выбери счет',
                              'success' => 'Ура! Покупка твоя!',
                              _ => 'Ой, фир не хватает!',
                            },
                            style: _type(24, weight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Закрыть',
                          onPressed: c.busy
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (step == 'cart') ...[
                      const SizedBox(height: 12),
                      _ProductCard(
                        item: widget.item,
                        selected: true,
                        closet: false,
                        quantity: 0,
                        locked: false,
                        equipped: false,
                        onTap: null,
                      ),
                      const SizedBox(height: 24),
                      Text(widget.item.title, style: _type(16)),
                      const SizedBox(height: 12),
                      summary(),
                    ],
                    if (step == 'accounts') ...[
                      const SizedBox(height: 12),
                      accounts(),
                      const SizedBox(height: 12),
                      Text(
                        'Нужно и Хочу — план расходов. Оплата из общего баланса: ${formatFira(c.snapshot!.wallet.firaAmount)}.',
                        style: _type(12),
                        textAlign: TextAlign.center,
                      ),
                      if (purpose != null &&
                          c.snapshot!.budget != null &&
                          plannedAmount < widget.item.price)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Покупка выше плана на ${formatFira(widget.item.price - plannedAmount)}. План не является отдельным счётом.',
                            style: _type(12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                    if (step == 'success') ...[
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Предмет ждёт тебя в шкафу. Можешь использовать его в любой момент.',
                        style: _type(14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Осталось: ${formatFira(c.snapshot!.wallet.firaAmount)}',
                        style: _type(16),
                      ),
                    ],
                    if (step == 'insufficient') ...[
                      const Icon(
                        Icons.error,
                        color: Color(0xFFEC2C2F),
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      summary(insufficient: true),
                      const SizedBox(height: 16),
                      Text(
                        'Пока покупка не по карману. Можно заработать ещё или вернуться позже.',
                        style: _type(14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (c.error != null && step != 'insufficient')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          c.error!,
                          style: _type(14, color: const Color(0xFFAF2025)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (step == 'cart')
                StrannikButton(
                  label: 'Купить',
                  backgroundColor: AppColors.blue,
                  onPressed: c.busy
                      ? null
                      : () {
                          setState(
                            () => step =
                                c.snapshot!.wallet.firaAmount <
                                    widget.item.price
                                ? 'insufficient'
                                : 'accounts',
                          );
                        },
                ),
              if (step == 'accounts')
                StrannikButton(
                  label: c.busy
                      ? 'Покупаем…'
                      : 'Оплатить ${formatFira(widget.item.price)}',
                  backgroundColor: AppColors.blue,
                  onPressed: c.busy ? null : pay,
                ),
              if (step == 'success')
                StrannikButton(
                  label: 'Назад в магазин',
                  backgroundColor: AppColors.blue,
                  onPressed: () => Navigator.pop(context),
                ),
              if (step == 'insufficient') ...[
                StrannikButton(
                  label: 'Заработать в заданиях',
                  onPressed: () => Navigator.pop(context, 'learning'),
                ),
                const SizedBox(height: 8),
                StrannikButton(
                  label: 'Накопить и вернуться позже',
                  backgroundColor: AppColors.blue,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  int get plannedAmount => purpose == PurchasePurpose.need
      ? c.snapshot!.budget?.mandatory ?? 0
      : c.snapshot!.budget?.optional ?? 0;
  Widget accounts() => Column(
    children: [
      _account(
        'Общий баланс',
        c.snapshot!.wallet.firaAmount,
        AppColors.yellow,
        purpose == null,
        () => setState(() => purpose = null),
      ),
      const SizedBox(height: 8),
      _account(
        'Нужно',
        c.snapshot!.budget?.mandatory,
        AppColors.pink,
        purpose == PurchasePurpose.need,
        c.snapshot!.budget == null
            ? null
            : () => setState(() => purpose = PurchasePurpose.need),
      ),
      const SizedBox(height: 8),
      _account(
        'Хочу',
        c.snapshot!.budget?.optional,
        AppColors.lightBlue,
        purpose == PurchasePurpose.want,
        c.snapshot!.budget == null
            ? null
            : () => setState(() => purpose = PurchasePurpose.want),
      ),
      const SizedBox(height: 8),
      _account(
        'Цель',
        c.snapshot!.savings?.savedAmount,
        const Color(0xFFE9FFF5),
        false,
        null,
        subtitle: 'Накопления нельзя потратить здесь',
      ),
    ],
  );
  Widget _account(
    String title,
    int? amount,
    Color color,
    bool selected,
    VoidCallback? onTap, {
    String? subtitle,
  }) => Semantics(
    selected: selected,
    button: true,
    enabled: onTap != null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: AppColors.blue, width: 2) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _type(16)),
                  if (subtitle != null) Text(subtitle, style: _type(11)),
                  if (amount == null && subtitle == null)
                    Text('План не задан', style: _type(11)),
                ],
              ),
            ),
            Text(
              amount == null ? '—' : '$amount ₣',
              style: _type(18, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
  Widget summary({bool insufficient = false}) {
    final balance = c.snapshot!.wallet.firaAmount, cost = widget.item.price;
    return Column(
      children: [
        _summaryRow('Стоимость покупки', cost, AppColors.lightBlue),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth < 290 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.15
              ? Column(
                  children: [
                    _summaryRow('На счете', balance, const Color(0xFFE9FFF5)),
                    const SizedBox(height: 8),
                    _summaryRow(
                      insufficient ? 'Не хватает' : 'Останется',
                      insufficient
                          ? math.max(0, cost - balance)
                          : math.max(0, balance - cost),
                      insufficient ? AppColors.pink : AppColors.yellow,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _summaryRow(
                        'На счете',
                        balance,
                        const Color(0xFFE9FFF5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryRow(
                        insufficient ? 'Не хватает' : 'Останется',
                        insufficient
                            ? math.max(0, cost - balance)
                            : math.max(0, balance - cost),
                        insufficient ? AppColors.pink : AppColors.yellow,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, int amount, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(child: Text(label, style: _type(14))),
        const SizedBox(width: 4),
        Text('$amount ₣', style: _type(16, weight: FontWeight.w800)),
      ],
    ),
  );
}
