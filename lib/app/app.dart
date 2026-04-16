import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/navigation/presentation/pages/main_navigation_page.dart';
import 'theme/app_theme.dart';

class OtraCopaApp extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<bool> onThemeChanged;
  final String selectedCity;
  final ValueChanged<String> onCityChanged;

  const OtraCopaApp({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.selectedCity,
    required this.onCityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final isDarkMode = themeMode == ThemeMode.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Otra Copa',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: session == null
          ? LoginPage(
              isDarkMode: isDarkMode,
              onThemeChanged: onThemeChanged,
              selectedCity: selectedCity,
              onCityChanged: onCityChanged,
            )
          : MainNavigationPage(
              isDarkMode: isDarkMode,
              onThemeChanged: onThemeChanged,
              selectedCity: selectedCity,
              onCityChanged: onCityChanged,
            ),
    );
  }
}