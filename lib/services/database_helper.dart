import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/credential.dart';
import '../models/folder.dart';
import 'encryption_service.dart';

class DatabaseHelper {
  static final Random _random = Random();
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const String _credentialsBoxName = 'credentials';
  static const String _foldersBoxName = 'folders';
  
  Box? _credentialsBox;
  Box? _foldersBox;
  final EncryptionService _encryptionService = EncryptionService();

  Future<void> init() async {
    try {
      // Если Box уже открыт, не открываем снова
      if (_credentialsBox == null || !_credentialsBox!.isOpen) {
        _credentialsBox = await Hive.openBox(_credentialsBoxName);
        // Убеждаемся, что Box готов к работе
        await _credentialsBox!.flush();
      }
      if (_foldersBox == null || !_foldersBox!.isOpen) {
        _foldersBox = await Hive.openBox(_foldersBoxName);
        // Убеждаемся, что Box готов к работе
        await _foldersBox!.flush();
      }
    } catch (e) {
      // Если не удалось открыть, пробуем удалить и создать заново
      try {
        await Hive.deleteBoxFromDisk(_credentialsBoxName);
      } catch (_) {}
      try {
        await Hive.deleteBoxFromDisk(_foldersBoxName);
      } catch (_) {}
      
      _credentialsBox = await Hive.openBox(_credentialsBoxName);
      _foldersBox = await Hive.openBox(_foldersBoxName);
      // Убеждаемся, что Box готов к работе
      await _credentialsBox!.flush();
      await _foldersBox!.flush();
    }
  }

  // ========== Методы для работы с учетными записями ==========

  /// Добавить новую учетную запись
  Future<int> insertCredential(Credential credential) async {
    await _ensureInitialized();
    
    // Шифруем пароль перед сохранением
    final encryptedPassword = _encryptionService.encryptPassword(credential.password);
    
    // Генерируем ID если его нет
    int id = credential.id ?? _generateId();
    
    // Создаем объект с ID и зашифрованным паролем
    final credentialToSave = credential.copyWith(
      id: id,
      password: encryptedPassword,
    );
    
    // Сохраняем в Hive
    final json = credentialToSave.toJson();
    await _credentialsBox!.put(id.toString(), json);
    
    // Принудительно сохраняем на диск - это критически важно!
    await _credentialsBox!.flush();
    
    // Дополнительная проверка - убеждаемся, что данные записались
    // Проверяем, что данные действительно сохранились в памяти
    final saved = _credentialsBox!.get(id.toString());
    if (saved == null) {
      throw Exception('Failed to save credential - data not found after save');
    }
    
    // Дополнительная проверка - проверяем количество ключей
    final keysCount = _credentialsBox!.keys.length;
    if (keysCount == 0) {
      throw Exception('Failed to save credential - box is empty after save');
    }
    
    // Финальная проверка - еще раз вызываем flush для гарантии
    await _credentialsBox!.flush();
    
    return id;
  }

  /// Получить все учетные записи
  Future<List<Credential>> getAllCredentials() async {
    await _ensureInitialized();
    
    // Убеждаемся, что Box открыт и готов
    if (!_credentialsBox!.isOpen) {
      await init();
    }
    
    final List<Credential> credentials = [];
    
    // Получаем все ключи и преобразуем в список
    // Используем toList() для создания копии списка ключей
    final keysList = _credentialsBox!.keys.toList();
    
    // Если ключей нет, возвращаем пустой список
    if (keysList.isEmpty) {
      return credentials;
    }
    
    // Проходим по всем ключам и загружаем данные
    for (var key in keysList) {
      try {
        // Получаем значение по ключу
        final value = _credentialsBox!.get(key);
        if (value == null) continue;
        
        // Преобразуем в Map<String, dynamic>
        final json = Map<String, dynamic>.from(value as Map);
        final credential = Credential.fromJson(json);
        
        // Расшифровываем пароль при чтении
        final decryptedPassword = _encryptionService.decryptPassword(credential.password);
        
        // Добавляем учетную запись с правильным ID и расшифрованным паролем
        credentials.add(credential.copyWith(
          id: int.parse(key.toString()),
          password: decryptedPassword,
        ));
      } catch (e) {
        // Пропускаем поврежденные записи
        continue;
      }
    }
    
    credentials.sort((a, b) => a.title.compareTo(b.title));
    return credentials;
  }

