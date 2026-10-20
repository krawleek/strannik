/// Figma Stage 3: all navigation and answer feedback live outside widgets.
/// The saved event journal is replayed through this graph before rewards unlock.
enum SafetyView {
  call,
  question,
  email,
  clues,
  prize,
  card,
  conclusion,
  complete,
}

class SafetyAction {
  const SafetyAction(this.id, this.label, this.next);
  final String id, label, next;
}

class SafetyAnswer {
  const SafetyAnswer(this.id, this.text, this.feedback, {this.correct = false});
  final String id, text, feedback;
  final bool correct;
}

class SafetyNode {
  const SafetyNode(
    this.id,
    this.view, {
    this.speech = '',
    this.caller = '',
    this.question = '',
    this.answers = const [],
    this.actions = const [],
    this.progress = 0,
  });
  final String id, speech, caller, question;
  final SafetyView view;
  final List<SafetyAnswer> answers;
  final List<SafetyAction> actions;
  final double progress;
}

class FinancialSafetyLesson {
  const FinancialSafetyLesson(
    this.taskId,
    this.nodes,
    this.title,
    this.ending,
    this.exitLabel,
  );
  static const callId = 'home_planet_safety_call';
  static const emailId = 'home_planet_safety_email';
  static const topicId = 'home_planet_safety';
  final String taskId, title, ending, exitLabel;
  final List<SafetyNode> nodes;
  SafetyNode node(String id) => nodes.firstWhere((n) => n.id == id);
  static FinancialSafetyLesson? forTask(String id) => switch (id) {
    callId => call,
    emailId => email,
    _ => null,
  };
  static const demand =
      'Вот молодец! Забери из дома деньги и все ценные вещи. Через час придёт мой человек. Отдашь всё ему!';
  static const guilt =
      'Ну что, ты поможешь родителям или тебе на них наплевать?';
  static const warning =
      'Незнакомый номер — повод быть осторожнее, а слова о звании ничего не доказывают. Но самое опасное здесь — угрозы и требование передать деньги.';
  static const safe =
      'А теперь самое время положить трубку и рассказать обо всём взрослому, которому доверяешь.';
  static const call = FinancialSafetyLesson(
    callId,
    [
      SafetyNode(
        'incoming',
        SafetyView.call,
        speech: 'Хм, незнакомый номер. Если не ждёшь звонка, лучше не отвечать. Но давай посмотрим, как действуют мошенники!',
        actions: [SafetyAction('answer_call', 'Взять трубку', 'colonel')],
      ),
      SafetyNode(
        'colonel',
        SafetyView.call,
        caller: 'Здравствуйте! Я полковник ФСБ. Ты знаешь, что такое ФСБ?',
        speech: 'ФСБ — это государственная служба безопасности. Но любой может назвать себя её сотрудником по телефону.',
        actions: [SafetyAction('listen', 'Слушать дальше', 'parents')],
      ),
      SafetyNode(
        'parents',
        SafetyView.call,
        caller: 'Твои родители совершили преступление! Но ты можешь спасти их от тюрьмы!',
        speech: 'Погоди-ка! Настоящий сотрудник ФСБ не стал бы просить ребёнка тайно спасать родителей.',
        actions: [SafetyAction('listen', 'Слушать дальше', 'law')],
      ),
      SafetyNode(
        'law',
        SafetyView.call,
        caller: '...',
        speech: 'Даже если кто-то нарушил закон, это решается по закону, а не по телефонным угрозам',
        actions: [SafetyAction('listen', 'Слушать дальше', 'guilt')],
      ),
      SafetyNode(
        'guilt',
        SafetyView.call,
        caller: guilt,
        speech: 'Фу, как грубо! Он так очевидно пытается заставить нас чувствовать вину',
        actions: [SafetyAction('listen', 'Слушать дальше', 'decision')],
      ),
      SafetyNode(
        'decision',
        SafetyView.call,
        caller: guilt,
        actions: [
          SafetyAction('listen', 'Слушать дальше', 'ask'),
          SafetyAction('hang_up', 'Бросить трубку', 'ended'),
        ],
      ),
      SafetyNode(
        'ask',
        SafetyView.call,
        caller: guilt,
        speech: 'Давай узнаем вместе, чего он добивается',
        actions: [
          SafetyAction('ask', 'Вы не сказали, чего хотите...', 'demand'),
        ],
      ),
      SafetyNode(
        'demand',
        SafetyView.call,
        caller: demand,
        speech: 'Настоящий сотрудник полиции или ФСБ не стал бы требовать от ребёнка деньги и драгоценности.',
        actions: [SafetyAction('next', 'Далее', 'call_warning')],
      ),
      SafetyNode(
        'ended',
        SafetyView.call,
        progress: .33,
        speech: 'Разговор окончен. Ты правильно сделал, что положил трубку. Такой звонящий может требовать деньги и ценные вещи. Расскажи обо всём взрослому, которому доверяешь.',
        actions: [SafetyAction('next', 'Далее', 'call_warning')],
      ),
      SafetyNode(
        'call_warning',
        SafetyView.question,
        progress: .33,
        question: 'Что в разговоре должно насторожить?',
        answers: [
          SafetyAnswer('rank', 'Он представился полковником', warning),
          SafetyAnswer(
            'threat_money',
            'Он угрожает родителям и требует деньги',
            'Точно! Незнакомец пугает тебя и требует деньги. Это серьёзный признак мошенничества.',
            correct: true,
          ),
          SafetyAnswer('unknown', 'Он позвонил с незнакомого номера', warning),
        ],
        actions: [SafetyAction('next', 'Далее', 'call_response')],
      ),
      SafetyNode(
        'call_response',
        SafetyView.question,
        progress: .66,
        question: 'Как стоит поступить Страннику?',
        answers: [
          SafetyAnswer(
            'give',
            'Собрать деньги и передать незнакомцу',
            'Стоп! Нельзя отдавать деньги и ценные вещи незнакомцам.',
          ),
          SafetyAnswer(
            'negotiate',
            'Продолжить разговор и попробовать договориться',
            'Мошенник может продолжать пугать и запутывать нас. Лучше закончить разговор и обратиться за помощью.',
          ),
          SafetyAnswer(
            'adult',
            'Положить трубку и рассказать всё взрослому',
            'Закончи разговор и расскажи обо всём взрослому, которому доверяешь.',
            correct: true,
          ),
        ],
        actions: [SafetyAction('next', 'Далее', 'safe_end')],
      ),
      SafetyNode(
        'safe_end',
        SafetyView.conclusion,
        progress: 1,
        speech: safe,
        actions: [SafetyAction('finish', 'Окончить звонок', 'complete')],
      ),
      SafetyNode('complete', SafetyView.complete, progress: 1),
    ],
    'Ты раскрыл обман!',
    'Теперь ты знаешь, что не стоит иметь дел с мошенниками.',
    'К заданиям',
  );

