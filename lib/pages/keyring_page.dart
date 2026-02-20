import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/credential.dart';
import '../models/folder.dart';
import '../services/database_helper.dart';
import 'credential_edit_page.dart';
import 'folder_edit_page.dart';
import 'settings_page.dart';

class KeyRingPage extends StatefulWidget {
  final ValueChanged<bool>? onThemeChanged;
  final ValueChanged<Locale>? onLanguageChanged;
  final Locale currentLocale;
  
  const KeyRingPage({
    super.key, 
    this.onThemeChanged,
    this.onLanguageChanged,
    required this.currentLocale,
  });

  @override
  State<KeyRingPage> createState() => _KeyRingPageState();
}

class _KeyRingPageState extends State<KeyRingPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Credential> _credentials = [];
  List<Credential> _filteredCredentials = [];
  List<Folder> _folders = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  int? _selectedFolderId;
  final Map<int, bool> _expandedFolders = {}; // Отслеживание развернутых папок

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Убеждаемся, что база данных инициализирована
      await _dbHelper.init();
      
      final credentials = await _dbHelper.getAllCredentials();
      final folders = await _dbHelper.getAllFolders();
      
      if (mounted) {
        setState(() {
          _credentials = credentials;
          _folders = folders;
          _updateFilteredCredentials();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки данных: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _updateFilteredCredentials() {
    if (_selectedFolderId == null) {
      // В режиме "Все" показываем все записи (фильтрация будет в UI)
      _filteredCredentials = _credentials;
    } else {
      _filteredCredentials = _credentials.where((c) => c.folderId == _selectedFolderId).toList();
    }
  }

  void _filterCredentials(String query) {
    setState(() {
      if (query.isEmpty) {
        _updateFilteredCredentials();
      } else {
        // Поиск работает для всех записей
        _filteredCredentials = _credentials.where((credential) {
          return credential.title.toLowerCase().contains(query.toLowerCase()) ||
              credential.username.toLowerCase().contains(query.toLowerCase()) ||
              (credential.url?.toLowerCase().contains(query.toLowerCase()) ?? false);
        }).toList();
      }
    });
  }

  List<Credential> _getCredentialsForFolder(int? folderId) {
    if (_isSearching && _searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      return _credentials.where((credential) {
        final matchesFolder = credential.folderId == folderId;
        final matchesSearch = credential.title.toLowerCase().contains(query) ||
            credential.username.toLowerCase().contains(query) ||
            (credential.url?.toLowerCase().contains(query) ?? false);
        return matchesFolder && matchesSearch;
      }).toList();
    }
    return _credentials.where((c) => c.folderId == folderId).toList();
  }

  List<Credential> _getCredentialsWithoutFolder() {
    if (_isSearching && _searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      return _credentials.where((credential) {
        final matchesFolder = credential.folderId == null;
        final matchesSearch = credential.title.toLowerCase().contains(query) ||
            credential.username.toLowerCase().contains(query) ||
            (credential.url?.toLowerCase().contains(query) ?? false);
        return matchesFolder && matchesSearch;
      }).toList();
    }
    return _credentials.where((c) => c.folderId == null).toList();
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Папку'),
              onTap: () => Navigator.pop(context, 'folder'),
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Учетную запись'),
              onTap: () => Navigator.pop(context, 'credential'),
            ),
          ],
        ),
      ),
    );

    if (result == 'folder') {
      final folderResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FolderEditPage(),
        ),
      );
      if (folderResult == true) {
        _loadData();
      }
    } else if (result == 'credential') {
      final credentialResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CredentialEditPage(
            initialFolderId: _selectedFolderId,
          ),
        ),
      );
      if (credentialResult == true) {
        _loadData();
      }
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить папку?'),
        content: Text('Вы уверены, что хотите удалить папку "${folder.name}"? Учетные записи из этой папки не будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && folder.id != null) {
      await _dbHelper.deleteFolder(folder.id!);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Папка удалена')),
        );
      }
    }
  }

  Future<void> _deleteCredential(Credential credential) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить учетную запись?'),
        content: Text('Вы уверены, что хотите удалить "${credential.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && credential.id != null) {
      await _dbHelper.deleteCredential(credential.id!);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Учетная запись удалена')),
        );
      }
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label скопирован в буфер обмена')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск...',
                  border: InputBorder.none,
                ),
                onChanged: _filterCredentials,
              )
            : const Text('Ключница'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filterCredentials('');
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    onThemeChanged: widget.onThemeChanged,
                    onLanguageChanged: widget.onLanguageChanged,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Список папок
          if (_folders.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _folders.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Кнопка "Все"
                    final isSelected = _selectedFolderId == null;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: const Text('Все'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFolderId = null;
                            _updateFilteredCredentials();
                            _searchController.clear();
                          });
                        },
                      ),
                    );
                  }
                  final folder = _folders[index - 1];
                  final isSelected = _selectedFolderId == folder.id;
                  final folderColor = folder.color != null
                      ? Color(int.parse(folder.color!.replaceFirst('#', ''), radix: 16))
                      : Colors.blue;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      avatar: CircleAvatar(
                        backgroundColor: folderColor,
                        radius: 12,
                        child: const Icon(Icons.folder, size: 16, color: Colors.white),
                      ),
                      label: Text(folder.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFolderId = selected ? folder.id : null;
                          _updateFilteredCredentials();
                          _searchController.clear();
                        });
                      },
                      deleteIcon: IconButton(
                        icon: const Icon(Icons.edit, size: 16),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FolderEditPage(folder: folder),
                            ),
                          );
                          if (result == true) {
                            _loadData();
                          }
                        },
                      ),
                      onDeleted: () => _deleteFolder(folder),
                    ),
                  );
                },
              ),
            ),
          // Список учетных записей
          Expanded(
            child: _selectedFolderId == null
                ? _buildAllView() // Режим "Все" с папками
                : _buildFolderView(), // Режим конкретной папки
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAllView() {
    final foldersWithCredentials = <Folder>[];
    
    for (var folder in _folders) {
      final folderCredentials = _getCredentialsForFolder(folder.id);
      if (folderCredentials.isNotEmpty || !_isSearching) {
        foldersWithCredentials.add(folder);
      }
    }
    
    final credentialsWithoutFolder = _getCredentialsWithoutFolder();
    final hasAnyData = foldersWithCredentials.isNotEmpty || credentialsWithoutFolder.isNotEmpty;
    
    if (!hasAnyData && _credentials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Нет сохраненных учетных записей',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView(
      children: [
        // Папки с учетными записями
        ...foldersWithCredentials.map((folder) => _FolderExpansionTile(
          folder: folder,
          credentials: _getCredentialsForFolder(folder.id),
          isExpanded: _expandedFolders[folder.id] ?? false,
          onExpansionChanged: (expanded) {
            if (folder.id != null) {
              setState(() {
                _expandedFolders[folder.id!] = expanded;
              });
            }
          },
          onCredentialTap: (credential) async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CredentialEditPage(
                  credential: credential,
                ),
              ),
            );
            if (result == true) {
              _loadData();
            }
          },
          onCredentialDelete: (credential) => _deleteCredential(credential),
          onCopyPassword: (credential) => _copyToClipboard(
            credential.password,
            'Пароль',
          ),
          onCopyUsername: (credential) => _copyToClipboard(
            credential.username,
            'Логин',
          ),
          onCopyCustomField: (value, key) => _copyToClipboard(
            value,
            key,
          ),
          onFolderEdit: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FolderEditPage(folder: folder),
              ),
            );
            if (result == true) {
              _loadData();
            }
          },
          onFolderDelete: () => _deleteFolder(folder),
        )),
        
        // Учетные записи без папок
        if (credentialsWithoutFolder.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Без папки',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ...credentialsWithoutFolder.map((credential) => _CredentialCard(
            credential: credential,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CredentialEditPage(
                    credential: credential,
                  ),
                ),
              );
              if (result == true) {
                _loadData();
              }
            },
            onDelete: () => _deleteCredential(credential),
            onCopyPassword: () => _copyToClipboard(
              credential.password,
              'Пароль',
            ),
            onCopyUsername: () => _copyToClipboard(
              credential.username,
              'Логин',
            ),
            onCopyCustomField: (value, key) => _copyToClipboard(
              value,
              key,
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildFolderView() {
    if (_filteredCredentials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Нет учетных записей в этой папке',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _filteredCredentials.length,
      itemBuilder: (context, index) {
        final credential = _filteredCredentials[index];
        return _CredentialCard(
          credential: credential,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CredentialEditPage(
                  credential: credential,
                ),
              ),
            );
            if (result == true) {
              _loadData();
            }
          },
          onDelete: () => _deleteCredential(credential),
          onCopyPassword: () => _copyToClipboard(
            credential.password,
            'Пароль',
          ),
          onCopyUsername: () => _copyToClipboard(
            credential.username,
            'Логин',
          ),
          onCopyCustomField: (value, key) => _copyToClipboard(
            value,
            key,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _FolderExpansionTile extends StatelessWidget {
  final Folder folder;
  final List<Credential> credentials;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<Credential> onCredentialTap;
  final ValueChanged<Credential> onCredentialDelete;
  final ValueChanged<Credential> onCopyPassword;
  final ValueChanged<Credential> onCopyUsername;
  final void Function(String value, String key) onCopyCustomField;
  final VoidCallback onFolderEdit;
  final VoidCallback onFolderDelete;

  const _FolderExpansionTile({
    required this.folder,
    required this.credentials,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onCredentialTap,
    required this.onCredentialDelete,
    required this.onCopyPassword,
    required this.onCopyUsername,
    required this.onCopyCustomField,
    required this.onFolderEdit,
    required this.onFolderDelete,
  });

  @override
  Widget build(BuildContext context) {
    final folderColor = folder.color != null
        ? Color(int.parse(folder.color!.replaceFirst('#', ''), radix: 16))
        : Colors.blue;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: folderColor,
          child: const Icon(Icons.folder, color: Colors.white),
        ),
        title: Text(folder.name),
        subtitle: Text('${credentials.length} ${_getCountText(credentials.length)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onFolderEdit,
              tooltip: 'Редактировать папку',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.red,
              onPressed: onFolderDelete,
              tooltip: 'Удалить папку',
            ),
          ],
        ),
        initiallyExpanded: isExpanded,
        onExpansionChanged: onExpansionChanged,
        children: credentials.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Нет учетных записей',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ]
            : credentials.map((credential) => Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: _CredentialCard(
                  credential: credential,
                  onTap: () => onCredentialTap(credential),
                  onDelete: () => onCredentialDelete(credential),
                  onCopyPassword: () => onCopyPassword(credential),
                  onCopyUsername: () => onCopyUsername(credential),
                  onCopyCustomField: (value, key) => onCopyCustomField(value, key),
                ),
              )).toList(),
      ),
    );
  }

  String _getCountText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'запись';
    } else if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'записи';
    } else {
      return 'записей';
    }
  }
}

