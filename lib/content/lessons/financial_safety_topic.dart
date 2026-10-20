import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import 'financial_safety_lesson.dart';

/// Final design 40000215:83212 / 83381 explicitly defines two investigations.
/// The older locked card 40000220:35583 has no scenario or prototype target.
abstract final class FinancialSafetyTopic {
  static const id = FinancialSafetyLesson.topicId;
  static const title = 'Финансовая безопасность';
  static const plannedTitle = 'Мама, это ты?';
  static const plannedDescription =
      'Что делать, если кто-то выдает себя за ваших близких?';
  // Separate topic bonus explicitly approved in 40000215:83316.
  static const rewardFira = 500;
  static const rewardXp = 30;
  static List<LearningTask> requiredTasks(ContentRepository content) =>
      content.tasks
          .where(
            (t) =>
                t.themeId == id &&
                t.enabled &&
                t.rewardPolicy == RewardPolicy.oneTime,
          )
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
  static const guideTitle = 'Как защититься от мошенников';
  static const guideIntro =
      'Мяу! Мошенники хитрые, но мы хитрее. Запомни 8 правил — и обмануть тебя будет непросто!';

  /// Verbatim full guide 40000220:35612, including content below the viewport.
  static const tips = [
    (
      'Не верь угрозам по телефону',
      'Если незнакомец пугает тебя или семью, просто положи трубку.',
    ),
    (
      'Не отдавай деньги незнакомцам',
      'Даже если человек называет себя полицейским или сотрудником ФСБ.',
    ),
    (
      'Проверяй неожиданные выигрыши',
      'Не участвовал в розыгрыше? Обещанный приз — повод насторожиться.',
    ),
    (
      'Не открывай ссылки из странных писем',
      'Они ведут на поддельные сайты, где просят заплатить «сбор» за приз.',
    ),
    (
      'Береги данные карты',
      'Не вводи их на сайтах и не присылай фото карты или документов.',
    ),
    (
      'Никому не говори коды из SMS',
      'Код — как ключ: с ним мошенники могут войти в твой аккаунт.',
    ),
    (
      'Проверяй, кто тебе пишет',
      'Странная просьба от «мамы»? Позвони ей по сохранённому номеру.',
    ),
    (
      'Не поддавайся спешке',
      'Торопят, пугают или стыдят? Закончи разговор и расскажи взрослому.',
    ),
  ];
}
