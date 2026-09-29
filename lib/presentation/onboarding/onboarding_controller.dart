import 'package:flutter/foundation.dart';

import '../../app/bootstrap.dart';
import '../../app/onboarding/onboarding_flow_service.dart';
import '../../core/result.dart';

// Draft navigation is deliberately transient; SQLite owns completion only.
enum OnboardingStep {
  intro,
  beam,
  arrival,
  street,
  childName,
  help,
  disguise,
  skin,
  petName,
  askParents,
  doorstep,
  parentVoice,
  petPersuades,
  handoff,
  parentHello,
  parentOffer,
  money,
  care,
  results,
  permission,
  pin,
  parentReady,
  childReady,
}

class OnboardingController extends ChangeNotifier {
  OnboardingController(GameServices game)
    : _game = game,
      _flow = OnboardingFlowService(game);
  final GameServices _game;
  final OnboardingFlowService _flow;
  bool? completed;
  bool busy = false, parentConsent = false, existingPin = false;
  bool _disposed = false, _pinAccepted = false;
  String childName = '', petName = '';
  int skinIndex = 0;
  OnboardingStep step = OnboardingStep.intro;
  String? error;
  static const skinIds = ['gray', 'orange', 'cream'];
  String get skinId => skinIds[skinIndex];
  bool get canGoBack => !busy && !_pinAccepted && step != OnboardingStep.intro;
  bool get canContinue =>
      !busy &&
      switch (step) {
        OnboardingStep.childName => childName.trim().isNotEmpty,
        OnboardingStep.petName => petName.trim().isNotEmpty,
        OnboardingStep.pin || OnboardingStep.permission => false,
        _ => true,
      };
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (busy) return;
    busy = true;
    error = null;
    _changed();
    final result = await _game.context.run(
      (r) async => (
        (await r.profiles.profile())?.onboardingCompleted == true,
        (await r.parents.parentSettings()).hasPin,
      ),
    );
    if (_disposed) return;
    busy = false;
    switch (result) {
      case Success(value: final value):
        completed = value.$1;
        existingPin = value.$2;
      case Rejected():
        error = 'Не получилось открыть игру. Попробуйте ещё раз.';
    }
    _changed();
  }

  void setChildName(String value) {
    if (!busy) {
      childName = value;
      error = null;
      _changed();
    }
  }

  void setPetName(String value) {
    if (!busy) {
      petName = value;
      error = null;
      _changed();
    }
  }

  void changeSkin(int delta) {
    if (busy || step != OnboardingStep.skin) return;
    skinIndex = (skinIndex + delta) % skinIds.length;
    _changed();
  }

  void next() {
    if (!canContinue || completed == true) return;
    if (step == OnboardingStep.childReady) return;
    childName = childName.trim();
    petName = petName.trim();
    step = OnboardingStep.values[step.index + 1];
    error = null;
    _changed();
  }

  void back() {
    if (!canGoBack) return;
    parentConsent = false;
    error = null;
    step = OnboardingStep.values[step.index - 1];
    _changed();
  }

  void explainAgain() {
    if (busy || _pinAccepted) return;
    parentConsent = false;
    step = OnboardingStep.money;
    error = null;
    _changed();
  }

  void decline() {
    if (busy || _pinAccepted) return;
    parentConsent = false;
    step = OnboardingStep.parentOffer;
    error = null;
    _changed();
  }

  void consent() {
    if (busy ||
        (step != OnboardingStep.permission &&
            step != OnboardingStep.parentOffer)) {
      return;
    }
    parentConsent = true;
    step = OnboardingStep.pin;
    error = null;
    _changed();
  }

  Future<void> submitPin(String pin) async {
    if (busy || !parentConsent || step != OnboardingStep.pin) return;
    if (!RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
      error = 'Введите четыре цифры.';
      _changed();
      return;
    }
    busy = true;
    error = null;
    _changed();
    final result = await _flow.acceptPin(pin);
    if (_disposed) return;
    busy = false;
    switch (result) {
      case Success():
        _pinAccepted = true;
        step = OnboardingStep.parentReady;
      case Rejected(reason: final reason):
        error = switch (reason) {
          Failure.pinLocked => 'Слишком много попыток. Подождите 30 секунд.',
          Failure.invalidPin => 'PIN не подошёл. Попробуйте ещё раз.',
          _ => 'Не получилось сохранить PIN. Попробуйте ещё раз.',
        };
    }
    _changed();
  }

  Future<void> finish() async {
    if (busy || completed == true || step != OnboardingStep.childReady) return;
    busy = true;
    error = null;
    _changed();
    final result = await _flow.complete(
      childName: childName,
      petName: petName,
      skinId: skinId,
      parentConsent: parentConsent,
    );
    if (_disposed) return;
    busy = false;
    switch (result) {
      case Success():
        completed = true;
      case Rejected():
        error = 'Не получилось сохранить игру. Попробуй ещё раз.';
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