class _CredentialCard extends StatefulWidget {
  final Credential credential;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onCopyPassword;
  final VoidCallback onCopyUsername;
  final void Function(String value, String key)? onCopyCustomField;

  const _CredentialCard({
    required this.credential,
    required this.onTap,
    required this.onDelete,
    required this.onCopyPassword,
    required this.onCopyUsername,
    this.onCopyCustomField,
  });

  @override
  State<_CredentialCard> createState() => _CredentialCardState();
}

class _CredentialCardState extends State<_CredentialCard> {
  bool _isPasswordVisible = false;
  final Map<String, bool> _customFieldPasswordVisible = {}; // Видимость паролей в кастомных полях

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.credential.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: widget.onDelete,
                    color: Colors.red,
                  ),
                ],
              ),
              if (widget.credential.url != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.credential.url!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.credential.username,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: widget.onCopyUsername,
                    tooltip: 'Копировать логин',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.lock, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isPasswordVisible
                          ? widget.credential.password
                          : '•' * widget.credential.password.length,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                    tooltip: _isPasswordVisible ? 'Скрыть пароль' : 'Показать пароль',
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: widget.onCopyPassword,
                    tooltip: 'Копировать пароль',
                  ),
                ],
              ),
              // Кастомные поля
              if (widget.credential.customFields.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                ...widget.credential.customFields.entries.map((entry) {
                  final fieldType = widget.credential.customFieldTypes[entry.key] ?? 'text';
                  final isPassword = fieldType == 'password';
                  final isVisible = _customFieldPasswordVisible[entry.key] ?? false;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          isPassword ? Icons.lock : Icons.label_outline,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${entry.key}: ${isPassword && !isVisible ? '•' * entry.value.length : entry.value}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        if (isPassword)
                          IconButton(
                            icon: Icon(
                              isVisible ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _customFieldPasswordVisible[entry.key] = !isVisible;
                              });
                            },
                            tooltip: isVisible ? 'Скрыть пароль' : 'Показать пароль',
                          ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: widget.onCopyCustomField != null
                              ? () => widget.onCopyCustomField!(entry.value, entry.key)
                              : null,
                          tooltip: 'Копировать ${entry.key}',
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

