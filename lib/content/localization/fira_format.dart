String formatFira(int amount) {
  final value = amount.abs();
  final lastTwo = value % 100;
  final last = value % 10;
  final word = lastTwo >= 11 && lastTwo <= 14
      ? 'фир'
      : switch (last) {
          1 => 'фира',
          2 || 3 || 4 => 'фиры',
          _ => 'фир',
        };
  return '$amount $word';
}
