import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../venue/presentation/pages/venue_calendar_page.dart';
import 'admin_courts_page.dart';
import 'admin_venue_form_page.dart';

class AdminVenuesPage extends StatefulWidget {
  const AdminVenuesPage({super.key});

  @override
  State<AdminVenuesPage> createState() => _AdminVenuesPageState();
}

class _AdminVenuesPageState extends State<AdminVenuesPage> {
  List<Map<String, dynamic>> venues = [];
  bool isLoading = true;
  final Set<int> togglingVenueIds = {};

  @override
  void initState() {
    super.initState();
    _loadVenues();
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

  Future<void> _loadVenues() async {
    _safeSetState(() {
      isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('venues')
          .select()
          .order('id', ascending: false);

      _safeSetState(() {
        venues = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('Error cargando canchas: $e');
    }
  }

  Future<void> _openForm({Map<String, dynamic>? venue}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminVenueFormPage(venue: venue),
      ),
    );

    await _loadVenues();
  }

  Future<void> _openCourts(Map<String, dynamic> venue) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCourtsPage(venue: venue),
      ),
    );

    await _loadVenues();
  }

  Future<void> _openCalendar(Map<String, dynamic> venue) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueCalendarPage(venue: venue),
      ),
    );

    await _loadVenues();
  }

  Future<void> _toggleActive(Map<String, dynamic> venue) async {
    final int venueId = venue['id'] as int;
    final bool currentValue = venue['is_active'] == true;
    final bool newValue = !currentValue;

    _safeSetState(() {
      togglingVenueIds.add(venueId);
    });

    try {
      await Supabase.instance.client
          .from('venues')
          .update({'is_active': newValue})
          .eq('id', venueId);

      _safeSetState(() {
        final index = venues.indexWhere((v) => v['id'] == venueId);
        if (index != -1) {
          venues[index] = {
            ...venues[index],
            'is_active': newValue,
          };
        }
      });

      _showSnackBar(
        newValue ? 'Complejo activado' : 'Complejo desactivado',
      );
    } catch (e) {
      _showSnackBar('Error actualizando estado: $e');
    } finally {
      _safeSetState(() {
        togglingVenueIds.remove(venueId);
      });
    }
  }

  Future<void> _deleteVenue(int id) async {
    try {
      await Supabase.instance.client
          .from('venues')
          .delete()
          .eq('id', id);

      await _loadVenues();
      _showSnackBar('Complejo eliminado');
    } catch (e) {
      _showSnackBar('Error eliminando cancha: $e');
    }
  }

  Future<void> _confirmDelete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cancha'),
        content: Text('¿Seguro que querés eliminar "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteVenue(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar canchas'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : venues.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay complejos cargados.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: venues.map((venue) {
                    final int venueId = venue['id'] as int;
                    final name = (venue['name'] ?? 'Sin nombre').toString();
                    final city = (venue['city'] ?? '').toString();
                    final active = venue['is_active'] == true;
                    final isToggling = togglingVenueIds.contains(venueId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
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
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.stadium_outlined,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _openCourts(venue),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$city • ${active ? 'Activo' : 'Inactivo'}',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openForm(venue: venue);
                                    } else if (value == 'toggle') {
                                      _toggleActive(venue);
                                    } else if (value == 'delete') {
                                      _confirmDelete(venueId, name);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(active ? 'Desactivar' : 'Activar'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _VenueQuickAction(
                                    icon: Icons.sports_soccer_outlined,
                                    label: 'Canchas',
                                    onTap: () => _openCourts(venue),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _VenueQuickAction(
                                    icon: Icons.calendar_month_outlined,
                                    label: 'Calendario',
                                    onTap: () => _openCalendar(venue),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _VenueQuickAction(
                                    icon: Icons.edit_outlined,
                                    label: 'Editar',
                                    filled: true,
                                    onTap: () => _openForm(venue: venue),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _VenueQuickAction(
                                    icon: active
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    label: isToggling
                                        ? 'Cambiando...'
                                        : active
                                            ? 'Desactivar'
                                            : 'Activar',
                                    onTap: isToggling ? null : () => _toggleActive(venue),
                                    trailingLoader: isToggling,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}

class _VenueQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool trailingLoader;

  const _VenueQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.trailingLoader = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final backgroundColor =
        filled ? theme.colorScheme.primaryContainer : theme.colorScheme.surface;
    final borderColor = filled
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.outlineVariant.withOpacity(0.35);
    final foregroundColor =
        filled ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: backgroundColor,
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (trailingLoader)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            else
              Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}