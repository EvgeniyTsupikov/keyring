import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyring/services/encryption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EncryptionService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('encryptPassword uses v2 format and decrypts back', () async {
      final service = EncryptionService();
      await service.initialize();

      final encrypted = service.encryptPassword('super-secret');

      expect(encrypted.startsWith('v2:'), isTrue);
      expect(service.decryptPassword(encrypted), equals('super-secret'));
    });

    test('decryptPassword supports legacy payload format', () async {
      final key = Key.fromSecureRandom(32);
      final legacyIv = IV.fromSecureRandom(16);

      final encrypter = Encrypter(AES(key));
      final legacyCipher = encrypter.encrypt('legacy-password', iv: legacyIv).base64;

      SharedPreferences.setMockInitialValues({
        'encryption_key': key.base64,
        'encryption_key_iv': legacyIv.base64,
      });

      final service = EncryptionService();
      await service.initialize();

      final decrypted = service.decryptPassword(legacyCipher);
      expect(decrypted, equals('legacy-password'));
    });
  });
}
