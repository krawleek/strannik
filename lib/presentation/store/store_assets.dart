import '../../domain/models/models.dart';

abstract final class StoreAssets {
  static const room = 'assets/store/room.png';
  static const closetRoom = 'assets/store/closet_room.png';
  static const cat = 'assets/store/cat.png';
  static const scarfLayer = 'assets/store/scarf_overlay.png';
  static const products = <String, String>{
    'scarf': 'assets/store/scarf.png',
    'treat': 'assets/store/treat.png',
    'ball': 'assets/store/ball.png',
    'fuel': 'assets/store/fuel.png',
    'medicine': 'assets/store/medicine.png',
  };
  static String? product(StoreItem item) =>
      products[item.assetId] ?? products[item.id];
  static String? accessory(String? id) => id == 'scarf' ? scarfLayer : null;
}
