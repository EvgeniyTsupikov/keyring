import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/database_helper.dart';

class SettingsPage extends StatefulWidget {
  final ValueChanged<bool>? onThemeChanged;
  final ValueChanged<Locale>? onLanguageChanged;

  const SettingsPage({super.key, this.onThemeChanged, this.onLanguageChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkMode = false;
  String _currentLanguage = 'ru';
  Map<String, int> _statistics = {
    'credentials': 0,
    'folders': 0,
    'sites': 0,
  };
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadStatistics();
    _loadAppVersion();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkTheme') ?? false;
      _currentLanguage = prefs.getString('languageCode') ?? 'ru';
    });
  }

  Future<void> _loadStatistics() async {
    final dbHelper = DatabaseHelper();
    final stats = await dbHelper.getStatistics();
    setState(() {
      _statistics = stats;
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      // Если не удалось получить версию, используем версию из pubspec.yaml
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', value);
    widget.onThemeChanged?.call(value);
  }

  Future<void> _changeLanguage(String languageCode) async {
    setState(() {
      _currentLanguage = languageCode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', languageCode);
    final locale = Locale(languageCode);
    widget.onLanguageChanged?.call(locale);
  }

  @override
  Widget build(BuildContext context) {
    final isRussian = _currentLanguage == 'ru';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isRussian ? 'Настройки' : 'Settings'),
      ),
      body: ListView(
        children: [
          // Тема
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text(isRussian ? 'Тема' : 'Theme'),
            subtitle: Text(_isDarkMode 
                ? (isRussian ? 'Темная' : 'Dark')
                : (isRussian ? 'Светлая' : 'Light')),
            trailing: Switch(
              value: _isDarkMode,
              onChanged: _toggleTheme,
            ),
          ),
          const Divider(),
          
          // Язык
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(isRussian ? 'Язык' : 'Language'),
            subtitle: Text(_currentLanguage == 'ru' ? 'Русский' : 'English'),
            trailing: DropdownButton<String>(
              value: _currentLanguage,
              items: const [
                DropdownMenuItem(
                  value: 'ru',
                  child: Text('Русский'),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text('English'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _changeLanguage(value);
                }
              },
            ),
          ),
          const Divider(),
          
          // Статистика
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRussian ? 'Статистика' : 'Statistics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _StatisticItem(
                  icon: Icons.lock,
                  label: isRussian ? 'Учетных записей' : 'Credentials',
                  value: _statistics['credentials']?.toString() ?? '0',
                ),
                const SizedBox(height: 8),
                _StatisticItem(
                  icon: Icons.folder,
                  label: isRussian ? 'Папок' : 'Folders',
                  value: _statistics['folders']?.toString() ?? '0',
                ),
                const SizedBox(height: 8),
                _StatisticItem(
                  icon: Icons.link,
                  label: isRussian ? 'Сайтов' : 'Sites',
                  value: _statistics['sites']?.toString() ?? '0',
                ),
              ],
            ),
          ),
          const Divider(),
          
          // О приложении
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(isRussian ? 'О приложении' : 'About'),
            subtitle: Text(isRussian 
                ? 'Версия $_appVersion'
                : 'Version $_appVersion'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: isRussian ? 'Ключница' : 'Keyring',
                applicationVersion: _appVersion,
                applicationIcon: const Icon(Icons.lock, size: 48),
                children: [
                  Text(isRussian 
                      ? 'Приложение для безопасного хранения логинов и паролей.'
                      : 'Application for secure storage of usernames and passwords.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatisticItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatisticItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }
}
