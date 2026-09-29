enum AppDestination {
  home('Дом'),
  store('Магазин'),
  bank('Банк'),
  learning('Обучение'),
  petProfile('Профиль питомца'),
  childProfile('Профиль ребёнка'),
  stages('Стадии');

  const AppDestination(this.label);
  final String label;
}
