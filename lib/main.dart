import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabasePublishableKey,
  );

  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('is_dark_mode') ?? false;
  final selectedCity = prefs.getString('selected_city') ?? 'Asunción';

  runApp(
    OtraCopaRoot(
      initialThemeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialCity: selectedCity,
    ),
  );
}

class OtraCopaRoot extends StatefulWidget {
  final ThemeMode initialThemeMode;
  final String initialCity;

  const OtraCopaRoot({
    super.key,
    required this.initialThemeMode,
    required this.initialCity,
  });

  @override
  State<OtraCopaRoot> createState() => _OtraCopaRootState();
}

class _OtraCopaRootState extends State<OtraCopaRoot> {
  late ThemeMode _themeMode;
  late String _selectedCity;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    _selectedCity = widget.initialCity;
  }

  Future<void> _toggleDarkMode(bool isDark) async {
    final newThemeMode = isDark ? ThemeMode.dark : ThemeMode.light;

    setState(() {
      _themeMode = newThemeMode;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
  }

  Future<void> _changeCity(String city) async {
    setState(() {
      _selectedCity = city;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_city', city);
  }

  @override
  Widget build(BuildContext context) {
    return OtraCopaApp(
      themeMode: _themeMode,
      onThemeChanged: _toggleDarkMode,
      selectedCity: _selectedCity,
      onCityChanged: _changeCity,
    );
  }
}