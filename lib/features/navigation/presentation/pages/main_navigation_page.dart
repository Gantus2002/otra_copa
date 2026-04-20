import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../courts/presentation/pages/courts_page.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../reservations/presentation/pages/my_reservations_page.dart';
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

class _MainNavigationPageState extends State<MainNavigationPage>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _pendingReservationsCount = 0;

  Timer? _badgeTimer;
  bool _isLoadingBadge = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadPendingReservationsCount();

    _badgeTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadPendingReservationsCount();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _badgeTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPendingReservationsCount();
    }
  }

  Future<void> _loadPendingReservationsCount() async {
    if (_isLoadingBadge) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _pendingReservationsCount = 0;
      });
      return;
    }

    _isLoadingBadge = true;

    try {
      final response = await Supabase.instance.client
          .from('court_reservations')
          .select('id, status, expires_at')
          .eq('user_id', user.id)
          .eq('status', 'pending_payment');

      final rows = List<Map<String, dynamic>>.from(response);

      int validPending = 0;

      for (final row in rows) {
        final expiresAtRaw = row['expires_at'];
        final expiresAt = expiresAtRaw != null
            ? DateTime.tryParse(expiresAtRaw.toString())
            : null;

        final expired =
            expiresAt != null && expiresAt.isBefore(DateTime.now());

        if (!expired) {
          validPending++;
        }
      }

      if (!mounted) return;

      setState(() {
        _pendingReservationsCount = validPending;
      });
    } catch (_) {
    } finally {
      _isLoadingBadge = false;
    }
  }

  List<Widget> _buildPages() {
    return [
      HomePage(
        selectedCity: widget.selectedCity,
        onCityChanged: widget.onCityChanged,
      ),
      TournamentsPage(
        selectedCity: widget.selectedCity,
      ),
      CourtsPage(
        selectedCity: widget.selectedCity,
      ),
      const MyReservationsPage(),
      ProfilePage(
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];
  }

  Widget _navIconWithBadge({
    required IconData icon,
    required bool selected,
    required int badgeCount,
  }) {
    final baseIcon = Icon(
      icon,
      size: selected ? 25 : 23,
    );

    if (badgeCount <= 0) {
      return baseIcon;
    }

    final badgeText = badgeCount > 9 ? '9+' : '$badgeCount';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        baseIcon,
        Positioned(
          right: -8,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white,
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
                      onDestinationSelected: (index) async {
                        setState(() {
                          _currentIndex = index;
                        });

                        await _loadPendingReservationsCount();
                      },
                      destinations: [
                        const NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: 'Inicio',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.emoji_events_outlined),
                          selectedIcon: Icon(Icons.emoji_events_rounded),
                          label: 'Torneos',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.stadium_outlined),
                          selectedIcon: Icon(Icons.stadium_rounded),
                          label: 'Canchas',
                        ),
                        NavigationDestination(
                          icon: _navIconWithBadge(
                            icon: Icons.receipt_long_outlined,
                            selected: false,
                            badgeCount: _pendingReservationsCount,
                          ),
                          selectedIcon: _navIconWithBadge(
                            icon: Icons.receipt_long_rounded,
                            selected: true,
                            badgeCount: _pendingReservationsCount,
                          ),
                          label: 'Reservas',
                        ),
                        const NavigationDestination(
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