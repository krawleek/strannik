import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/support_mail.dart';
import '../../core/result.dart';
import '../../domain/models/models.dart';
import '../assets/presentation_assets.dart';
import '../components/strannik_button.dart';
import '../components/strannik_pin_input.dart';
import '../components/strannik_tap_target.dart';
import '../components/strannik_speech_bubble.dart';
import '../foundation/app_tokens.dart';
import 'profile_controller.dart';

const _surface = Color(0xFFF3F5F8);
const _red = Color(0xFFEC2C2F);
TextStyle _text(
  double size, {
  Color color = AppColors.black,
  FontWeight weight = FontWeight.w700,
}) => TextStyle(
  fontFamily: AppTypography.family,
  fontSize: size,
  height: 1.2,
  fontWeight: weight,
  color: color,
);
Widget _art(String name, {double? width, double? height}) => Image.asset(
  'assets/profile/$name.png',
  width: width,
  height: height,
  fit: BoxFit.contain,
  excludeFromSemantics: true,
);
Widget _card(Widget child, {Color color = Colors.white}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(12),
  ),
  child: child,
);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onReset,
  });
  final ProfileController controller;
  final VoidCallback onBack;
  final Future<void> Function() onReset;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  ProfileController get c => widget.controller;
  String page = 'child';
  LearningTheme? theme;
  Timer? _sessionTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_refresh);
    if (c.overview == null) c.load();
    _sessionTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && page != 'child' && page != 'farewell' && !c.parent) {
        c.playtime.start();
        setState(() => page = 'child');
      }
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    c.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    c.logout();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      c.logout();
      if (mounted && page != 'farewell') setState(() => page = 'child');
    }
  }

  void back() {
    if (page == 'child') {
      widget.onBack();
      return;
    }
    setState(() {
      if (page == 'topic') {
        page = 'progress';
      } else if (page == 'reward' || page == 'success' || page == 'progress') {
        page = 'parent';
      } else {
        c.logout();
        c.playtime.start();
        page = 'child';
      }
    });
  }

  void go(String value) {
    if (c.parent) setState(() => page = value);
  }

  Future<T?> sheet<T>(Widget child) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      side: BorderSide(color: AppColors.black, width: 3),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        24,
        12,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(child: child),
    ),
  );
  Future<bool> authenticate() async {
    if (c.parent) return true;
    final result = await sheet<bool>(
      _PinSheet(controller: c, onRecovery: recovery),
    );
    if (result == true && c.parent) {
      await c.playtime.checkpoint(stop: true);
      return true;
    }
    return false;
  }

  Future<void> email({bool recovery = false}) async {
    final opened = await SupportMail().open(recovery: recovery);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Почтовое приложение не найдено. Напишите на strannik@mail.ru.',
        ),
        action: SnackBarAction(
          label: 'Скопировать',
          onPressed: () =>
              Clipboard.setData(const ClipboardData(text: 'strannik@mail.ru')),
        ),
      ),
    );
  }

  Future<void> recovery() => showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (context) => _RecoveryFlow(onMail: () => email(recovery: true)),
  );

  Future<void> rename() async {
    final name = TextEditingController(text: c.overview?.profile?.nickname);
    await sheet<void>(
      StatefulBuilder(
        builder: (context, update) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Изменить имя', style: _text(24)),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              autofocus: true,
              maxLength: 24,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Имя ребёнка',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => update(() {}),
            ),
            const SizedBox(height: 12),
            StrannikButton(
              label: 'Сохранить',
              onPressed: name.text.trim().isEmpty
                  ? null
                  : () async {
                      if (await c.perform(
                            () => c.game.profile.rename(name.text),
                          ) &&
                          context.mounted) {
                        Navigator.pop(context);
                      }
                    },
            ),
            if (c.error != null) Text(c.error!, style: _text(14, color: _red)),
          ],
        ),
      ),
    );
    // Dispose after the route's closing animation has detached the input.
    Future.delayed(const Duration(milliseconds: 350), name.dispose);
  }

  Future<void> avatar() => sheet<void>(_AvatarPicker(controller: c));

  Future<void> destructive(bool delete) async {
    if (!await authenticate() || !mounted) return;
    final token = c.token;
    final confirm = await sheet<bool>(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _card(
            Column(
              children: [
                const Icon(Icons.delete_outline, color: _red, size: 40),
                const SizedBox(height: 16),
                Text(
                  delete ? 'Удалить профиль ребёнка?' : 'Сбросить прогресс?',
                  style: _text(24),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  delete
                      ? 'Все достижения, пройденные уроки, накопленные монеты и игровой прогресс будут безвозвратно удалены. Восстановить их не получится.'
                      : 'Все достижения, пройденные уроки, накопленные монеты и игровой прогресс будут удалены. Имя ребёнка и родительский PIN сохранятся.',
                  style: _text(14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          StrannikButton(
            label: delete ? 'Удалить' : 'Сбросить',
            backgroundColor: _red,
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 10),
          StrannikButton(
            label: 'Отмена',
            backgroundColor: AppColors.blue,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) {
      if (page == 'child') {
        c.logout();
        c.playtime.start();
      }
      return;
    }
    await c.playtime.checkpoint(stop: true);
    if (await c.perform(
      () => delete ? c.game.profile.delete(token) : c.game.profile.reset(token),
    )) {
      c.logout();
      await c.notificationSettings.clear();
      if (delete && mounted) {
        setState(() => page = 'farewell');
      } else {
        await widget.onReset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final protected = page != 'child' && page != 'farewell' && !c.parent;
    final current = protected ? 'child' : page;
    final title = switch (current) {
      'parent' => 'Мамам и папам',
      'progress' => 'Прогресс',
      'topic' => theme?.title ?? 'Прогресс',
      'reward' => 'Отправить фиры',
      'success' => '',
      _ => 'Профиль',
    };
    if (current == 'farewell') {
      return _FarewellScreen(
        onExit: () async {
          await widget.onReset();
          await SystemNavigator.pop();
        },
      );
    }
    if (current == 'reward' || current == 'success') {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) back();
        },
        child: _RewardSceneLayout(
          success: current == 'success',
          onBack: back,
          error: c.error,
          child: current == 'success'
              ? success()
              : _RewardScreen(controller: c, onSuccess: () => go('success')),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: ColoredBox(
        color: current == 'child' ? AppColors.lightBlue : _surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: back,
                    tooltip: 'Назад',
                    icon: _art('back', width: 24, height: 24),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: _text(
                        24,
                        weight: FontWeight.w800,
                      ).copyWith(height: 1),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: c.overview == null
                  ? Center(
                      child: c.error == null
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: c.load,
                              child: Text(c.error!),
                            ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        current == 'child' ? 12 : 16,
                        0,
                        current == 'child' ? 12 : 16,
                        24,
                      ),
                      child: Column(
                        children: [
                          if (c.error != null)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                c.error!,
                                style: _text(14, color: _red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          switch (current) {
                            'parent' => dashboard(),
                            'progress' => progress(),
                            'topic' => topic(),
                            'reward' => _RewardScreen(
                              controller: c,
                              onSuccess: () => go('success'),
                            ),
                            'success' => success(),
                            _ => child(),
                          },
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget child() => Column(
    children: [
      const SizedBox(height: 11),
      StrannikTapTarget(
        label: 'Изменить аватарку',
        onTap: avatar,
        child: Image.asset(
          PresentationAssets.avatar(c.overview!.profile?.avatarId ?? 'girl')
              .path,
          width: 134,
          height: 114,
          fit: BoxFit.contain,
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              c.overview!.profile?.nickname ?? 'Путник',
              style: _text(32, weight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: rename,
            tooltip: 'Изменить имя',
            icon: _art('edit', width: 32, height: 32),
          ),
        ],
      ),
      const SizedBox(height: 28),
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            children: List.generate(5, (i) {
              final labels = [
                'Звуковые эффекты',
                'Музыка',
                'Вибрация',
                'Уведомления',
                'Демо-режим',
              ];
              final values = [
                c.settings.soundEnabled,
                c.settings.musicEnabled,
                c.settings.hapticsEnabled,
                c.notifications,
                c.overview!.demo,
              ];
              return Container(
                constraints: const BoxConstraints(minHeight: 60),
                decoration: BoxDecoration(
                  border: i < 4
                      ? const Border(
                          bottom: BorderSide(
                            color: AppColors.lightBlue,
                            width: 3,
                          ),
                        )
                      : null,
                ),
                child: Semantics(
                  toggled: values[i],
                  label: labels[i],
                  child: InkWell(
                    onTap: c.busy
                        ? null
                        : () async {
                            if (i == 4 && !await authenticate()) return;
                            await c.setting(i, !values[i]);
                            if (i == 4) {
                              c.logout();
                              c.playtime.start();
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14.5,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              labels[i],
                              style: _text(18, color: AppColors.ink),
                            ),
                          ),
                          Container(
                            width: 50,
                            height: 28,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: values[i]
                                    ? const Color(0xFF4CAF50)
                                    : AppColors.pink,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Align(
                                alignment: values[i]
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: AppColors.ink,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      const SizedBox(height: 20),
      StrannikButton(
        label: 'Войти как родитель',
        minimumHeight: 53,
        backgroundColor: AppColors.blue,
        onPressed: c.busy
            ? null
            : () async {
                if (await authenticate()) go('parent');
              },
        child: const _ProfileActionLabel('Войти как родитель', 'lock'),
      ),
      const SizedBox(height: 10),
      StrannikButton(
        label: 'Сбросить прогресс',
        minimumHeight: 53,
        backgroundColor: _red,
        onPressed: c.busy ? null : () => destructive(false),
        child: const _ProfileActionLabel('Сбросить прогресс', 'trash'),
      ),
    ],
  );
  Widget dashboard() => Column(
    children: [
      const SizedBox(height: 16),
      _card(
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.overview!.profile?.nickname ?? '',
                    style: _text(32, weight: FontWeight.w800),
                  ),
                  Text(
                    'уровень ${(c.overview!.pet?.currentStage.index ?? 0) + 1}',
                    style: _text(14, color: AppColors.gray),
                  ),
                ],
              ),
            ),
            _art('parent_pair', width: 145, height: 65),
          ],
        ),
      ),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => go('progress'),
        child: _card(
          Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Прогресс ›', style: _text(20)),
                  const SizedBox(height: 4),
                  Text(
                    'Пройдено ${c.overview!.completedThemes.length}/${c.game.context.content.themes.length} тем',
                    style: _text(14, color: AppColors.gray),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: c.game.context.content.themes.isEmpty
                          ? 0
                          : c.overview!.completedThemes.length /
                                c.game.context.content.themes.length,
                      minHeight: 12,
                      color: const Color(0xFF315B7C),
                      backgroundColor: const Color(0xFFF5F5F5),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: _art('progress_book', width: 100, height: 84),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${c.playtime.averageMinutes(c.week).round()} мин ◷',
              style: _text(24),
            ),
            Text(
              'среднее время в игре',
              style: _text(14, color: AppColors.gray),
            ),
            const SizedBox(height: 16),
            _WeeklyChart(week: c.week),
          ],
        ),
      ),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => sheet<void>(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Есть вопросы или идеи?', style: _text(24)),
              const SizedBox(height: 12),
              Text(
                'Будем рады вашим предложениям! Напишите нам на strannik@mail.ru',
                style: _text(14),
              ),
              const SizedBox(height: 20),
              StrannikButton(
                label: 'Написать письмо',
                backgroundColor: AppColors.blue,
                onPressed: email,
              ),
            ],
          ),
        ),
        child: _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Есть вопросы или идеи?', style: _text(20)),
              const SizedBox(height: 4),
              Text(
                'Будем рады вашим предложениям!\nНапишите нам на strannik@mail.ru',
                style: _text(14),
              ),
              SizedBox(
                height: 68,
                child: Stack(
                  children: [
                    Positioned(
                      left: 55,
                      bottom: 0,
                      child: _art('letter_back', width: 130, height: 60),
                    ),
                    Positioned(
                      right: -16,
                      bottom: -10,
                      child: _art('letter_front', width: 135, height: 85),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      StrannikButton(
        label: 'Удалить аккаунт',
        backgroundColor: _red,
        onPressed: c.busy ? null : () => destructive(true),
      ),
    ],
  );
  Widget progress() => Column(
    children: [
      const SizedBox(height: 16),
      _card(
        Column(
          children: [
            Row(
              children: [
                Image.asset(
                  PresentationAssets.petAvatar,
                  width: 66,
                  height: 66,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Наградить ребёнка', style: _text(18)),
                      Text(
                        'Подарите фиры для новых приключений!',
                        style: _text(12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StrannikButton(
              label: 'Отправить игровую валюту',
              onPressed: () => go('reward'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      ...c.game.context.content.themes.map((t) {
        final completed = c.overview!.completedThemes.contains(t.id);
        final started = c.game.context.content.tasks
            .where((a) => a.themeId == t.id)
            .any((a) => c.overview!.startedTasks.contains(a.id));
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              theme = t;
              go('topic');
            },
            child: _card(
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: completed
                          ? AppColors.green
                          : started
                          ? AppColors.lightOrange
                          : AppColors.gray,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${t.order}',
                      style: _text(18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: _text(16)),
                        Text(
                          completed
                              ? '● Пройдено'
                              : started
                              ? '● В процессе'
                              : '● Не начато',
                          style: _text(
                            12,
                            color: completed
                                ? AppColors.green
                                : started
                                ? AppColors.darkOrange
                                : AppColors.gray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              color: started && !completed ? AppColors.yellow : Colors.white,
            ),
          ),
        );
      }),
    ],
  );
  Widget topic() {
    final tasks = c.game.context.content.tasks
        .where((t) => t.enabled && t.themeId == theme!.id)
        .toList();
    return Column(
      children: [
        const SizedBox(height: 16),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Тема ${theme!.order}',
                style: _text(14, color: AppColors.green),
              ),
              const SizedBox(height: 16),
              Text(theme!.title, style: _text(24)),
              const SizedBox(height: 16),
              ...tasks.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        c.overview!.completedTasks.contains(t.id)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: c.overview!.completedTasks.contains(t.id)
                            ? AppColors.green
                            : AppColors.gray,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.title, style: _text(14))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          color: const Color(0xFFE9FFF5),
        ),
        const SizedBox(height: 16),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Обсудите с ребенком', style: _text(20)),
              const SizedBox(height: 8),
              Text(
                'Вопросы, которые помогут закрепить знания',
                style: _text(14),
              ),
              const SizedBox(height: 12),
              Text(
                'Что делать, если денег не хватает на всё?\nКак отличить нужную покупку от желанной?\nПочему полезно откладывать часть денег?',
                style: _text(14),
              ),
            ],
          ),
          color: AppColors.lightBlue,
        ),
        const SizedBox(height: 16),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Спланируйте поход в магазин', style: _text(20)),
              const SizedBox(height: 8),
              Text(
                '1. Вместе определите бюджет и список нужных товаров.\n2. Предложите ребёнку решить, на что можно потратить сдачу.',
                style: _text(14),
              ),
            ],
          ),
          color: AppColors.pink,
        ),
      ],
    );
  }

  Widget success() => Column(
    children: [
      _card(
        Column(
          children: [
            const Icon(Icons.check_circle, color: AppColors.green, size: 52),
            const SizedBox(height: 16),
            Text('Подарок отправлен!', style: _text(24)),
            const SizedBox(height: 8),
            Text(
              'Вы подарили ребёнку больше возможностей для новых приключений!',
              style: _text(14, color: AppColors.gray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      StrannikButton(
        label: 'Назад к темам',
        backgroundColor: AppColors.darkOrange,
        onPressed: () => go('progress'),
      ),
    ],
  );
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.controller, required this.onRecovery});
  final ProfileController controller;
  final Future<void> Function() onRecovery;
  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final input = TextEditingController(), focus = FocusNode();
  bool busy = false, locked = false;
  String? error;
  @override
  void dispose() {
    input.clear();
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _card(
        Column(
          children: [
            Text('Введите PIN-код', style: _text(24)),
            const SizedBox(height: 8),
            Text(
              error ?? 'Хотим убедиться, что вы взрослый',
              style: _text(14, color: error == null ? AppColors.ink : _red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            StrannikPinInput(
              controller: input,
              focusNode: focus,
              onChanged: (_) => setState(() {}),
              enabled: !busy && !locked,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      StrannikButton(
        label: busy ? 'Проверяем…' : 'Отправить',
        backgroundColor: AppColors.blue,
        onPressed: busy || locked || input.text.length != 4
            ? null
            : () async {
                setState(() => busy = true);
                final result = await widget.controller.game.parentAccess
                    .authenticate(input.text);
                input.clear();
                if (!context.mounted) return;
                if (result is Success<void>) {
                  Navigator.pop(context, true);
                  return;
                }
                final reason = (result as Rejected<void>).reason;
                setState(() {
                  busy = false;
                  locked = reason == Failure.pinLocked;
                  error = locked
                      ? 'Три неверных попытки. Повторите через 5 минут.'
                      : reason == Failure.invalidPin
                      ? 'Неверный код! Попробуйте снова'
                      : 'Не получилось войти. Попробуйте ещё раз.';
                });
                if (locked) {
                  focus.unfocus();
                  Navigator.pop(context, false);
                  await widget.onRecovery();
                }
              },
      ),
      TextButton(
        onPressed: busy
            ? null
            : () async {
                Navigator.pop(context, false);
                await widget.onRecovery();
              },
        child: const Text('Забыли PIN-код?'),
      ),
    ],
  );
}

class _RecoveryQuestion extends StatefulWidget {
  const _RecoveryQuestion({required this.onAnswer});
  final Future<void> Function(bool) onAnswer;
  @override
  State<_RecoveryQuestion> createState() => _RecoveryQuestionState();
}

class _RecoveryQuestionState extends State<_RecoveryQuestion> {
  int? selected;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _card(
        Column(
          children: [
            const Icon(Icons.help, color: AppColors.blue, size: 44),
            const SizedBox(height: 16),
            Text(
              'Что такое инфляция?',
              style: _text(24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Вы ввели неверный PIN три раза. Для восстановления доступа потребуется помощь поддержки.',
              style: _text(14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...[
              'Рост цен на товары и услуги',
              'Повышение курса валют',
              'Увеличение зарплат',
            ].asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => selected = e.key),
                  child: _card(
                    Row(
                      children: [
                        Text('${e.key + 1}', style: _text(18)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(e.value, style: _text(14))),
                      ],
                    ),
                    color: selected == e.key
                        ? const Color(0xFFE9FFF5)
                        : _surface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      StrannikButton(
        label: 'Выбрать',
        onPressed: selected == null
            ? null
            : () => widget.onAnswer(selected == 0),
      ),
    ],
  );
}

class _RewardScreen extends StatefulWidget {
  const _RewardScreen({required this.controller, required this.onSuccess});
  final ProfileController controller;
  final VoidCallback onSuccess;
  @override
  State<_RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<_RewardScreen> {
  final amount = TextEditingController();
  late final String key = widget.controller.game.context.ids.next();
  bool busy = false;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = int.tryParse(amount.text);
    return Column(
      children: [
        _card(
          Column(
            children: [
              Text('Отправить фиры', style: _text(24)),
              const SizedBox(height: 8),
              Text(
                'Фиры — игровая валюта, не настоящие деньги',
                style: _text(14, color: AppColors.gray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amount,
                enabled: !busy,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Количество фир',
                  suffixText: '₣',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [50, 100, 200, 500]
                    .map(
                      (n) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.yellow,
                              foregroundColor: AppColors.darkOrange,
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: busy
                                ? null
                                : () {
                                    amount.text = '$n';
                                    setState(() {});
                                  },
                            child: Text(
                              '$n',
                              style: _text(14, color: AppColors.darkOrange),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StrannikButton(
          label: busy ? 'Отправляем…' : 'Отправить ${value ?? 0} ₣',
          backgroundColor: AppColors.darkOrange,
          onPressed: busy || value == null || value <= 0
              ? null
              : () async {
                  setState(() => busy = true);
                  final ok = await widget.controller.reward(value, key);
                  if (!mounted) return;
                  if (ok) {
                    widget.onSuccess();
                  } else {
                    setState(() => busy = false);
                  }
                },
        ),
      ],
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.week});
  final List<Duration> week;
  @override
  Widget build(BuildContext context) {
    final max = math.max(
      60.0,
      week.map((d) => d.inSeconds / 60).fold<double>(0, math.max),
    );
    return SizedBox(
      height: 124,
      child: Stack(
        children: [
          Positioned.fill(
            bottom: 24,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                3,
                (i) => Row(
                  children: [
                    const Expanded(
                      child: Divider(height: 1, color: Color(0xFFE7E7E7)),
                    ),
                    SizedBox(
                      width: 25,
                      child: Text(
                        '${(max * (2 - i) / 2).round()}',
                        style: _text(10, color: AppColors.gray),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 26),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                7,
                (i) => Expanded(
                  child: Semantics(
                    label:
                        '${['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][i]}: ${week[i].inMinutes} минут',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 27,
                          height: week[i].inMilliseconds == 0
                              ? 0
                              : math.max(2, 88 * week[i].inSeconds / 60 / max),
                          decoration: BoxDecoration(
                            color: AppColors.lightOrange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][i],
                          style: _text(10, color: AppColors.gray),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (week.every((d) => d == Duration.zero))
            Center(
              child: Text(
                'Пока нет данных',
                style: _text(14, color: AppColors.gray),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileActionLabel extends StatelessWidget {
  const _ProfileActionLabel(this.label, this.icon);
  final String label;
  final String icon;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _art(icon, width: icon == 'lock' ? 18 : 25, height: 24),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          label,
          style: AppTypography.button,
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );
}

class _AvatarPicker extends StatefulWidget {
  const _AvatarPicker({required this.controller});
  final ProfileController controller;
  @override
  State<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<_AvatarPicker> {
  static const ids = ['boy', 'girl'];
  late int selected = widget.controller.overview?.profile?.avatarId == 'boy'
      ? 0
      : 1;
  late final pager = PageController(
    viewportFraction: .48,
    initialPage: 5000 + selected,
  );
  @override
  void dispose() {
    pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text('Изменить аватарку', style: _text(24)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 150,
                  child: PageView.builder(
                    controller: pager,
                    onPageChanged: (index) =>
                        setState(() => selected = index % ids.length),
                    itemBuilder: (context, index) {
                      final avatar = index % ids.length,
                          active = selected == avatar;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Semantics(
                          label: avatar == 1 ? 'Девочка' : 'Мальчик',
                          selected: active,
                          child: StrannikTapTarget(
                            label: avatar == 1
                                ? 'Выбрать девочку'
                                : 'Выбрать мальчика',
                            selected: active,
                            onTap: widget.controller.busy
                                ? null
                                : () => pager.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                  ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFFFFD9B3)
                                    : const Color(0xFFE9FFF5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  width: 5,
                                  color: active
                                      ? const Color(0xFFFFB981)
                                      : const Color(0xFFA7E9C5),
                                ),
                              ),
                              child: Opacity(
                                opacity: active ? 1 : .22,
                                child: Image.asset(
                                  PresentationAssets.avatar(ids[avatar]).path,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    ids.length,
                    (i) => Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == selected ? AppColors.blue : AppColors.gray,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.controller.error != null)
          Text(widget.controller.error!, style: _text(14, color: _red)),
        StrannikButton(
          label: widget.controller.busy ? 'Сохраняем…' : 'Сохранить',
          onPressed: widget.controller.busy
              ? null
              : () async {
                  final result = await widget.controller.perform(
                    () => widget.controller.game.profile.avatar(ids[selected]),
                  );
                  if (result && context.mounted) Navigator.pop(context);
                },
        ),
      ],
    ),
  );
}

class _RewardSceneLayout extends StatelessWidget {
  const _RewardSceneLayout({
    required this.success,
    required this.onBack,
    required this.child,
    this.error,
  });
  final bool success;
  final VoidCallback onBack;
  final Widget child;
  final String? error;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.yellow,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final top = MediaQuery.viewPaddingOf(context).top;
        final designHeight = success ? 493.0 : 429.0;
        final artworkHeight = (constraints.maxWidth * designHeight / 360 - top)
            .clamp(200.0, 520.0);
        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: artworkHeight,
                width: double.infinity,
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned(
                        top: -top,
                        left: 0,
                        right: 0,
                        child: Image.asset(
                          'assets/profile/${success ? 'success_scene' : 'reward_scene'}.png',
                          fit: BoxFit.fitWidth,
                          excludeFromSemantics: true,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 4,
                        child: IconButton(
                          onPressed: onBack,
                          tooltip: 'Назад',
                          icon: _art('back', width: 24, height: 24),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  border: Border(
                    top: BorderSide(color: AppColors.black, width: 3),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
                child: Column(
                  children: [
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(error!, style: _text(14, color: _red)),
                      ),
                    child,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _RecoveryFlow extends StatefulWidget {
  const _RecoveryFlow({required this.onMail});
  final VoidCallback onMail;
  @override
  State<_RecoveryFlow> createState() => _RecoveryFlowState();
}

class _RecoveryFlowState extends State<_RecoveryFlow> {
  bool answered = false;
  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: AppColors.lightBlue,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/profile/recovery_scene.png',
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      decoration: const BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Закрыть',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          if (!answered)
                            _RecoveryQuestion(
                              onAnswer: (correct) async =>
                                  setState(() => answered = true),
                            )
                          else ...[
                            _card(
                              Column(
                                children: [
                                  const Icon(
                                    Icons.error,
                                    color: _red,
                                    size: 44,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Не получилось войти',
                                    style: _text(24),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Если вы родитель и забыли PIN-код, свяжитесь с нами по почте strannik@mail.ru. Мы поможем восстановить доступ.',
                                    style: _text(14),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            StrannikButton(
                              label: 'Написать письмо',
                              backgroundColor: AppColors.blue,
                              onPressed: widget.onMail,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _FarewellScreen extends StatelessWidget {
  const _FarewellScreen({required this.onExit});
  final Future<void> Function() onExit;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) onExit();
    },
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/onboarding/street_background.png',
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    StrannikSpeechBubble(
                      name: 'Веня',
                      child: Text(
                        'Мяу! Был рад познакомиться! Если захотите поговорить, пишите на почту strannik@mail.ru',
                        style: _text(14),
                      ),
                    ),
                    Image.asset(
                      'assets/profile/farewell_cat.png',
                      height: 190,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(height: 24),
                    StrannikButton(
                      label: 'Выйти из приложения',
                      backgroundColor: AppColors.lightBlue,
                      foregroundColor: AppColors.blue,
                      onPressed: onExit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
