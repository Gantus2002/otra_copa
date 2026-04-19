import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_court_form_page.dart';
import 'admin_court_schedules_page.dart';

class AdminCourtsPage extends StatefulWidget {
  final Map<String, dynamic> venue;
  final bool readOnlyToOwnerScope;

  const AdminCourtsPage({
    super.key,
    required this.venue,
    this.readOnlyToOwnerScope = false,
  });

  @override
  State<AdminCourtsPage> createState() => _AdminCourtsPageState();
}

class _AdminCourtsPageState extends State<AdminCourtsPage> {
  List<Map<String, dynamic>> courts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourts();
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

  Future<void> _loadCourts() async {
    _safeSetState(() {
      isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('courts')
          .select()
          .eq('venue_id', widget.venue['id'])
          .order('id', ascending: false);

      _safeSetState(() {
        courts = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('Error cargando canchas: $e');
    }
  }

  void _openForm({Map<String, dynamic>? court}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCourtFormPage(
          venue: widget.venue,
          court: court,
        ),
      ),
    );

    await _loadCourts();
  }

  void _openSchedules(Map<String, dynamic> court) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCourtSchedulesPage(
          court: court,
        ),
      ),
    );

    await _loadCourts();
  }

  Future<void> _toggleActive(Map<String, dynamic> court) async {
    try {
      final newValue = !(court['is_active'] == true);

      await Supabase.instance.client
          .from('courts')
          .update({'is_active': newValue}).eq('id', court['id']);

      await _loadCourts();
    } catch (e) {
      _showSnackBar('Error actualizando cancha: $e');
    }
  }

  Future<void> _deleteCourt(int id) async {
    try {
      await Supabase.instance.client.from('courts').delete().eq('id', id);

      await _loadCourts();
      _showSnackBar('Cancha eliminada');
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
      await _deleteCourt(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueName = (widget.venue['name'] ?? 'Complejo').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('Canchas de $venueName'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : courts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay canchas cargadas en este complejo.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: courts.map((court) {
                    final name = (court['name'] ?? 'Sin nombre').toString();
                    final sportType = (court['sport_type'] ?? '').toString();
                    final active = court['is_active'] == true;

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
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.sports_soccer_outlined,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
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
                                      const SizedBox(height: 2),
                                      Text(
                                        '$sportType • ${active ? 'Activa' : 'Inactiva'}',
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openForm(court: court);
                                    } else if (value == 'toggle') {
                                      _toggleActive(court);
                                    } else if (value == 'delete') {
                                      _confirmDelete(court['id'] as int, name);
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
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openSchedules(court),
                                    icon: const Icon(Icons.schedule_outlined),
                                    label: const Text('Horarios'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openForm(court: court),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Editar'),
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