import 'dart:math';
import 'package:flutter/material.dart';
import '../models/credential.dart';
import '../models/folder.dart';
import '../services/database_helper.dart';

class CredentialEditPage extends StatefulWidget {
  final Credential? credential;
  final int? initialFolderId;

  const CredentialEditPage({super.key, this.credential, this.initialFolderId});

  @override
  State<CredentialEditPage> createState() => _CredentialEditPageState();
}

class _CredentialEditPageState extends State<CredentialEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isPasswordVisible = false;
  List<Folder> _folders = [];
  int? _selectedFolderId;
  Map<String, String> _customFields = {}; // Кастомные поля
  Map<String, String> _customFieldTypes = {}; // Типы кастомных полей ('text' или 'password')
  final Map<String, TextEditingController> _customFieldKeyControllers = {};
  final Map<String, TextEditingController> _customFieldValueControllers = {};
  final Map<String, bool> _customFieldPasswordVisible = {}; // Видимость паролей в кастомных полях

  @override
  void initState() {
    super.initState();
    if (widget.credential != null) {
      _titleController.text = widget.credential!.title;
      _usernameController.text = widget.credential!.username;
      _passwordController.text = widget.credential!.password;
      _urlController.text = widget.credential!.url ?? '';
      _notesController.text = widget.credential!.notes ?? '';
      _selectedFolderId = widget.credential!.folderId;
      _customFields = Map<String, String>.from(widget.credential!.customFields);
      _customFieldTypes = Map<String, String>.from(widget.credential!.customFieldTypes);
      // Создаем контроллеры для существующих полей
      for (var entry in _customFields.entries) {
        _customFieldKeyControllers[entry.key] = TextEditingController(text: entry.key);
        _customFieldValueControllers[entry.key] = TextEditingController(text: entry.value);
        _customFieldPasswordVisible[entry.key] = false; // По умолчанию пароли скрыты
      }
    } else {
      _selectedFolderId = widget.initialFolderId;
    }
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final folders = await _dbHelper.getAllFolders();
    setState(() {
      _folders = folders;
    });
  }

  String _generatePassword({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSymbols = true,
  }) {
    const String uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const String numbers = '0123456789';
    const String symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

    String chars = '';
    if (includeUppercase) chars += uppercase;
    if (includeLowercase) chars += lowercase;
    if (includeNumbers) chars += numbers;
    if (includeSymbols) chars += symbols;

    if (chars.isEmpty) chars = lowercase + numbers;

    final random = Random.secure();
    String password = '';
    for (int i = 0; i < length; i++) {
      password += chars[random.nextInt(chars.length)];
    }

    return password;
  }

  Future<void> _showPasswordGenerator() async {
    int length = 16;
    bool includeUppercase = true;
    bool includeLowercase = true;
    bool includeNumbers = true;
    bool includeSymbols = true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Генератор паролей'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Длина: $length'),
                Slider(
                  value: length.toDouble(),
                  min: 8,
                  max: 32,
                  divisions: 24,
                  label: length.toString(),
                  onChanged: (value) {
                    setDialogState(() {
                      length = value.toInt();
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Заглавные буквы'),
                  value: includeUppercase,
                  onChanged: (value) {
                    setDialogState(() {
                      includeUppercase = value ?? true;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Строчные буквы'),
                  value: includeLowercase,
                  onChanged: (value) {
                    setDialogState(() {
                      includeLowercase = value ?? true;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Цифры'),
                  value: includeNumbers,
                  onChanged: (value) {
                    setDialogState(() {
                      includeNumbers = value ?? true;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Символы'),
                  value: includeSymbols,
                  onChanged: (value) {
                    setDialogState(() {
                      includeSymbols = value ?? true;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final password = _generatePassword(
                  length: length,
                  includeUppercase: includeUppercase,
                  includeLowercase: includeLowercase,
                  includeNumbers: includeNumbers,
                  includeSymbols: includeSymbols,
                );
                Navigator.pop(context, password);
              },
              child: const Text('Сгенерировать'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _passwordController.text = result;
      });
    }
  }

  void _addCustomField() {
    final newKey = 'Поле ${_customFields.length + 1}';
    setState(() {
      _customFields[newKey] = '';
      _customFieldTypes[newKey] = 'text'; // По умолчанию тип "заметка"
      _customFieldKeyControllers[newKey] = TextEditingController(text: newKey);
      _customFieldValueControllers[newKey] = TextEditingController();
      _customFieldPasswordVisible[newKey] = false;
    });
  }

  void _removeCustomField(String key) {
    setState(() {
      _customFields.remove(key);
      _customFieldTypes.remove(key);
      _customFieldKeyControllers[key]?.dispose();
      _customFieldValueControllers[key]?.dispose();
      _customFieldKeyControllers.remove(key);
      _customFieldValueControllers.remove(key);
      _customFieldPasswordVisible.remove(key);
    });
  }


  Widget _buildCustomFieldRow(String key, String value) {
    // Получаем или создаем контроллеры для этого поля
    if (!_customFieldKeyControllers.containsKey(key)) {
      _customFieldKeyControllers[key] = TextEditingController(text: key);
    }
    if (!_customFieldValueControllers.containsKey(key)) {
      _customFieldValueControllers[key] = TextEditingController(text: value);
    }

    final keyController = _customFieldKeyControllers[key]!;
    final valueController = _customFieldValueControllers[key]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Название поля',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (newKey) {
                if (newKey.trim().isNotEmpty && newKey.trim() != key) {
                  // Ключ изменился - нужно обновить структуру данных
                  final oldValue = valueController.text;
                  setState(() {
                    _customFields.remove(key);
                    _customFields[newKey.trim()] = oldValue;
                    
                    // Обновляем контроллеры и типы
                    _customFieldKeyControllers[newKey.trim()] = _customFieldKeyControllers.remove(key)!;
                    _customFieldValueControllers[newKey.trim()] = _customFieldValueControllers.remove(key)!;
                    if (_customFieldTypes.containsKey(key)) {
                      _customFieldTypes[newKey.trim()] = _customFieldTypes.remove(key)!;
                    }
                    if (_customFieldPasswordVisible.containsKey(key)) {
                      _customFieldPasswordVisible[newKey.trim()] = _customFieldPasswordVisible.remove(key)!;
                    }
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // Выбор типа поля
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<String>(
              value: _customFieldTypes[key] ?? 'text',
              decoration: const InputDecoration(
                labelText: 'Тип',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'text',
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 18),
                      SizedBox(width: 8),
                      Text('Заметка'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'password',
                  child: Row(
                    children: [
                      Icon(Icons.lock, size: 18),
                      SizedBox(width: 8),
                      Text('Пароль'),
                    ],
                  ),
                ),
              ],
              onChanged: (newType) {
                if (newType != null) {
                  setState(() {
                    _customFieldTypes[key] = newType;
                    if (newType == 'password') {
                      _customFieldPasswordVisible[key] = false;
                    }
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: valueController,
              decoration: InputDecoration(
                labelText: 'Значение',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: (_customFieldTypes[key] ?? 'text') == 'password'
                    ? IconButton(
                        icon: Icon(
                          _customFieldPasswordVisible[key] ?? false
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _customFieldPasswordVisible[key] = !(_customFieldPasswordVisible[key] ?? false);
                          });
                        },
                        tooltip: _customFieldPasswordVisible[key] ?? false
                            ? 'Скрыть пароль'
                            : 'Показать пароль',
                      )
                    : null,
              ),
              obscureText: (_customFieldTypes[key] ?? 'text') == 'password' &&
                  !(_customFieldPasswordVisible[key] ?? false),
              onChanged: (newValue) {
                final currentKey = keyController.text.trim().isNotEmpty 
                    ? keyController.text.trim() 
                    : key;
                setState(() {
                  _customFields[currentKey] = newValue;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _removeCustomField(key),
            tooltip: 'Удалить поле',
          ),
        ],
      ),
    );
  }

  Future<void> _saveCredential() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // Собираем актуальные значения из контроллеров
      final Map<String, String> finalCustomFields = {};
      final Map<String, String> finalCustomFieldTypes = {};
      for (var entry in _customFieldKeyControllers.entries) {
        final key = entry.value.text.trim();
        final value = _customFieldValueControllers[entry.key]?.text.trim() ?? '';
        if (key.isNotEmpty) {
          finalCustomFields[key] = value;
          // Сохраняем тип поля
          final originalKey = entry.key;
          if (_customFieldTypes.containsKey(originalKey)) {
            finalCustomFieldTypes[key] = _customFieldTypes[originalKey]!;
          } else {
            finalCustomFieldTypes[key] = 'text'; // По умолчанию
          }
        }
      }

      final now = DateTime.now();
      Credential credential;

      if (widget.credential != null) {
        // Обновление существующей записи
        credential = widget.credential!.copyWith(
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          url: _urlController.text.trim().isEmpty
              ? null
              : _urlController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          folderId: _selectedFolderId,
          customFields: finalCustomFields,
          customFieldTypes: finalCustomFieldTypes,
          updatedAt: now,
        );
        await _dbHelper.updateCredential(credential);
      } else {
        // Создание новой записи
        credential = Credential(
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          url: _urlController.text.trim().isEmpty
              ? null
              : _urlController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          folderId: _selectedFolderId,
          customFields: finalCustomFields,
          customFieldTypes: finalCustomFieldTypes,
          createdAt: now,
          updatedAt: now,
        );
        final savedId = await _dbHelper.insertCredential(credential);
        // Проверяем, что данные сохранились
        await Future.delayed(const Duration(milliseconds: 100));
        final saved = await _dbHelper.getCredentialById(savedId);
        if (saved == null) {
          throw Exception('Credential was not saved properly');
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.credential != null
                    ? 'Учетная запись обновлена'
                    : 'Учетная запись сохранена',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Ошибка при сохранении';
        if (e.toString().contains('libsqlite3.so')) {
          errorMessage = 'Ошибка: не найдена библиотека SQLite. Установите: sudo apt-get install libsqlite3-dev';
        } else {
          errorMessage = 'Ошибка при сохранении: ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.credential != null ? 'Редактировать' : 'Новая учетная запись'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название / Сервис *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите название';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL (необязательно)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Логин / Email *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите логин';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Пароль *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.autorenew),
                      onPressed: _showPasswordGenerator,
                      tooltip: 'Сгенерировать пароль',
                    ),
                  ],
                ),
              ),
              obscureText: !_isPasswordVisible,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите пароль';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _selectedFolderId,
              decoration: const InputDecoration(
                labelText: 'Папка (необязательно)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Без папки'),
                ),
                ..._folders.map((folder) {
                  final folderColor = folder.color != null
                      ? Color(int.parse(folder.color!.replaceFirst('#', ''), radix: 16))
                      : Colors.blue;
                  return DropdownMenuItem<int?>(
                    value: folder.id,
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: folderColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(folder.name),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedFolderId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Заметки (необязательно)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            // Секция дополнительных полей
            Row(
              children: [
                const Icon(Icons.add_circle_outline),
                const SizedBox(width: 8),
                Text(
                  'Дополнительные поля',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._customFields.entries.map((entry) => _buildCustomFieldRow(entry.key, entry.value)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addCustomField,
              icon: const Icon(Icons.add),
              label: const Text('Добавить поле'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveCredential,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(widget.credential != null ? 'Сохранить' : 'Создать'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    // Освобождаем контроллеры дополнительных полей
    for (var controller in _customFieldKeyControllers.values) {
      controller.dispose();
    }
    for (var controller in _customFieldValueControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