  static const email = FinancialSafetyLesson(
    emailId,
    [
      SafetyNode(
        'email',
        SafetyView.email,
        speech: 'Ого! Десять тысяч! Мы могли бы купить столько всего для корабля! Но… Мы ведь не участвовали ни в какой лотерее',
        actions: [SafetyAction('next', 'Далее', 'email_trust')],
      ),
      SafetyNode(
        'email_trust',
        SafetyView.question,
        question: 'Стоит ли доверять этому письму?',
        answers: [
          SafetyAnswer(
            'trust',
            'Да! Мы выиграли деньги!',
            'Не будем торопиться! Сначала проверим, кто отправил письмо и почему нам обещают деньги',
          ),
          SafetyAnswer(
            'check',
            'Не знаю, давай проверим',
            'Отличная идея! Давай поищем подозрительные детали',
            correct: true,
          ),
          SafetyAnswer(
            'fraud',
            'Это точно мошенники!',
            'Похоже на обман! Но давай найдём доказательства',
          ),
        ],
        actions: [SafetyAction('next', 'Далее', 'clues')],
      ),
      SafetyNode(
        'clues',
        SafetyView.clues,
        progress: .33,
        speech: 'Найдем улики? Нажимай на детали письма, которые кажутся подозрительными',
        actions: [SafetyAction('next', 'Далее', 'email_summary')],
      ),
      SafetyNode(
        'email_summary',
        SafetyView.email,
        progress: .33,
        speech: 'Кажется, письмо подозрительное. Давай посмотрим, что мошенники приготовили дальше.',
        actions: [SafetyAction('check_prize', 'Проверить приз', 'prize')],
      ),
      SafetyNode(
        'prize',
        SafetyView.prize,
        progress: .66,
        speech: 'Всего 30 рублей, а получить можно 10 000! Вроде выгодно… Или нас хотят обмануть?',
        actions: [SafetyAction('discuss', 'Давай обсудим', 'email_fee')],
      ),
      SafetyNode(
        'email_fee',
        SafetyView.question,
        progress: .66,
        question: 'Почему просьба заплатить 30 фир подозрительна?',
        answers: [
          SafetyAnswer(
            'small',
            '30 — это ведь совсем немного',
            'Маленькая сумма не делает предложение безопасным. За обещанием большого приза может скрываться попытка узнать данные карты. Не стоит платить даже 30 рублей!',
          ),
          SafetyAnswer(
            'pay_prize',
            'Если я выиграл, то почему должен платить за приз?',
            'Точно! Мошенники обещают большой приз, а потом просят маленький платёж. Но им могут быть нужны не эти 30 рублей, а данные твоей карты!',
            correct: true,
          ),
          SafetyAnswer(
            'later',
            'Надо узнать, можно ли заплатить после приза',
            'Отсрочка не делает предложение безопасным. Даже если заплатить позже, мошенники всё равно могут получить данные карты. За сомнительный приз платить не нужно.',
          ),
        ],
        actions: [SafetyAction('next', 'Далее', 'card')],
      ),
      SafetyNode(
        'card',
        SafetyView.card,
        progress: 1,
        speech: 'Сайт хочет узнать номер карты и код с обратной стороны. А ведь мы просто хотели получить подарок!',
        actions: [SafetyAction('next', 'Далее', 'delete_email')],
      ),
      SafetyNode(
        'delete_email',
        SafetyView.conclusion,
        progress: 1,
        speech: 'Сначала нам пообещали деньги, потом попросили заплатить, а теперь данные карты... это обман!',
        actions: [SafetyAction('finish', 'Удалить письмо', 'complete')],
      ),
      SafetyNode('complete', SafetyView.complete, progress: 1),
    ],
    'Мошенники разоблачены!',
    'Теперь ты знаешь, что неожиданный выигрыш нужно проверять и нельзя переходить по подозрительным ссылкам',
    'Завершить тему',
  );

