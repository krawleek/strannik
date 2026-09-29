import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/strannik_button.dart';
import '../components/strannik_name_input.dart';
import '../components/strannik_pin_input.dart';
import '../components/strannik_speech_bubble.dart';
import '../components/strannik_tap_target.dart';
import '../foundation/app_tokens.dart';
import 'onboarding_assets.dart';
import 'onboarding_controller.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.controller});
  final OnboardingController controller;
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final TextEditingController _child = TextEditingController(
    text: c.childName,
  );
  late final TextEditingController _pet = TextEditingController(
    text: c.petName,
  );
  final _pin = TextEditingController();
  final _pinFocus = FocusNode();
  OnboardingController get c => widget.controller;
  @override
  void dispose() {
    _child.dispose();
    _pet.dispose();
    _pin.clear();
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    c.next();
  }

  Future<void> _savePin() async {
    FocusScope.of(context).unfocus();
    final pin = _pin.text;
    _pin.clear();
    await c.submitPin(pin);
  }

  Widget _art(
    String name, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) => Image.asset(
    OnboardingAssets.image(name),
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.high,
    excludeFromSemantics: true,
  );
  Widget _button(
    String text,
    VoidCallback? onTap, {
    Color color = AppColors.blue,
    Color textColor = AppColors.white,
    Widget? child,
  }) => StrannikButton(
    label: text,
    onPressed: c.busy ? null : onTap,
    backgroundColor: color,
    foregroundColor: textColor,
    child: child,
  );
  Widget _bubble(String text, {String? name}) => StrannikSpeechBubble(
    name:
        name ??
        (c.step.index < OnboardingStep.askParents.index
            ? 'Странник'
            : c.petName),
    compact: true,
    child: Text(text, style: AppTypography.body),
  );

  String? get _background => switch (c.step) {
    OnboardingStep.intro => 'intro_background',
    OnboardingStep.beam || OnboardingStep.arrival => 'beam_background',
    OnboardingStep.street => 'street_background',
    OnboardingStep.childName ||
    OnboardingStep.help ||
    OnboardingStep.disguise ||
    OnboardingStep.petName ||
    OnboardingStep.askParents => 'street_close',
    OnboardingStep.skin => 'skin_background',
    OnboardingStep.doorstep => 'house_door',
    OnboardingStep.parentVoice ||
    OnboardingStep.petPersuades ||
    OnboardingStep.handoff ||
    OnboardingStep.parentHello ||
    OnboardingStep.parentOffer ||
    OnboardingStep.permission ||
    OnboardingStep.childReady => 'room_door',
    _ => null,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final isDark = c.step != OnboardingStep.skin;
      final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
      return PopScope(
        canPop: c.step == OnboardingStep.intro && !c.busy,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) c.back();
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
          child: Scaffold(
            backgroundColor: AppColors.blue,
            resizeToAvoidBottomInset: true,
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (_background != null) _art(_background!, fit: BoxFit.cover),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final height = constraints.maxHeight;
                      final content = switch (c.step) {
                        OnboardingStep.intro ||
                        OnboardingStep.beam ||
                        OnboardingStep.arrival ||
                        OnboardingStep.street => _story(height),
                        OnboardingStep.skin => _skin(height),
                        OnboardingStep.money ||
                        OnboardingStep.care ||
                        OnboardingStep.results => _explanation(height),
                        OnboardingStep.handoff ||
                        OnboardingStep.pin ||
                        OnboardingStep.parentReady => _parentPanel(
                          height,
                          keyboard,
                        ),
                        _ => _dialogue(height, keyboard),
                      };
                      return content;
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

  Widget _scroll(double height, Widget child) => SingleChildScrollView(
    key: ValueKey(c.step),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: child,
    ),
  );

  Widget _story(double height) => Semantics(
    label: c.step == OnboardingStep.intro
        ? 'Странник. Твоё первое путешествие в мир денег. Продолжить'
        : 'Странник прилетел на Землю. Продолжить',
    button: true,
    onTap: _next,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _next,
      child: SizedBox.expand(
        child: Stack(
          children: [
            if (c.step == OnboardingStep.intro) ...[
              Align(
                alignment: const Alignment(0, -.3),
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B2B23),
                    border: Border.all(color: AppColors.black, width: 8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Странник',
                        style: AppTypography.heading.copyWith(
                          fontSize: 36,
                          color: AppColors.white,
                        ),
                      ),
                      Text(
                        'твое первое путешествие\nв мир денег',
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: height * .47,
                bottom: -24,
                child: _art('falling_cat', fit: BoxFit.contain),
              ),
            ],
            if (c.step == OnboardingStep.arrival ||
                c.step == OnboardingStep.street)
              Positioned(
                left: 69,
                bottom: 32,
                width: 150,
                height: 134,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(c.step),
                  tween: Tween(begin: 0, end: 1),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 450),
                  builder: (_, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: _art('alien', fit: BoxFit.cover),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _skin(double height) => _scroll(
    height,
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(
        children: [
          SizedBox(height: math.max(24, height * .16)),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 22),
              child: SizedBox(
                width: 246,
                child: _bubble(
                  const [
                    'Хмм... Серый выглядит очень элегантно!',
                    'Рыжий с сумасшедшинкой! Мне подходит!',
                    'Я похож на то, что вы зовете мягким хлебушком.. Класс!',
                  ][c.skinIndex],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 323,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Semantics(
                  label:
                      'Маскировка: ${const ['серый кот', 'рыжий кот', 'кот цвета хлебушка'][c.skinIndex]}',
                  image: true,
                  child: _skinArt(360),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 68,
                      height: 56,
                      child: _button(
                        'Предыдущая маскировка',
                        () => c.changeSkin(-1),
                        color: const Color(0xFFEDEDED),
                        child: _art('chevron', width: 20, height: 24),
                      ),
                    ),
                    SizedBox(
                      width: 68,
                      height: 56,
                      child: _button(
                        'Следующая маскировка',
                        () => c.changeSkin(1),
                        color: const Color(0xFFEDEDED),
                        child: Transform.flip(
                          flipX: true,
                          child: _art('chevron', width: 20, height: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: math.max(24, height - height * .16 - 323 - 124 - 84),
          ),
          _button('Круто, давай!', _next),
        ],
      ),
    ),
  );

  Widget _skinArt(double width) => SizedBox(
    width: width,
    height: width * 322 / 360,
    child: Image.asset(
      OnboardingAssets.skin(c.skinId),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    ),
  );

  Widget _dialogue(double height, bool keyboard) {
    final step = c.step;
    final input =
        step == OnboardingStep.childName || step == OnboardingStep.petName;
    final parent = step.index >= OnboardingStep.parentHello.index;
    final text = switch (step) {
      OnboardingStep.childName => 'Привет! Не пугайся, я всего лишь прилетел с другой планеты.\nЯ XÆLiQЫ, а как зовут тебя?',
      OnboardingStep.help => 'Рад встрече! Извини, что так сразу прошу... мне нужна помощь.\nМоя тарелка сломалась и один я ее не починю. Поможешь?',
      OnboardingStep.disguise => 'Я притворюсь обычным котом и никто не заметит, что я с другой планеты. Поможешь выбрать маскировку?',
      OnboardingStep.petName => 'Отлично! Мне нравится как я выгляжу. Теперь тебе осталось только дать мне земное имя',
      OnboardingStep.askParents => 'Ты придумал отличное имя! Теперь давай узнаем, что думают родители о новом питомце...',
      OnboardingStep.doorstep => 'Мы пришли... я пойду спрошу у родителей можно ли тебе остаться с нами!',
      OnboardingStep.parentVoice => 'Кот? Уличный?..\nНу вот только кота нам не хватало. Ладно, покажи, что там за кот',
      OnboardingStep.petPersuades => 'Моя очередь убеждать!\nНе переживай, я их совершенно очарую своей милой мордахой',
      OnboardingStep.parentHello =>
        'Привет! Я кот ${c.petName}. А вы ведь родитель ${c.childName}, верно?',
      OnboardingStep.parentOffer || OnboardingStep.permission => 'Мне нужен дом, и я могу кое-чем помочь вам взамен! Я знаю все про деньги и научу вашего ребенка обращаться с ними. Ок?',
      OnboardingStep.childReady =>
        'Ура! Мне разрешили остаться!\nПокажешь свою комнату?',
      _ => '',
    };
    final isDoor = step == OnboardingStep.doorstep;
    final top = keyboard
        ? 12.0
        : isDoor
        ? height * .68
        : parent
        ? height *
              (step == OnboardingStep.permission ||
                      step == OnboardingStep.parentOffer
                  ? .22
                  : .36)
        : height * .20;
    return _scroll(
      height,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: Column(
          children: [
            SizedBox(height: top),
            if (!(input && keyboard))
              SizedBox(
                width: isDoor ? 328 : 270,
                child: _bubble(
                  text,
                  name: isDoor
                      ? c.childName
                      : step == OnboardingStep.parentVoice
                      ? 'Родитель'
                      : null,
                ),
              ),
            if (!isDoor && !keyboard)
              SizedBox(
                height: parent ? 230 : 247,
                child: step.index < OnboardingStep.petName.index
                    ? _art('alien', width: 275, height: 247, fit: BoxFit.cover)
                    : step == OnboardingStep.parentVoice
                    ? _art(
                        'cat_back',
                        width: 300,
                        height: 247,
                        fit: BoxFit.cover,
                      )
                    : _skinArt(275),
              ),
            if (input) ...[
              const SizedBox(height: 8),
              Text(
                step == OnboardingStep.childName
                    ? 'Напиши свое имя'
                    : 'Как назовешь котика?',
                textAlign: TextAlign.center,
                style: AppTypography.heading.copyWith(
                  color: AppColors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 28),
              Semantics(
                label: step == OnboardingStep.childName
                    ? 'Имя ребёнка'
                    : 'Имя питомца',
                child: StrannikNameInput(
                  key: ValueKey(step),
                  controller: step == OnboardingStep.childName ? _child : _pet,
                  label: step == OnboardingStep.childName
                      ? 'Имя ребёнка'
                      : 'Имя питомца',
                  hint: step == OnboardingStep.childName
                      ? 'Имя, ник, прозвище'
                      : 'Напиши имя',
                  onChanged: step == OnboardingStep.childName
                      ? c.setChildName
                      : c.setPetName,
                  onSubmitted: (_) {
                    if (c.canContinue) _next();
                  },
                ),
              ),
              const SizedBox(height: 13),
              _button(
                'Отправить',
                c.canContinue ? _next : null,
                color: AppColors.green,
              ),
            ] else ...[
              const SizedBox(height: 24),
              if (step == OnboardingStep.help) ...[
                _button('Конечно! Что нужно делать?', _next),
                const SizedBox(height: 11),
                _button(
                  'Но... что сказать взрослым?',
                  _next,
                  color: AppColors.lightBlue,
                  textColor: AppColors.blue,
                ),
              ] else if (step == OnboardingStep.parentOffer ||
                  step == OnboardingStep.permission) ...[
                _button(
                  step == OnboardingStep.parentOffer
                      ? 'Расскажи подробнее'
                      : 'Ещё раз об игре',
                  c.explainAgain,
                  color: AppColors.lightBlue,
                  textColor: AppColors.blue,
                ),
                const SizedBox(height: 11),
                _button(
                  'Хорошо, оставайся',
                  c.consent,
                  color: const Color(0xFFEDEDED),
                  textColor: AppColors.blue,
                ),
                if (step == OnboardingStep.permission)
                  StrannikTapTarget(
                    label: 'Пока не разрешаю',
                    onTap: c.decline,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Пока не разрешаю',
                        style: TextStyle(color: AppColors.white),
                      ),
                    ),
                  ),
              ] else
                _button(
                  switch (step) {
                    OnboardingStep.disguise => 'Круто, давай!',
                    OnboardingStep.askParents => 'Они точно согласятся!',
                    OnboardingStep.doorstep => 'Идем просить',
                    OnboardingStep.parentHello => 'Да, я родитель',
                    OnboardingStep.childReady =>
                      c.busy ? 'Сохраняем…' : 'Идем, я все покажу!',
                    _ => 'Далее',
                  },
                  step == OnboardingStep.childReady ? c.finish : _next,
                  color: parent ? const Color(0xFFEDEDED) : AppColors.blue,
                  textColor: parent ? AppColors.blue : AppColors.white,
                ),
            ],
            if (c.error != null) _error(),
          ],
        ),
      ),
    );
  }

  Widget _error() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Semantics(
      liveRegion: true,
      child: Text(
        c.error!,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(color: AppColors.white),
      ),
    ),
  );

  Widget _explanation(double height) {
    final index = c.step.index - OnboardingStep.money.index;
    final title = const [
      'Управлять деньгами',
      'Заботиться обо мне',
      'Результаты заметны сразу',
    ][index];
    final body = const [
      'Научится планировать бюджет, отличать необходимое от желаемого, копить и безопасно совершать покупки в игровой валюте',
      'Все знания сразу пригодятся в игре: ребёнок будет распределять фиры на нужды, желания и общую цель, и видеть последствия своих решений',
      'В родительском разделе можно следить за освоенными темами и отправлять игровые фиры за успехи. Вы сможете следить за прогрессом',
    ][index];
    return _scroll(
      height,
      Column(
        children: [
          SizedBox(
            height: math.min(420, height * .54),
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _art(
                  const [
                    'parent_money',
                    'parent_care_backdrop',
                    'parent_results',
                  ][index],
                  fit: BoxFit.fill,
                ),
                if (index == 1)
                  Align(
                    alignment: Alignment.center,
                    child: _art('parent_care_cat', width: 254, height: 288),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              children: [
                Text(
                  'Что будет делать\nребёнок?',
                  textAlign: TextAlign.center,
                  style: AppTypography.heading.copyWith(
                    color: AppColors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.badge,
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: 20),
                Semantics(
                  label: 'Объяснение для родителя: ${index + 1} из 3',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == index ? AppColors.white : AppColors.gray,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                _button('Далее', _next),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _parentPanel(double height, bool keyboard) {
    final pin = c.step == OnboardingStep.pin;
    final ready = c.step == OnboardingStep.parentReady;
    final title = pin
        ? (c.existingPin ? 'Введите ваш PIN-код' : 'Придумайте PIN-код')
        : ready
        ? 'Теперь всё готово'
        : 'Теперь нужен\nвзрослый';
    final body = pin
        ? (c.existingPin
              ? 'PIN уже создан. Подтвердите его, чтобы продолжить знакомство.'
              : 'Он защитит раздел, в котором можно смотреть прогресс и управлять профилем')
        : ready
        ? 'Если захотите посмотреть, как идут дела, откройте профиль ребёнка, там есть раздел «Для родителей».'
        : 'Передай телефон родителю — ${c.petName} расскажет о себе и о том, чем он сможет быть полезен в обмен на помощь с починкой корабля';
    return _scroll(
      height,
      SizedBox(
        height: keyboard ? math.max(height, 410) : math.max(height, 680),
        child: Stack(
          children: [
            if (pin && !keyboard)
              Positioned(
                left: -165,
                right: -220,
                bottom: -90,
                height: 669,
                child: _art('pin_cat', fit: BoxFit.fill),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 28),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7E7E7),
                  border: Border.all(color: AppColors.black, width: 6),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!pin && !ready) ...[
                            _art('info', width: 46, height: 42),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: AppTypography.heading.copyWith(
                              color: AppColors.black,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: AppTypography.body,
                          ),
                          if (pin) ...[
                            const SizedBox(height: 28),
                            StrannikPinInput(
                              controller: _pin,
                              focusNode: _pinFocus,
                              enabled: !c.busy,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                          if (ready) ...[
                            const SizedBox(height: 24),
                            _art('parent_ready', width: 310, height: 135),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _button(
                      pin
                          ? (c.busy ? 'Сохраняем…' : 'Сохранить')
                          : ready
                          ? 'Передать телефон ребёнку'
                          : 'Передать телефон родителю',
                      pin ? (_pin.text.length == 4 ? _savePin : null) : _next,
                      color: pin ? AppColors.green : AppColors.blue,
                    ),
                    if (c.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            c.error!,
                            textAlign: TextAlign.center,
                            style: AppTypography.body,
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
  }
}
