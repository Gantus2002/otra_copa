import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../admin/presentation/pages/admin_courts_page.dart';
import '../../../admin/presentation/pages/admin_venue_form_page.dart';
import 'venue_calendar_page.dart';
import 'venue_reservations_page.dart';
import 'venue_schedules_selector_page.dart';

class VenueDashboardPage extends StatefulWidget {
  const VenueDashboardPage({super.key});

  @override
  State<VenueDashboardPage> createState() => _VenueDashboardPageState();
}

class _VenueDashboardPageState extends State<VenueDashboardPage> {
  bool isLoading = true;
  Map<String, dynamic>? myVenue;

  double todayRevenue = 0;
  double monthRevenue = 0;
  int todayConfirmedCount = 0;
  int pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMyVenueAndStats();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadMyVenueAndStats() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _safeSetState(() {
        isLoading = false;
      });
      return;
    }

    _safeSetState(() {
      isLoading = true;
    });

    try {
      final venueResponse = await Supabase.instance.client
          .from('venues')
          .select()
          .eq('owner_user_id', user.id)
          .maybeSingle();

      if (venueResponse == null) {
        _safeSetState(() {
          myVenue = null;
          todayRevenue = 0;
          monthRevenue = 0;
          todayConfirmedCount = 0;
          pendingCount = 0;
          isLoading = false;
        });
        return;
      }

      final venue = Map<String, dynamic>.from(venueResponse);
      final venueId = venue['id'];

      final reservationsResponse = await Supabase.instance.client
          .from('court_reservations')
          .select()
          .eq('venue_id', venueId);

      final reservations = List<Map<String, dynamic>>.from(reservationsResponse);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      double tempTodayRevenue = 0;
      double tempMonthRevenue = 0;
      int tempTodayConfirmedCount = 0;
      int tempPendingCount = 0;

      for (final reservation in reservations) {
        final status = (reservation['status'] ?? '').toString();
        final rawDate = (reservation['reservation_date'] ?? '').toString();
        final parsedDate = DateTime.tryParse(rawDate);
        final total = reservation['total_price'];

        final price = total is num ? total.toDouble() : 0.0;

        if (status == 'pending_payment') {
          tempPendingCount++;
        }

        if (parsedDate == null) continue;

        final reservationDay =
            DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

        if (status == 'confirmed') {
          if (reservationDay == today) {
            tempTodayRevenue += price;
            tempTodayConfirmedCount++;
          }

          if (!reservationDay.isBefore(monthStart)) {
            tempMonthRevenue += price;
          }
        }
      }

      _safeSetState(() {
        myVenue = venue;
        todayRevenue = tempTodayRevenue;
        monthRevenue = tempMonthRevenue;
        todayConfirmedCount = tempTodayConfirmedCount;
        pendingCount = tempPendingCount;
        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('Error cargando panel: $e');
    }
  }

  Future<void> _openCreateOrEditVenue() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminVenueFormPage(
          venue: myVenue,
          forcedOwnerUserId: user.id,
          lockOwnerToCurrentUser: true,
        ),
      ),
    );

    await _loadMyVenueAndStats();
  }

  Future<void> _openMyCourts() async {
    if (myVenue == null) {
      _showSnackBar('Primero creá tu complejo');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCourtsPage(
          venue: myVenue!,
          readOnlyToOwnerScope: true,
        ),
      ),
    );

    await _loadMyVenueAndStats();
  }

  Future<void> _openSchedules() async {
    if (myVenue == null) {
      _showSnackBar('Primero creá tu complejo');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueSchedulesSelectorPage(
          venue: myVenue!,
        ),
      ),
    );
  }

  Future<void> _openReservations() async {
    if (myVenue == null) {
      _showSnackBar('Primero creá tu complejo');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueReservationsPage(
          venue: myVenue!,
        ),
      ),
    );

    await _loadMyVenueAndStats();
  }

  Future<void> _openCalendar() async {
    if (myVenue == null) {
      _showSnackBar('Primero creá tu complejo');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueCalendarPage(
          venue: myVenue!,
        ),
      ),
    );

    await _loadMyVenueAndStats();
  }

  String _money(double value) {
    return 'Gs. ${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final venueName = (myVenue?['name'] ?? 'Administrá tu cancha').toString();
    final venueCity = (myVenue?['city'] ?? '').toString();
    final venueAddress = (myVenue?['address'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de cancha'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMyVenueAndStats,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primaryContainer,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venueName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          myVenue == null
                              ? 'Creá tu complejo y después cargá canchas, horarios y reservas.'
                              : (venueCity.isNotEmpty || venueAddress.isNotEmpty)
                                  ? '$venueCity${venueCity.isNotEmpty && venueAddress.isNotEmpty ? ' • ' : ''}$venueAddress'
                                  : 'Gestioná tu complejo, canchas, horarios y reservas.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.90),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (myVenue != null) ...[
                    if (pendingCount > 0) ...[
                      _PendingHighlightCard(
                        pendingCount: pendingCount,
                        onTap: _openReservations,
                      ),
                      const SizedBox(height: 20),
                    ],
                    _SectionTitle(
                      title: 'Resumen rápido',
                      subtitle: 'Lo más importante de tu complejo hoy',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Hoy',
                            value: _money(todayRevenue),
                            icon: Icons.payments_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Mes',
                            value: _money(monthRevenue),
                            icon: Icons.calendar_month_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Confirmadas hoy',
                            value: '$todayConfirmedCount',
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Pendientes',
                            value: '$pendingCount',
                            icon: Icons.schedule_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (myVenue == null) ...[
                    _SectionTitle(
                      title: 'Primer paso',
                      subtitle: 'Creá tu complejo para empezar a administrar',
                    ),
                    const SizedBox(height: 14),
                    _VenueActionTile(
                      icon: Icons.add_business_outlined,
                      title: 'Crear mi complejo',
                      subtitle:
                          'Nombre, ciudad, dirección, descripción y contacto',
                      onTap: _openCreateOrEditVenue,
                    ),
                  ] else ...[
                    _SectionTitle(
                      title: 'Gestión',
                      subtitle: 'Administrá todo lo relacionado a tu cancha',
                    ),
                    const SizedBox(height: 14),
                    _VenueActionTile(
                      icon: Icons.storefront_outlined,
                      title: 'Mi complejo',
                      subtitle: 'Editar datos principales del complejo',
                      onTap: _openCreateOrEditVenue,
                    ),
                    const SizedBox(height: 12),
                    _VenueActionTile(
                      icon: Icons.sports_soccer_outlined,
                      title: 'Mis canchas',
                      subtitle: 'Crear y editar las canchas de tu complejo',
                      onTap: _openMyCourts,
                    ),
                    const SizedBox(height: 12),
                    _VenueActionTile(
                      icon: Icons.schedule_outlined,
                      title: 'Horarios',
                      subtitle: 'Definir disponibilidad y horarios base',
                      onTap: _openSchedules,
                    ),
                    const SizedBox(height: 12),
                    _VenueActionTile(
                      icon: Icons.receipt_long_outlined,
                      title: pendingCount > 0
                          ? 'Reservas pendientes ($pendingCount)'
                          : 'Reservas',
                      subtitle: pendingCount > 0
                          ? 'Entrá para confirmar o cancelar pagos pendientes'
                          : 'Ver reservas, pagos y confirmaciones',
                      onTap: _openReservations,
                      highlighted: pendingCount > 0,
                    ),
                    const SizedBox(height: 12),
                    _VenueActionTile(
                      icon: Icons.calendar_month_outlined,
                      title: 'Calendario',
                      subtitle: 'Ver ocupación de canchas por día',
                      onTap: _openCalendar,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PendingHighlightCard extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onTap;

  const _PendingHighlightCard({
    required this.pendingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.orange.withOpacity(0.10),
            border: Border.all(
              color: Colors.orange.withOpacity(0.25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tenés $pendingCount reservas pendientes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Entrá para confirmarlas o cancelarlas.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  const _VenueActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final borderColor = highlighted
        ? Colors.orange.withOpacity(0.28)
        : theme.colorScheme.outlineVariant.withOpacity(0.22);

    final backgroundColor = highlighted
        ? Colors.orange.withOpacity(0.06)
        : theme.colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: backgroundColor,
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: highlighted
                ? Colors.orange.withOpacity(0.15)
                : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: highlighted
                ? Colors.orange
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}