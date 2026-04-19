import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../admin/presentation/pages/admin_court_schedules_page.dart';

class VenueSchedulesSelectorPage extends StatefulWidget {
  final Map<String, dynamic> venue;

  const VenueSchedulesSelectorPage({
    super.key,
    required this.venue,
  });

  @override
  State<VenueSchedulesSelectorPage> createState() =>
      _VenueSchedulesSelectorPageState();
}

class _VenueSchedulesSelectorPageState
    extends State<VenueSchedulesSelectorPage> {
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
      _showSnackBar('Error cargando canchas');
    }
  }

  void _openSchedules(Map<String, dynamic> court) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCourtSchedulesPage(
          court: court,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueName = (widget.venue['name'] ?? 'Mi complejo').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('Horarios - $venueName'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : courts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Primero tenés que crear al menos una cancha.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: courts.map((court) {
                    final name = (court['name'] ?? 'Cancha').toString();
                    final sportType = (court['sport_type'] ?? '').toString();

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
                            Icons.schedule_outlined,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(sportType),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openSchedules(court),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}