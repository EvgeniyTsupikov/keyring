import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:keyring/models/credential.dart';
import 'package:keyring/models/folder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('DatabaseHelper Persistence Tests', () {
    late String testPath;
    Box? credentialsBox;
    Box? foldersBox;

    setUpAll(() async {
      // Инициализация Hive для тестов с временной директорией
      final directory = await Directory.systemTemp.createTemp('hive_test_');
      testPath = directory.path;
      Hive.init(testPath);
    });

    setUp(() async {
      // Очищаем базу данных перед каждым тестом
      try {
        await Hive.deleteBoxFromDisk('credentials');
      } catch (_) {}
      try {
        await Hive.deleteBoxFromDisk('folders');
      } catch (_) {}
      
      // Открываем Box
      credentialsBox = await Hive.openBox('credentials');
      foldersBox = await Hive.openBox('folders');
    });

    tearDown(() async {
      // Закрываем Box после каждого теста
      await credentialsBox?.close();
      await foldersBox?.close();
    });

    tearDownAll(() async {
      // Очищаем временную директорию после всех тестов
      try {
        final directory = Directory(testPath);
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('Должен сохранять и загружать учетную запись после переоткрытия Box', () async {
      // Создаем учетную запись
      final credential = Credential(
        title: 'Test Service',
        username: 'testuser',
        password: 'testpass123',
        url: 'https://test.com',
        notes: 'Test notes',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Сохраняем
      final id = 1234567890;
      final json = credential.toJson();
      await credentialsBox!.put(id.toString(), json);
      await credentialsBox!.flush();

      // Проверяем, что данные сохранились
      final saved = credentialsBox!.get(id.toString());
      expect(saved, isNotNull);

      // Закрываем Box
      await credentialsBox!.close();

      // Переоткрываем Box
      credentialsBox = await Hive.openBox('credentials');

      // Загружаем данные
      final loadedValue = credentialsBox!.get(id.toString());
      expect(loadedValue, isNotNull);
      
      final loadedCredential = Credential.fromJson(Map<String, dynamic>.from(loadedValue as Map));
      expect(loadedCredential.title, equals('Test Service'));
      expect(loadedCredential.username, equals('testuser'));
      expect(loadedCredential.password, equals('testpass123'));
      expect(loadedCredential.url, equals('https://test.com'));
    });

    test('Должен сохранять и загружать папку после переоткрытия Box', () async {
      // Создаем папку
      final folder = Folder(
        name: 'Test Folder',
        color: '#FF0000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Сохраняем
      final id = 1234567890;
      final json = folder.toJson();
      await foldersBox!.put(id.toString(), json);
      await foldersBox!.flush();

      // Проверяем, что данные сохранились
      final saved = foldersBox!.get(id.toString());
      expect(saved, isNotNull);

      // Закрываем Box
      await foldersBox!.close();

      // Переоткрываем Box
      foldersBox = await Hive.openBox('folders');

      // Загружаем данные
      final loadedValue = foldersBox!.get(id.toString());
      expect(loadedValue, isNotNull);
      
      final loadedFolder = Folder.fromJson(Map<String, dynamic>.from(loadedValue as Map));
      expect(loadedFolder.name, equals('Test Folder'));
      expect(loadedFolder.color, equals('#FF0000'));
    });

    test('Должен сохранять несколько учетных записей и загружать их', () async {
      // Создаем несколько учетных записей
      final credential1 = Credential(
        title: 'Service 1',
        username: 'user1',
        password: 'pass1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final credential2 = Credential(
        title: 'Service 2',
        username: 'user2',
        password: 'pass2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await credentialsBox!.put('1', credential1.toJson());
      await credentialsBox!.put('2', credential2.toJson());
      await credentialsBox!.flush();

      // Закрываем Box
      await credentialsBox!.close();

      // Переоткрываем Box
      credentialsBox = await Hive.openBox('credentials');

      // Загружаем все данные
      final keys = credentialsBox!.keys.toList();
      expect(keys.length, equals(2));

      final loaded1 = Credential.fromJson(Map<String, dynamic>.from(credentialsBox!.get('1') as Map));
      final loaded2 = Credential.fromJson(Map<String, dynamic>.from(credentialsBox!.get('2') as Map));

      expect(loaded1.title, equals('Service 1'));
      expect(loaded2.title, equals('Service 2'));
    });

    test('Должен сохранять учетную запись с кастомными полями', () async {
      // Создаем учетную запись с кастомными полями
      final credential = Credential(
        title: 'Test Service',
        username: 'testuser',
        password: 'testpass123',
        customFields: {
          'PIN': '1234',
          'Security Question': 'What is your pet name?',
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = 1234567890;
      await credentialsBox!.put(id.toString(), credential.toJson());
      await credentialsBox!.flush();

      // Закрываем Box
      await credentialsBox!.close();

      // Переоткрываем Box
      credentialsBox = await Hive.openBox('credentials');

      // Загружаем данные
      final loadedValue = credentialsBox!.get(id.toString());
      final loadedCredential = Credential.fromJson(Map<String, dynamic>.from(loadedValue as Map));
      
      expect(loadedCredential.customFields.length, equals(2));
      expect(loadedCredential.customFields['PIN'], equals('1234'));
      expect(loadedCredential.customFields['Security Question'], equals('What is your pet name?'));
    });

    test('Должен удалять учетную запись и сохранять изменения', () async {
      // Создаем учетную запись
      final credential = Credential(
        title: 'Test Service',
        username: 'testuser',
        password: 'testpass123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = 1234567890;
      await credentialsBox!.put(id.toString(), credential.toJson());
      await credentialsBox!.flush();

      // Удаляем
      await credentialsBox!.delete(id.toString());
      await credentialsBox!.flush();

      // Закрываем Box
      await credentialsBox!.close();

      // Переоткрываем Box
      credentialsBox = await Hive.openBox('credentials');

      // Проверяем удаление
      final keys = credentialsBox!.keys.toList();
      expect(keys.length, equals(0));
      expect(credentialsBox!.get(id.toString()), isNull);
    });
  });
}
