import 'package:flutter/foundation.dart';

import '../../app/bootstrap.dart';
import '../../content/lessons/earth_topic_one.dart';
import '../../core/result.dart';
import '../../domain/models/budget_category.dart';
import '../../domain/models/models.dart';

enum BankPage { home, allocation, reallocation, history, success }

class BankSnapshot {
  const BankSnapshot(
    this.wallet,
    this.plan,
    this.savings,
    this.history,
    this.explained,
    this.goal,
  );
  final Wallet wallet;
  final BudgetAllocation plan;
  final SavingsGoal? savings;
  final List<Transaction> history;
  final bool explained;
  final BigGoal? goal;
  int get unallocated =>
      (wallet.firaAmount - plan.total).clamp(0, maxGameValue);
  int get shortfall => plan.shortfall(wallet);
}

/// SQLite is the source of truth. Only unsaved editor input lives here.
class BankController extends ChangeNotifier {
  BankController(this.game);
  final GameServices game;
  static const tooltipId = 'bank_budget_explanation_v1';
  BankSnapshot? snapshot;
  BankPage page = BankPage.home;
  BudgetAllocation draft = BudgetAllocation(
    mandatory: 0,
    optional: 0,
    remainder: 0,
  );
  BudgetCategory destination = BudgetCategory.need;
  BudgetCategory? source;
  int? moveAmount = 0;
  final Set<BudgetCategory> invalidFields = {};
  bool loading = false, busy = false, _disposed = false;
  String? error;
  int? explanationStep;
  int _loadVersion = 0;
  int get available => snapshot?.wallet.firaAmount ?? 0;
  int get remaining => available - draft.total;
  bool get validDraft => invalidFields.isEmpty && draft.total <= available;
  bool get validMove =>
      snapshot != null &&
      source != null &&
      source != destination &&
      moveAmount != null &&
      moveAmount! > 0 &&
      moveAmount! <= snapshot!.plan.amountFor(source!) &&
      snapshot!.shortfall == 0;
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final version = ++_loadVersion;
    loading = snapshot == null;
    _publish();
    final result = await game.context.run(
      (r) async => BankSnapshot(
        await r.economy.wallet(),
        await r.economy.budget() ??
            BudgetAllocation(mandatory: 0, optional: 0, remainder: 0),
        await r.economy.savings(),
        List.unmodifiable((await r.economy.transactions()).reversed),
        (await r.system.shownTooltips()).contains(tooltipId),
        (await r.learning.learningProgress(EarthTopicOne.goalId)).completed
            ? await r.progress.bigGoal()
            : null,
      ),
    );
    if (_disposed || version != _loadVersion) return;
    loading = false;
    switch (result) {
      case Success(value: final value):
        final firstLoad = snapshot == null;
        snapshot = value;
        if (firstLoad && !value.explained) explanationStep = 0;
        error = null;
      case Rejected():
        error = 'Не получилось открыть счёт. Попробуй ещё раз.';
    }
    _publish();
  }

  void openAllocation() {
    if (busy || snapshot == null) return;
    draft = snapshot!.plan;
    invalidFields.clear();
    error = null;
    page = BankPage.allocation;
    _publish();
  }

  Future<void> fulfilGoal() async {
    if (busy) return;
    busy = true;
    _publish();
    final result = await game.progression.fulfilFinancialGoal();
    await load();
    if (result is Rejected) {
      error =
          'Не получилось оплатить цель. Проверь накопления и попробуй ещё раз.';
    }
    busy = false;
    _publish();
  }

  /// Recover legacy reserved funds through the existing atomic transfer.
  /// Planning categories and the selected BigGoal are never separate accounts.
  Future<void> returnLegacySavings() async {
    final amount = snapshot?.savings?.savedAmount ?? 0;
    if (busy || amount == 0) return;
    busy = true;
    error = null;
    _publish();
    try {
      final result = await game.savings.withdrawFromSavings(amount);
      await load();
      if (result is Rejected) {
        error =
            'Не получилось вернуть фиры. Проверь баланс и попробуй ещё раз.';
      }
    } finally {
      busy = false;
      _publish();
    }
  }

  void setAllocation(BudgetCategory category, int? value) {
    if (busy || page != BankPage.allocation) return;
    if (value == null ||
        value < 0 ||
        value > maxGameValue - (draft.total - draft.amountFor(category))) {
      invalidFields.add(category);
    } else {
      invalidFields.remove(category);
      draft = draft.withCategory(category, value);
    }
    error = null;
    _publish();
  }

  void openReallocation(BudgetCategory category) {
    if (busy || snapshot == null) return;
    if (snapshot!.shortfall > 0) {
      openAllocation();
      return;
    }
    destination = category;
    source = null;
    moveAmount = 0;
    error = null;
    page = BankPage.reallocation;
    _publish();
  }

  void selectSource(BudgetCategory category) {
    if (busy || page != BankPage.reallocation || category == destination) {
      return;
    }
    source = category;
    moveAmount = 0;
    error = null;
    _publish();
  }

  void setMoveAmount(int? value) {
    if (busy || page != BankPage.reallocation) return;
    moveAmount = value;
    error = null;
    _publish();
  }

  void showHistory() {
    if (busy) return;
    page = BankPage.history;
    error = null;
    _publish();
  }

  void home() {
    if (busy) return;
    page = BankPage.home;
    invalidFields.clear();
    error = null;
    _publish();
  }

  Future<void> dismissExplanation() async {
    if (busy) return;
    // Immediately dismiss even on a failed write, so help never traps the child.
    explanationStep = null;
    _publish();
    final result = await game.context.run(
      (r) => r.system.markTooltipShown(tooltipId),
    );
    if (result is Rejected) {
      error = 'Не удалось сохранить подсказку. Счёт всё равно доступен.';
      _publish();
    }
  }

  Future<void> nextExplanation() async {
    if (explanationStep == null) return;
    if (explanationStep! == 3) {
      await dismissExplanation();
      return;
    }
    explanationStep = explanationStep! + 1;
    _publish();
  }

  void explain() {
    if (!busy) {
      explanationStep = 0;
      _publish();
    }
  }

  Future<bool> save() async {
    final editing = page;
    if (busy ||
        snapshot == null ||
        (editing != BankPage.allocation && editing != BankPage.reallocation) ||
        (editing == BankPage.allocation ? !validDraft : !validMove)) {
      return false;
    }
    busy = true;
    error = null;
    _publish();
    try {
      final result = editing == BankPage.allocation
          ? await game.economy.allocateBudget(
              mandatory: draft.mandatory,
              optional: draft.optional,
              remainder: draft.remainder,
            )
          : await game.economy.reallocateBudget(
              source: source!,
              destination: destination,
              amount: moveAmount!,
            );
      if (_disposed) return false;
      if (result case Rejected(reason: final reason)) {
        await load();
        error = switch (reason) {
          Failure.insufficientFunds =>
            'Баланс или план изменился. Проверь суммы и попробуй снова.',
          Failure.invalidAmount => 'Введи целое положительное количество фир.',
          Failure.invalidState ||
          Failure.notFound => 'План изменился. Вернись к счёту и проверь его.',
          _ => 'Не получилось сохранить план. Попробуй ещё раз.',
        };
        return false;
      }
      // Commit succeeded: success must remain truthful even if refresh fails.
      page = BankPage.success;
      await load();
      return true;
    } catch (_) {
      error = 'Не получилось сохранить план. Попробуй ещё раз.';
      return false;
    } finally {
      busy = false;
      _publish();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