  static const clueText = {
    'sender': 'Посмотри на адрес! Он похож на название магазина, но в нём есть лишние буквы. Мошенники часто используют похожие адреса',
    'prize': 'Мы не участвовали в лотерее. Почему тогда нам обещают приз? Это подозрительно',
    'link': 'Незнакомая ссылка может вести на поддельный сайт. Не стоит открывать её, не проверив',
  };
  static const clueLabels = {
    'sender': 'Лишние буквы',
    'prize': 'Неожиданный приз',
    'link': 'Незнакомая ссылка',
  };
}

/// Only accepted transitions are persisted. Replaying them also validates the
/// completion prerequisites at the service boundary, including clue collection.
class SafetyProgress {
  SafetyProgress(this.lesson);
  final FinancialSafetyLesson lesson;
  final List<String> events = [];
  late String nodeId = lesson.nodes.first.id;
  String? selectedId, lastClue;
  bool feedback = false;
  final Set<String> clues = {};
  SafetyNode get node => lesson.node(nodeId);
  SafetyAnswer? get selected => selectedId == null
      ? null
      : node.answers.firstWhere((a) => a.id == selectedId);
  bool get ready => node.view == SafetyView.complete;
  bool get canAdvance =>
      (node.view != SafetyView.question || feedback) &&
      (node.view != SafetyView.clues || clues.length == 3);
  Map<String, Object?> get saved => {
    'version': 1,
    'events': List<String>.of(events),
  };
  static SafetyProgress restore(
    FinancialSafetyLesson lesson,
    Map<String, Object?> state,
  ) {
    final p = SafetyProgress(lesson);
    for (final event in (state['events'] as List? ?? []).whereType<String>()) {
      if (!p.apply(event)) break;
    }
    return p;
  }

  bool apply(String event) {
    if (ready) return false;
    if (event.startsWith('answer:')) {
      final id = event.substring(7);
      if (node.view != SafetyView.question ||
          feedback ||
          !node.answers.any((a) => a.id == id)) {
        return false;
      }
      selectedId = id;
    } else if (event == 'check_answer') {
      if (node.view != SafetyView.question || selectedId == null || feedback) {
        return false;
      }
      feedback = true;
    } else if (event.startsWith('inspect:')) {
      final id = event.substring(8);
      if (node.view != SafetyView.clues ||
          !FinancialSafetyLesson.clueText.containsKey(id)) {
        return false;
      }
      clues.add(id);
      lastClue = id;
    } else {
      if (!canAdvance) return false;
      final actions = node.actions.where((a) => a.id == event);
      if (actions.isEmpty) return false;
      nodeId = actions.first.next;
      selectedId = null;
      feedback = false;
      lastClue = null;
    }
    events.add(event);
    return true;
  }
}
