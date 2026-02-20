import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/encryption_service.dart';
import 'services/database_helper.dart';
import 'pages/keyring_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация Hive
  await Hive.initFlutter();
  
  // Инициализация базы данных
  final dbHelper = DatabaseHelper();
  await dbHelper.init();
  
  // Инициализация сервиса шифрования
  await EncryptionService().initialize();
  
  // Загрузка настроек
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkTheme') ?? false;
  final languageCode = prefs.getString('languageCode') ?? 'ru';
  
  runApp(MyApp(
    initialDark: isDark,
    initialLocale: Locale(languageCode),
  ));
}

class MyApp extends StatefulWidget {
  final bool initialDark;
  final Locale initialLocale;
  
  const MyApp({super.key, required this.initialDark, required this.initialLocale});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDark;
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _isDark = widget.initialDark;
    _locale = widget.initialLocale;
  }

  void _toggleTheme(bool dark) {
    setState(() {
      _isDark = dark;
    });
  }

  void _changeLanguage(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _locale.languageCode == 'ru' ? 'Ключница' : 'Keyring',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      locale: _locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', ''),
        Locale('en', ''),
      ],
      home: KeyRingPage(
        onThemeChanged: _toggleTheme,
        onLanguageChanged: _changeLanguage,
        currentLocale: _locale,
      ),
    );
  }
}
