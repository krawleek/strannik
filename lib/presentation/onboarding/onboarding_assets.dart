abstract final class OnboardingAssets {
  static const root = 'assets/onboarding/';
  static String image(String name) => '$root$name.png';
  static String skin(String id) => image('skin_$id');
}
