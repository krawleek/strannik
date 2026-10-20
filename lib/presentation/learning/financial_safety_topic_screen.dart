import 'package:flutter/material.dart';

import '../../content/lessons/financial_safety_topic.dart';
import '../../domain/models/models.dart';
import '../components/strannik_button.dart';
import '../foundation/app_tokens.dart';
import 'financial_safety_screen.dart';
import 'learning_screen.dart';

class FinancialSafetyGuide extends StatelessWidget {
  const FinancialSafetyGuide({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFE8DEF8),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const SafetyLessonBackground(tint: Color(0xFFCFBDEF)),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        FinancialSafetyTopic.guideTitle,
                        style: AppTypography.heading.copyWith(
                          fontSize: 28,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть справку',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppColors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const SafetySpeechBubble(
                  text: FinancialSafetyTopic.guideIntro,
                  artwork: 'assets/learning/safety_guide_bubble.png',
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < FinancialSafetyTopic.tips.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: i.isEven ? AppColors.white : AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${i + 1}',
                            textAlign: TextAlign.center,
                            style: AppTypography.badge.copyWith(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                FinancialSafetyTopic.tips[i].$1,
                                style: AppTypography.badge.copyWith(
                                  color: AppColors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                FinancialSafetyTopic.tips[i].$2,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                StrannikButton(
                  backgroundColor: AppColors.blue,
                  label: 'Вернуться к теме',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class FinancialSafetyFinale extends StatelessWidget {
  const FinancialSafetyFinale({
    super.key,
    required this.progress,
    required this.xp,
    required this.busy,
    required this.onNext,
    required this.onClose,
    this.error,
  });
  final LearningTopicProgress progress;
  final int xp;
  final bool busy;
  final VoidCallback onNext, onClose;
  final String? error;
  @override
  Widget build(BuildContext context) {
    final story = progress.finaleStep > 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) onClose();
      },
      child: Scaffold(
        backgroundColor: AppColors.yellow,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'К карте заданий',
                    onPressed: busy ? null : onClose,
                    icon: const Icon(
                      Icons.chevron_left,
                      color: AppColors.black,
                    ),
                  ),
                ),
                Text(
                  FinancialSafetyTopic.title,
                  style: AppTypography.body.copyWith(color: AppColors.blue),
                ),
                const SizedBox(height: 16),
                if (story) ...[
                  const Text(
                    'Странник становится детективом',
                    style: AppTypography.heading,
                  ),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 328 / 370,
                    child: lessonArt('safety_detective'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Под подозрением… обычная игрушка!',
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: lessonArt('safety_story_cat', width: 64, height: 70),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(width: 2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      'Мяу! Кажется, я стал настоящим детективом! Теперь меня не так просто обмануть. А если что-то покажется подозрительным — я обязательно обращусь за помощью!',
                      style: AppTypography.body,
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    height: 230,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 15,
                          top: 30,
                          child: lessonArt(
                            'safety_celebration_star',
                            width: 46,
                            height: 45,
                          ),
                        ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: lessonArt(
                            'safety_finale_cat',
                            width: 160,
                            height: 203,
                          ),
                        ),
                        Positioned(
                          right: 22,
                          top: 130,
                          child: lessonArt(
                            'safety_celebration_star',
                            width: 40,
                            height: 40,
                          ),
                        ),
                        Positioned(
                          right: 52,
                          top: 20,
                          child: Text(
                            '!',
                            style: AppTypography.heading.copyWith(
                              fontSize: 38,
                              color: AppColors.darkOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Ура! Тема пройдена!',
                    style: AppTypography.heading,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Теперь ты умеешь замечать подозрительные звонки, распознавать обман в интернете и защищать свои деньги и аккаунты',
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Отдельная награда за тему',
                    style: AppTypography.counter,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _reward(
                        '+${FinancialSafetyTopic.rewardXp} XP',
                        AppColors.lightOrange,
                      ),
                      _reward(
                        '+${FinancialSafetyTopic.rewardFira} фир',
                        AppColors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Награда за тему получена один раз',
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFEFA),
                      border: Border.all(width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Странник растёт вместе с тобой',
                          style: AppTypography.counter,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Стадия 3 · Родная планета',
                          style: AppTypography.body,
                        ),
                        const SizedBox(height: 12),
                        Text('$xp XP', style: AppTypography.counter),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (error != null) Text(error!, style: AppTypography.body),
                StrannikButton(
                  backgroundColor: AppColors.blue,
                  label: busy
                      ? 'Сохраняем…'
                      : story
                      ? 'Продолжить приключение'
                      : 'К Страннику',
                  onPressed: busy ? null : onNext,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reward(String text, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: AppTypography.counter),
  );
}
