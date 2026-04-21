import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/update_password_page.dart';
import '../features/navigation/presentation/pages/main_navigation_page.dart';
import 'theme/app_theme.dart';

class OtraCopaApp extends StatefulWidget {
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
  State<OtraCopaApp> createState() => _OtraCopaAppState();
}

class _OtraCopaAppState extends State<OtraCopaApp> {
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.themeMode == ThemeMode.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Otra Copa',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: widget.themeMode,

      home: StreamBuilder<AuthState>(
        stream: _authStream,
        builder: (context, snapshot) {
          final session = Supabase.instance.client.auth.currentSession;

          // 🔥 CASO: reset password (clave)
          if (snapshot.hasData &&
              snapshot.data!.event == AuthChangeEvent.passwordRecovery) {
            return UpdatePasswordPage(
              isDarkMode: isDarkMode,
              onThemeChanged: widget.onThemeChanged,
              selectedCity: widget.selectedCity,
              onCityChanged: widget.onCityChanged,
            );
          }

          // usuario no logueado
          if (session == null) {
            return LoginPage(
              isDarkMode: isDarkMode,
              onThemeChanged: widget.onThemeChanged,
              selectedCity: widget.selectedCity,
              onCityChanged: widget.onCityChanged,
            );
          }

          // usuario logueado
          return MainNavigationPage(
            isDarkMode: isDarkMode,
            onThemeChanged: widget.onThemeChanged,
            selectedCity: widget.selectedCity,
            onCityChanged: widget.onCityChanged,
          );
        },
      ),
    );
  }
}