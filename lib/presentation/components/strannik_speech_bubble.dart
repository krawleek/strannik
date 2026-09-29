import 'package:flutter/material.dart';

import '../assets/presentation_assets.dart';
import '../foundation/app_tokens.dart';

class StrannikSpeechBubble extends StatelessWidget {
  const StrannikSpeechBubble({
    super.key,
    required this.name,
    required this.child,
  });
  final String name;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(top: 14, child: const _BubbleArtwork()),
      Padding(padding: const EdgeInsets.fromLTRB(20, 50, 20, 30), child: child),
      Positioned(
        top: 0,
        left: 16,
        right: 32,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.darkOrange,
              border: Border.fromBorderSide(AppBorders.nameBadge),
              borderRadius: BorderRadius.circular(AppRadius.nameBadge),
              boxShadow: const [AppShadows.nameBadge],
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.badge,
            ),
          ),
        ),
      ),
    ],
  );
}

/// Explicit image patches avoid drawImageNine disappearing on Android OpenGLES.
/// All pixels come from the original Figma contours; no illustration is redrawn.
class _BubbleArtwork extends StatefulWidget {
  const _BubbleArtwork();
  @override
  State<_BubbleArtwork> createState() => _BubbleArtworkState();
}

class _BubbleArtworkState extends State<_BubbleArtwork> {
  ImageStream? _stream;
  ImageInfo? _image;
  late final ImageStreamListener _listener = ImageStreamListener((image, _) {
    _image?.dispose();
    setState(() => _image = image);
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_listener);
    _stream = const AssetImage(
      PresentationAssets.bubble,
    ).resolve(createLocalImageConfiguration(context))..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _image == null ? null : _BubblePainter(_image!));
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.info);
  final ImageInfo info;
  @override
  void paint(Canvas canvas, Size size) {
    final width = info.image.width / info.scale;
    final height = info.image.height / info.scale;
    final sourceX = [0.0, 60.0, 200.0, width];
    final sourceY = [0.0, 45.0, 75.0, height];
    final targetX = [0.0, 60.0, size.width - (width - 200), size.width];
    final targetY = [0.0, 45.0, size.height - (height - 75), size.height];
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 3; x++) {
        canvas.drawImageRect(
          info.image,
          Rect.fromLTRB(
            sourceX[x] * info.scale,
            sourceY[y] * info.scale,
            sourceX[x + 1] * info.scale,
            sourceY[y + 1] * info.scale,
          ),
          Rect.fromLTRB(targetX[x], targetY[y], targetX[x + 1], targetY[y + 1]),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => oldDelegate.info != info;
}
