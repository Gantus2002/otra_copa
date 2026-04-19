import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      _showSnackBar('Error cargando canchas');
    }
  }

  void _openForm({Map<String, dynamic>? venue}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminVenueFormPage(venue: venue),
      ),
    );

    await _loadVenues();
  }

  void _openCourts(Map<String, dynamic> venue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCourtsPage(venue: venue),
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> venue) async {
    try {
      final newValue = !(venue['is_active'] == true);

      await Supabase.instance.client
          .from('venues')
          .update({'is_active': newValue}).eq('id', venue['id']);

      await _loadVenues();
    } catch (e) {
      _showSnackBar('Error actualizando estado');
    }
  }

  Future<void> _deleteVenue(int id) async {
    try {
      await Supabase.instance.client.from('venues').delete().eq('id', id);

      await _loadVenues();
    } catch (e) {
      _showSnackBar('Error eliminando cancha');
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
                    final name = (venue['name'] ?? 'Sin nombre').toString();
                    final city = (venue['city'] ?? '').toString();
                    final active = venue['is_active'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.stadium_outlined,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '$city • ${active ? 'Activo' : 'Inactivo'}',
                        ),
                        onTap: () => _openCourts(venue),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _openForm(venue: venue);
                            } else if (value == 'toggle') {
                              _toggleActive(venue);
                            } else if (value == 'delete') {
                              _confirmDelete(venue['id'] as int, name);
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
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}