import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';

class Pbkdf2PinHasher implements PinHasher {
  Pbkdf2PinHasher({this.iterations = 210000});
  final int iterations;
  Future<List<int>> _derive(String pin, List<int> salt, int count) async =>
      (await Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: count,
            bits: 256,
          ).deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt))
          .extractBytes();
  @override
  Future<PinCredential> hash(String pin) async {
    final random = Random.secure();
    final salt = List.generate(16, (_) => random.nextInt(256));
    return PinCredential(
      salt: base64Encode(salt),
      hash: base64Encode(await _derive(pin, salt, iterations)),
      iterations: iterations,
    );
  }

  @override
  Future<bool> verify(String pin, PinCredential credential) async {
    if (credential.algorithm != 'pbkdf2-sha256' || credential.iterations <= 0) {
      return false;
    }
    final actual = await _derive(
      pin,
      base64Decode(credential.salt),
      credential.iterations,
    );
    final expected = base64Decode(credential.hash);
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }
}
