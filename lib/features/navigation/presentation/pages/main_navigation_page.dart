import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../home/presentation/pages/home_page.dart';
import '../../../my_tournaments/presentation/pages/my_tournaments_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../tournaments/presentation/pages/tournaments_page.dart';

class MainNavigationPage extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final String selectedCity;
  final ValueChanged<String> onCityChanged;

  const MainNavigationPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.selectedCity,
    required this.onCityChanged,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  List<Widget> _buildPages() {
    return [
      HomePage(
        selectedCity: widget.selectedCity,
        onCityChanged: widget.onCityChanged,
      ),
      TournamentsPage(
        selectedCity: widget.selectedCity,
      ),
      const MyTournamentsPage(),
      ProfilePage(
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = _buildPages();

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 14,
                  sigmaY: 14,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.18),
                    ),
                  ),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      height: 76,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      indicatorColor:
                          theme.colorScheme.primaryContainer.withOpacity(0.92),
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        final selected = states.contains(WidgetState.selected);

                        return TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                          letterSpacing: -0.1,
                        );
                      }),
                      iconTheme: WidgetStateProperty.resolveWith((states) {
                        final selected = states.contains(WidgetState.selected);

                        return IconThemeData(
                          size: selected ? 25 : 23,
                          color: selected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        );
                      }),
                    ),
                    child: NavigationBar(
                      selectedIndex: _currentIndex,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      animationDuration: const Duration(milliseconds: 500),
                      onDestinationSelected: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: 'Inicio',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.emoji_events_outlined),
                          selectedIcon: Icon(Icons.emoji_events_rounded),
                          label: 'Torneos',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.list_alt_outlined),
                          selectedIcon: Icon(Icons.list_alt_rounded),
                          label: 'Mis torneos',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person_rounded),
                          label: 'Perfil',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}