import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../admin/presentation/pages/admin_courts_page.dart';
import '../../../admin/presentation/pages/admin_venue_form_page.dart';
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

  @override
  void initState() {
    super.initState();
    _loadMyVenue();
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

  Future<void> _loadMyVenue() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _safeSetState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('venues')
          .select()
          .eq('owner_user_id', user.id)
          .maybeSingle();

      _safeSetState(() {
        myVenue = response == null ? null : Map<String, dynamic>.from(response);
        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('Error cargando tu complejo');
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

    await _loadMyVenue();
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

    await _loadMyVenue();
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

  void _openReservations() {
    if (myVenue == null) {
      _showSnackBar('Primero creá tu complejo');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueReservationsPage(
          venue: myVenue!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de cancha'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMyVenue,
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
                          myVenue == null
                              ? 'Administrá tu cancha'
                              : (myVenue!['name'] ?? 'Mi complejo').toString(),
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
                              : ((myVenue!['city'] ?? '').toString().isNotEmpty
                                  ? '${(myVenue!['city'] ?? '').toString()} • ${(myVenue!['address'] ?? '').toString()}'
                                  : 'Gestioná tu complejo, canchas y horarios'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.90),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (myVenue == null) ...[
                    _VenueSectionTitle(
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
                    _VenueSectionTitle(
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
                      title: 'Reservas',
                      subtitle: 'Ver reservas, pagos y confirmaciones',
                      onTap: _openReservations,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _VenueSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _VenueSectionTitle({
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

class _VenueActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _VenueActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.onPrimaryContainer,
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