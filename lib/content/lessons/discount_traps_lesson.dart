/// Approved source: Figma 40000220:30088 (prototype, supplied by the user).
/// All amounts below are illustrations, never real purchases.
abstract final class DiscountTrapsLesson {
  static const taskId = 'space_theme1_task2';
  static const topicId = 'space_theme1';
  static const reference = 'discount_traps_v1';
  static const rulesStep = 17;
  static const gameStep = 18;
  static const resultStep = 19;
  static const readyStep = 20;
  static const rewardStep = 21;
  static const targetCount = 10;
  static const rule = 'Лови только желтые!';
  static const avoid =
      'Не лови товары с этими ценниками цвета — пропусти их мимо корзины';
  static const lines = [
    'Сколько скидок! Иногда они полезны, но иногда они заставляют нас тратить больше',
    'Скидки нужны чтобы покупать дешевле, как они могут заставить больше тратить?',
    'Иногда магазин сначала повышает цену, а потом показывает большую скидку',
    'Этот сок обычно стоит 50 фир и его много на складе. Магазин хочет его быстро продать, но не хочет продавать дешевле',
    'Он заранее повышает на него цену, а потом дает скидку. Поэтому зачёркнутая цена не всегда означает выгоду',
    'По одному ценнику нельзя узнать, была ли цена завышена.',
    'На этом список хитростей не заканчивается!',
    'Даже скидка на второй товар может навредить, если тебе этот второй товар не нужен',
    'Например,ты собирался потратить на йогурт 50 фир, а в итоге потратил на 2 йогурта 75.',
    'Еще важно проверять условия скидки на товар',
    'Я даже не рассказал про самую коварную скидку!',
    'Есть ли вообще что-то настоящее в этом мире... Почему все хотят обмануть...',
    'Некоторые скидки доступны только по карте магазина. Ты смотришь на яркие цифры и не видишь мелкую подпись',
    'А потом на кассе скидка не пробивается и ты платишь магазину больше, чем ты рассчитывал',
    'Слева мармеладки, которые стоили 100 фир. И справа тоже пачка мармелада за 100 фир.\nТолько правая на 20 грам меньше.',
    'Это называется шринкфляцией, когда цена остается той же, но самого товара в упаковке меньше и это самый обидный обман.',
    'Давай сыграем в игру и проверим насколько ты готов к обманам магазина?',
  ];
  static const actions = [
    'Далее',
    'Узнать больше',
    'Как так?',
    'Далее',
    'Далее',
    'Но...Это же обман?',
    'Серьезно?',
    'Далее?',
    'Далее',
    'Далее',
    'Мне страшно...',
    'Далее',
    'Далее',
    'Далее',
    'Далее',
    'Далее',
    'Я готов',
  ];
  static const nodes = [
    '30343',
    '30211',
    '30239',
    '30266',
    '30304',
    '30367',
    '30393',
    '30419',
    '30445',
    '30478',
    '30504',
    '30716',
    '30530',
    '30568',
    '30606',
    '30656',
    '30690',
  ];
  static bool human(int step) => step == 1 || step == 11;
  // The target is the yellow tag, as stated twice and illustrated in the design.
  // Orange, blue and green tags are distractors, regardless of their numbers.
  static const offers = [
    DiscountOffer(
      'popcorn',
      'Попкорн',
      'discount_popcorn',
      '−30%',
      DiscountTag.yellow,
    ),
    DiscountOffer(
      'juice',
      'Сок',
      'discount_juice',
      '10 фир\n80 граммов',
      DiscountTag.green,
    ),
    DiscountOffer('chips', 'Чипсы', 'discount_chips', '1+1', DiscountTag.blue),
    DiscountOffer(
      'apples',
      'Яблоки',
      'discount_apples',
      '50 фир\n100',
      DiscountTag.orange,
    ),
    DiscountOffer(
      'milk',
      'Молоко',
      'discount_milk',
      '−10%',
      DiscountTag.yellow,
    ),
    DiscountOffer('fish', 'Рыба', 'discount_fish', '1+1', DiscountTag.blue),
    DiscountOffer(
      'can',
      'Консервы',
      'discount_can',
      '30 фир\n80 граммов',
      DiscountTag.green,
    ),
    DiscountOffer(
      'sausage',
      'Колбаса',
      'discount_sausage',
      '50 фир\n100',
      DiscountTag.orange,
    ),
  ];
}

enum DiscountTag { yellow, blue, orange, green }

class DiscountOffer {
  const DiscountOffer(this.id, this.name, this.asset, this.label, this.tag);
  final String id, name, asset, label;
  final DiscountTag tag;
  bool get shouldCatch => tag == DiscountTag.yellow;
}

/// Replays accepted transitions instead of trusting a stored score or step.
/// This same evaluator gates rewards inside LearningService's transaction.
class DiscountProgress {
  int step = 0, round = 0, caught = 0;
  bool feedback = false, missedTarget = false;
  final List<String> events = [];
  DiscountOffer get offer =>
      DiscountTrapsLesson.offers[round % DiscountTrapsLesson.offers.length];
  bool get ready =>
      step == DiscountTrapsLesson.readyStep &&
      caught == DiscountTrapsLesson.targetCount &&
      !feedback;

  static DiscountProgress restore(Map<String, Object?> state) {
    final progress = DiscountProgress();
    if (state.isEmpty) return progress;
    if (state['version'] != 1 || state['events'] is! List) return progress;
    for (final event in state['events'] as List) {
      if (event is! String || !progress.apply(event)) return DiscountProgress();
    }
    return progress;
  }

  Map<String, Object?> get state => {
    'version': 1,
    'events': [...events],
  };

  bool apply(String event) {
    if (feedback) {
      if (event != 'retry') return false;
      feedback = false;
      missedTarget = false;
    } else if (step < DiscountTrapsLesson.gameStep) {
      if (event != 'next') return false;
      step++;
    } else if (step == DiscountTrapsLesson.gameStep) {
      if (event != 'catch:$round' && event != 'skip:$round') return false;
      final took = event.startsWith('catch:');
      if (took && offer.shouldCatch) caught++;
      feedback = took != offer.shouldCatch;
      missedTarget = !took && offer.shouldCatch;
      round++;
      if (caught == DiscountTrapsLesson.targetCount) {
        step = DiscountTrapsLesson.resultStep;
      }
    } else if (step == DiscountTrapsLesson.resultStep) {
      if (event != 'next') return false;
      step = DiscountTrapsLesson.readyStep;
    } else {
      return false;
    }
    events.add(event);
    return true;
  }
}
