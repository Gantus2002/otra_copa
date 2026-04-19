import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCourtSchedulesPage extends StatefulWidget {
  final Map<String, dynamic> court;

  const AdminCourtSchedulesPage({
    super.key,
    required this.court,
  });

  @override
  State<AdminCourtSchedulesPage> createState() =>
      _AdminCourtSchedulesPageState();
}

class _AdminCourtSchedulesPageState extends State<AdminCourtSchedulesPage> {
  List<Map<String, dynamic>> rules = [];
  bool isLoading = true;

  final List<_DayOption> days = const [
    _DayOption(value: 1, label: 'Lunes'),
    _DayOption(value: 2, label: 'Martes'),
    _DayOption(value: 3, label: 'Miércoles'),
    _DayOption(value: 4, label: 'Jueves'),
    _DayOption(value: 5, label: 'Viernes'),
    _DayOption(value: 6, label: 'Sábado'),
    _DayOption(value: 0, label: 'Domingo'),
  ];

  @override
  void initState() {
    super.initState();
    _loadRules();
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

  Future<void> _loadRules() async {
    _safeSetState(() {
      isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('court_availability_rules')
          .select()
          .eq('court_id', widget.court['id'])
          .order('day_of_week', ascending: true)
          .order('start_time', ascending: true);

      _safeSetState(() {
        rules = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('Error cargando horarios');
    }
  }

  String _dayLabel(int value) {
    return days.firstWhere((d) => d.value == value).label;
  }

  Future<void> _createRule() async {
    int selectedDay = 1;
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 23, minute: 0);

    final created = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> pickStart() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: startTime,
              );
              if (picked != null) {
                setLocalState(() {
                  startTime = picked;
                });
              }
            }

            Future<void> pickEnd() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: endTime,
              );
              if (picked != null) {
                setLocalState(() {
                  endTime = picked;
                });
              }
            }

            return AlertDialog(
              title: const Text('Nuevo horario'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedDay,
                    decoration: const InputDecoration(
                      labelText: 'Día',
                    ),
                    items: days
                        .map(
                          (day) => DropdownMenuItem<int>(
                            value: day.value,
                            child: Text(day.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setLocalState(() {
                          selectedDay = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Hora desde'),
                    subtitle: Text(_formatTimeOfDay(startTime)),
                    onTap: pickStart,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Hora hasta'),
                    subtitle: Text(_formatTimeOfDay(endTime)),
                    onTap: pickEnd,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true) return;

    final start = _formatTimeForDb(startTime);
    final end = _formatTimeForDb(endTime);

    if (start.compareTo(end) >= 0) {
      _showSnackBar('La hora de inicio debe ser menor que la hora de fin');
      return;
    }

    try {
      await Supabase.instance.client.from('court_availability_rules').insert({
        'court_id': widget.court['id'],
        'day_of_week': selectedDay,
        'start_time': start,
        'end_time': end,
        'is_active': true,
      });

      await _loadRules();
      _showSnackBar('Horario guardado');
    } catch (e) {
      _showSnackBar('Error guardando horario: $e');
    }
  }

  Future<void> _toggleRule(Map<String, dynamic> rule) async {
    try {
      final newValue = !(rule['is_active'] == true);

      await Supabase.instance.client
          .from('court_availability_rules')
          .update({'is_active': newValue}).eq('id', rule['id']);

      await _loadRules();
    } catch (e) {
      _showSnackBar('Error actualizando horario');
    }
  }

  Future<void> _deleteRule(int id) async {
    try {
      await Supabase.instance.client
          .from('court_availability_rules')
          .delete()
          .eq('id', id);

      await _loadRules();
    } catch (e) {
      _showSnackBar('Error eliminando horario');
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatTimeForDb(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  String _shortTime(dynamic raw) {
    final text = (raw ?? '').toString();
    if (text.length >= 5) return text.substring(0, 5);
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courtName = (widget.court['name'] ?? 'Cancha').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('Horarios - $courtName'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createRule,
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : rules.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay horarios cargados para esta cancha.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: rules.map((rule) {
                    final day = _dayLabel((rule['day_of_week'] ?? 0) as int);
                    final start = _shortTime(rule['start_time']);
                    final end = _shortTime(rule['end_time']);
                    final active = rule['is_active'] == true;

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
                          day,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '$start - $end • ${active ? 'Activo' : 'Inactivo'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'toggle') {
                              _toggleRule(rule);
                            } else if (value == 'delete') {
                              _deleteRule(rule['id'] as int);
                            }
                          },
                          itemBuilder: (_) => [
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

class _DayOption {
  final int value;
  final String label;

  const _DayOption({
    required this.value,
    required this.label,
  });
}