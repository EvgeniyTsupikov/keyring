import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  static const String _keyStorageKey = 'encryption_key';
  static const String _ivStorageKey = 'encryption_key_iv';
  static const String _cipherV2Prefix = 'v2:';

  Key? _key;
  IV? _legacyIv;

  /// Инициализация ключа шифрования
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedKey = prefs.getString(_keyStorageKey);
    final storedIv = prefs.getString(_ivStorageKey);
    
    if (storedKey != null) {
      // Используем существующий ключ
      _key = Key.fromBase64(storedKey);
    } else {
      // Генерируем новый ключ
      _key = Key.fromSecureRandom(32);
      await prefs.setString(_keyStorageKey, _key!.base64);
    }

    if (storedIv != null) {
      // Используем существующий IV
      _legacyIv = IV.fromBase64(storedIv);
    } else {
      // Генерируем новый IV
      _legacyIv = IV.fromSecureRandom(16);
      await prefs.setString(_ivStorageKey, _legacyIv!.base64);
    }
  }

  /// Шифрование пароля
  String encryptPassword(String password) {
    if (_key == null) {
      throw Exception('EncryptionService not initialized');
    }

    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(_key!));
    final encrypted = encrypter.encrypt(password, iv: iv);
    return '$_cipherV2Prefix${iv.base64}:${encrypted.base64}';
  }

  /// Расшифровка пароля
  String decryptPassword(String encryptedPassword) {
    if (_key == null) {
      throw Exception('EncryptionService not initialized');
    }

    final encrypter = Encrypter(AES(_key!));

    if (encryptedPassword.startsWith(_cipherV2Prefix)) {
      final payload = encryptedPassword.substring(_cipherV2Prefix.length);
      final separatorIndex = payload.indexOf(':');
      if (separatorIndex <= 0 || separatorIndex >= payload.length - 1) {
        throw Exception('Invalid encrypted payload format');
      }

      final ivBase64 = payload.substring(0, separatorIndex);
      final cipherBase64 = payload.substring(separatorIndex + 1);
      final iv = IV.fromBase64(ivBase64);
      final encrypted = Encrypted.fromBase64(cipherBase64);
      return encrypter.decrypt(encrypted, iv: iv);
    }

    if (_legacyIv == null) {
      throw Exception('Legacy IV not found for backward compatibility decrypt');
    }

    final encrypted = Encrypted.fromBase64(encryptedPassword);
    return encrypter.decrypt(encrypted, iv: _legacyIv!);
  }

  /// Проверка инициализации
  bool get isInitialized => _key != null;
}

