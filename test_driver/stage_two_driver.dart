import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final dir = Directory('build/stage2-qa/android');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png').writeAsBytes(bytes);
    return true;
  },
);