  /// Поиск учетных записей
  Future<List<Credential>> searchCredentials(String query) async {
    final allCredentials = await getAllCredentials();
    final lowerQuery = query.toLowerCase();
    
    return allCredentials.where((credential) {
      return credential.title.toLowerCase().contains(lowerQuery) ||
          credential.username.toLowerCase().contains(lowerQuery) ||
          (credential.url?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Получить учетную запись по ID
  Future<Credential?> getCredentialById(int id) async {
    await _ensureInitialized();
    
    final value = _credentialsBox!.get(id.toString());
    if (value == null) return null;
    
    final json = Map<String, dynamic>.from(value as Map);
    final credential = Credential.fromJson(json);
    final decryptedPassword = _encryptionService.decryptPassword(credential.password);
    return credential.copyWith(
      id: id,
      password: decryptedPassword,
    );
  }

  /// Обновить учетную запись
  Future<int> updateCredential(Credential credential) async {
    await _ensureInitialized();
    
    if (credential.id == null) {
      throw Exception('Credential ID is required for update');
    }
    
    // Шифруем пароль перед сохранением
    final encryptedPassword = _encryptionService.encryptPassword(credential.password);
    final credentialToUpdate = credential.copyWith(
      password: encryptedPassword,
      updatedAt: DateTime.now(),
    );
    
    await _credentialsBox!.put(
      credential.id.toString(),
      credentialToUpdate.toJson(),
    );
    // Принудительно сохраняем на диск
    await _credentialsBox!.flush();
    return credential.id!;
  }

  /// Удалить учетную запись
  Future<int> deleteCredential(int id) async {
    await _ensureInitialized();
    await _credentialsBox!.delete(id.toString());
    // Принудительно сохраняем на диск
    await _credentialsBox!.flush();
    return id;
  }

  /// Получить учетные записи в папке
  Future<List<Credential>> getCredentialsByFolderId(int? folderId) async {
    final allCredentials = await getAllCredentials();
    
    if (folderId == null) {
      return allCredentials.where((c) => c.folderId == null).toList();
    } else {
      return allCredentials.where((c) => c.folderId == folderId).toList();
    }
  }

  // ========== Методы для работы с папками ==========

  /// Добавить новую папку
  Future<int> insertFolder(Folder folder) async {
    await _ensureInitialized();
    
    // Генерируем ID если его нет
    int id = folder.id ?? _generateId();
    
    // Создаем объект с ID
    final folderToSave = folder.copyWith(id: id);
    
    // Сохраняем в Hive
    final json = folderToSave.toJson();
    await _foldersBox!.put(id.toString(), json);
    // Принудительно сохраняем на диск - это критически важно!
    await _foldersBox!.flush();
    
    // Дополнительная проверка - убеждаемся, что данные записались
    // Проверяем, что данные действительно сохранились в памяти
    final saved = _foldersBox!.get(id.toString());
    if (saved == null) {
      throw Exception('Failed to save folder - data not found after save');
    }
    
    // Дополнительная проверка - проверяем количество ключей
    final keysCount = _foldersBox!.keys.length;
    if (keysCount == 0) {
      throw Exception('Failed to save folder - box is empty after save');
    }
    
    // Финальная проверка - еще раз вызываем flush для гарантии
    await _foldersBox!.flush();
    
    return id;
  }

  /// Получить все папки
  Future<List<Folder>> getAllFolders() async {
    await _ensureInitialized();
    
    // Убеждаемся, что Box открыт и готов
    if (!_foldersBox!.isOpen) {
      await init();
    }
    
    final List<Folder> folders = [];
    
    // Получаем все ключи и преобразуем в список
    // Используем toList() для создания копии списка ключей
    final keysList = _foldersBox!.keys.toList();
    
    // Если ключей нет, возвращаем пустой список
    if (keysList.isEmpty) {
      return folders;
    }
    
    // Проходим по всем ключам и загружаем данные
    for (var key in keysList) {
      try {
        // Получаем значение по ключу
        final value = _foldersBox!.get(key);
        if (value == null) continue;
        
        // Преобразуем в Map<String, dynamic>
        final json = Map<String, dynamic>.from(value as Map);
        final folder = Folder.fromJson(json);
        
        // Добавляем папку с правильным ID
        folders.add(folder.copyWith(id: int.parse(key.toString())));
      } catch (e) {
        // Пропускаем поврежденные записи
        continue;
      }
    }
    
    folders.sort((a, b) => a.name.compareTo(b.name));
    return folders;
  }

  /// Получить папку по ID
  Future<Folder?> getFolderById(int id) async {
    await _ensureInitialized();
    
    final value = _foldersBox!.get(id.toString());
    if (value == null) return null;
    
    final json = Map<String, dynamic>.from(value as Map);
    final folder = Folder.fromJson(json);
    return folder.copyWith(id: id);
  }

  /// Обновить папку
  Future<int> updateFolder(Folder folder) async {
    await _ensureInitialized();
    
    if (folder.id == null) {
      throw Exception('Folder ID is required for update');
    }
    
    final folderToUpdate = folder.copyWith(updatedAt: DateTime.now());
    
    // Сохраняем в Hive
    final json = folderToUpdate.toJson();
    await _foldersBox!.put(
      folder.id.toString(),
      json,
    );
    // Принудительно сохраняем на диск
    await _foldersBox!.flush();
    
    return folder.id!;
  }

  /// Удалить папку
  Future<int> deleteFolder(int id) async {
    await _ensureInitialized();
    
    // Обнуляем folderId у всех учетных записей в этой папке
    final allCredentials = await getAllCredentials();
    for (var credential in allCredentials) {
      if (credential.folderId == id && credential.id != null) {
        await updateCredential(credential.copyWith(folderId: null));
      }
    }
    
    // Удаляем папку
    await _foldersBox!.delete(id.toString());
    // Принудительно сохраняем на диск
    await _foldersBox!.flush();
    return id;
  }

  /// Получить статистику
  Future<Map<String, int>> getStatistics() async {
    await _ensureInitialized();
    
    final credentials = await getAllCredentials();
    final folders = await getAllFolders();
    
    final sitesSet = <String>{};
    for (var credential in credentials) {
      if (credential.url != null && credential.url!.isNotEmpty) {
        sitesSet.add(credential.url!);
      }
    }
    
    return {
      'credentials': credentials.length,
      'folders': folders.length,
      'sites': sitesSet.length,
    };
  }

  /// Закрыть базы данных (используется только при завершении приложения)
  Future<void> close() async {
    if (_credentialsBox != null && _credentialsBox!.isOpen) {
      await _credentialsBox!.flush();
      await _credentialsBox!.close();
    }
    if (_foldersBox != null && _foldersBox!.isOpen) {
      await _foldersBox!.flush();
      await _foldersBox!.close();
    }
  }

  // Вспомогательные методы

  Future<void> _ensureInitialized() async {
    if (_credentialsBox == null || _foldersBox == null || 
        !_credentialsBox!.isOpen || !_foldersBox!.isOpen) {
      await init();
    }
    // Дополнительная проверка
    if (_credentialsBox == null || _foldersBox == null || 
        !_credentialsBox!.isOpen || !_foldersBox!.isOpen) {
      throw Exception('Database boxes are not initialized or closed');
    }
  }

  int _generateId() {
    final timestampMicros = DateTime.now().microsecondsSinceEpoch;
    final randomTail = _random.nextInt(1000);
    return (timestampMicros * 1000) + randomTail;
  }
}
