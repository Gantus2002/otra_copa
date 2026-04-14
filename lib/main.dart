import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabasePublishableKey,
  );

  runApp(const OtraCopaRoot());
}

class OtraCopaRoot extends StatefulWidget {
  const OtraCopaRoot({super.key});

  @override
  State<OtraCopaRoot> createState() => _OtraCopaRootState();
}

class _OtraCopaRootState extends State<OtraCopaRoot> {
  ThemeMode _themeMode = ThemeMode.light;
  String _selectedCity = 'Asunción';

  void _toggleDarkMode(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _changeCity(String city) {
    setState(() {
      _selectedCity = city;
    });
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