import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../services/database_helper.dart';

class FolderEditPage extends StatefulWidget {
  final Folder? folder;

  const FolderEditPage({super.key, this.folder});

  @override
  State<FolderEditPage> createState() => _FolderEditPageState();
}

class _FolderEditPageState extends State<FolderEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Color _selectedColor = Colors.blue;

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.folder != null) {
      _nameController.text = widget.folder!.name;
      if (widget.folder!.color != null) {
        _selectedColor = Color(int.parse(widget.folder!.color!.replaceFirst('#', ''), radix: 16));
      }
    }
  }

  Future<void> _saveFolder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final now = DateTime.now();
      Folder folder;

      if (widget.folder != null) {
        // Обновление существующей папки
        folder = widget.folder!.copyWith(
          name: _nameController.text.trim(),
          color: '#${_selectedColor.value.toRadixString(16).padLeft(8, '0')}',
          updatedAt: now,
        );
        await _dbHelper.updateFolder(folder);
      } else {
        // Создание новой папки
        folder = Folder(
          name: _nameController.text.trim(),
          color: '#${_selectedColor.value.toRadixString(16).padLeft(8, '0')}',
          createdAt: now,
          updatedAt: now,
        );
        final savedId = await _dbHelper.insertFolder(folder);
        // Проверяем, что данные сохранились
        await Future.delayed(const Duration(milliseconds: 100));
        final saved = await _dbHelper.getFolderById(savedId);
        if (saved == null) {
          throw Exception('Folder was not saved properly');
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.folder != null
                    ? 'Папка обновлена'
                    : 'Папка создана',
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
        title: Text(widget.folder != null ? 'Редактировать папку' : 'Новая папка'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название папки *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите название папки';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Цвет папки',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _availableColors.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveFolder,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(widget.folder != null ? 'Сохранить' : 'Создать'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

