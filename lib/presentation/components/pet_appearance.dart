import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../assets/presentation_assets.dart';
import '../store/store_assets.dart';

/// Figma Master Cat canvas: a base skin plus independently persisted equipment.
/// Preview overrides only this render; it never changes ownership or Pet state.
class PetAppearance extends StatelessWidget {
  const PetAppearance({super.key, this.pet, this.accessoryId});
  final Pet? pet;
  final String? accessoryId;
  @override
  Widget build(BuildContext context) {
    final skin = PresentationAssets.skin(pet?.skinId ?? 'orange');
    final base = pet?.skinId == 'orange' || pet == null || skin.isFallback
        ? StoreAssets.cat
        : skin.path;
    final layer = StoreAssets.accessory(
      accessoryId ?? pet?.equippedAccessoryId,
    );
    return AspectRatio(
      aspectRatio: 291 / 310,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / 291;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 281 * scale,
                height: 305 * scale,
                child: Image.asset(
                  base,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              if (layer != null)
                Positioned(
                  left: 61 * scale,
                  top: 112 * scale,
                  width: 143 * scale,
                  height: 104 * scale,
                  child: Image.asset(
                    layer,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
