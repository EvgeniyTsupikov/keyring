import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  static const String _keyStorageKey = 'encryption_key';
  static const String _ivStorageKey = 'encryption_key_iv';

  Key? _key;
  IV? _iv;

  /// Инициализация ключа шифрования
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedKey = prefs.getString(_keyStorageKey);
    String? storedIv = prefs.getString(_ivStorageKey);
    
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
      _iv = IV.fromBase64(storedIv);
    } else {
      // Генерируем новый IV
      _iv = IV.fromSecureRandom(16);
      await prefs.setString(_ivStorageKey, _iv!.base64);
    }
  }

  /// Шифрование пароля
  String encryptPassword(String password) {
    if (_key == null || _iv == null) {
      throw Exception('EncryptionService not initialized');
    }

    final encrypter = Encrypter(AES(_key!));
    final encrypted = encrypter.encrypt(password, iv: _iv!);
    return encrypted.base64;
  }

  /// Расшифровка пароля
  String decryptPassword(String encryptedPassword) {
    if (_key == null || _iv == null) {
      throw Exception('EncryptionService not initialized');
    }

    final encrypter = Encrypter(AES(_key!));
    final encrypted = Encrypted.fromBase64(encryptedPassword);
    return encrypter.decrypt(encrypted, iv: _iv!);
  }

  /// Проверка инициализации
  bool get isInitialized => _key != null && _iv != null;
}

