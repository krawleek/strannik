import '../../domain/models/models.dart';

/// Display-only mappings. Fallbacks never replace persisted domain IDs.
class AssetChoice {
  const AssetChoice(this.path, {this.isFallback = false});
  final String path;
  final bool isFallback;
}

abstract final class PresentationAssets {
  static const room = 'assets/backgrounds/background.png';
  static String backgroundFor(Stage stage) => switch (stage) {
    Stage.earth => room,
    Stage.space => 'assets/backgrounds/space.png',
    Stage.homePlanet => 'assets/backgrounds/home_planet.png',
  };
  static const orangeCat = 'assets/illustrations/pet.png';
  static const petAvatar = 'assets/icons/pet_avatar.png';
  static const girlAvatar = 'assets/profile/avatar_girl.png';
  static const star = 'assets/icons/stage_star.png';
  static const bubble = 'assets/illustrations/bubble.png';
  static const home = 'assets/icons/nav_home.png';
  static const store = 'assets/icons/nav_store.png';
  static const bank = 'assets/icons/nav_bank.png';
  static const learning = 'assets/icons/nav_learning.png';

  static const _skins = {
    'orange': orangeCat,
    'gray': 'assets/onboarding/skin_gray.png',
    'cream': 'assets/onboarding/skin_cream.png',
  };
  static const _avatars = {
    'girl': girlAvatar,
    'boy': 'assets/profile/avatar_boy.png',
    'cap': 'assets/profile/avatar_boy.png',
  };
  // No approved accessory artwork yet. The bag is an explicit item thumbnail,
  // never drawn as if it were the actual accessory worn by the cat.
  static const Map<String, String> _accessories = {
    'scarf': 'assets/store/scarf.png',
  };
  static AssetChoice skin(String id) => _resolve(_skins, id, orangeCat);
  static AssetChoice avatar(String id) => _resolve(_avatars, id, girlAvatar);
  static AssetChoice accessory(String id) => _resolve(_accessories, id, store);
  static AssetChoice _resolve(
    Map<String, String> map,
    String id,
    String fallback,
  ) => AssetChoice(map[id] ?? fallback, isFallback: !map.containsKey(id));
}
