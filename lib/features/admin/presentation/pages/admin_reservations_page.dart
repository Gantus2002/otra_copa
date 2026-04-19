import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReservationsPage extends StatefulWidget {
  const AdminReservationsPage({super.key});

  @override
  State<AdminReservationsPage> createState() => _AdminReservationsPageState();
}

class _AdminReservationsPageState extends State<AdminReservationsPage> {
  List<Map<String, dynamic>> reservations = [];
  bool isLoading = true;
  String selectedFilter = 'today';

  @override
  void initState() {
    super.initState();
    _loadReservations();
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

  Future<void> _loadReservations() async {
    _safeSetState(() => isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('court_reservations')
          .select(
            '*, courts(name), venues(name), profiles!court_reservations_user_id_fkey(full_name)',
          )
          .order('reservation_date', ascending: true)
          .order('start_time', ascending: true);

      _safeSetState(() {
        reservations = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() => isLoading = false);
      _showSnackBar('Error cargando reservas: $e');
    }
  }

  Future<void> _updateStatus({
    required int id,
    required String status,
    String? paymentStatus,
  }) async {
    try {
      final data = <String, dynamic>{
        'status': status,
      };

      if (paymentStatus != null) {
        data['payment_status'] = paymentStatus;
      }

      await Supabase.instance.client
          .from('court_reservations')
          .update(data)
          .eq('id', id);

      await _loadReservations();
      _showSnackBar('Reserva actualizada');
    } catch (e) {
      _showSnackBar('Error actualizando reserva: $e');
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmada';
      case 'cancelled':
        return 'Cancelada';
      case 'expired':
        return 'Expirada';
      case 'pending_payment':
      default:
        return 'Pendiente';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      case 'pending_payment':
      default:
        return Colors.orange;
    }
  }

  String _shortTime(String text) {
    if (text.length >= 5) return text.substring(0, 5);
    return text;
  }

  String _formatDate(String date) {
    final p = date.split('-');
    if (p.length == 3) {
      return '${p[2]}/${p[1]}/${p[0]}';
    }
    return date;
  }

  Widget _filterButton(String text, String value) {
    final selected = selectedFilter == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _safeSetState(() {
            selectedFilter = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.teal : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filteredReservations() {
    return reservations.where((r) {
      if (selectedFilter == 'all') return true;

      final date = DateTime.tryParse((r['reservation_date'] ?? '').toString());
      if (date == null) return false;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final reservationDay = DateTime(date.year, date.month, date.day);

      if (selectedFilter == 'today') {
        return reservationDay == today;
      }

      if (selectedFilter == 'tomorrow') {
        return reservationDay == tomorrow;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReservations();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Reservas'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      _filterButton('Hoy', 'today'),
                      const SizedBox(width: 8),
                      _filterButton('Mañana', 'tomorrow'),
                      const SizedBox(width: 8),
                      _filterButton('Todas', 'all'),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('No hay reservas para este filtro'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final r = filtered[index];

                            final court =
                                (r['courts']?['name'] ?? 'Cancha').toString();
                            final venue =
                                (r['venues']?['name'] ?? 'Complejo').toString();
                            final user = (r['profiles']?['full_name'] ?? 'Jugador')
                                .toString();

                            final date =
                                _formatDate((r['reservation_date'] ?? '').toString());
                            final start =
                                _shortTime((r['start_time'] ?? '').toString());
                            final end =
                                _shortTime((r['end_time'] ?? '').toString());
                            final status = (r['status'] ?? '').toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: Theme.of(context).colorScheme.surface,
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withOpacity(0.22),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      court,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(venue),
                                    Text(user),
                                    const SizedBox(height: 10),
                                    Text('$date • $start - $end'),
                                    const SizedBox(height: 10),
                                    Text(
                                      _statusText(status),
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    if (status == 'pending_payment')
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _updateStatus(
                                                id: r['id'] as int,
                                                status: 'confirmed',
                                                paymentStatus: 'verified',
                                              ),
                                              child: const Text('Confirmar'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => _updateStatus(
                                                id: r['id'] as int,
                                                status: 'cancelled',
                                                paymentStatus: 'rejected',
                                              ),
                                              child: const Text('Cancelar'),
                                            ),
                                          ),
                                        ],
                                      )
                                    else if (status == 'confirmed')
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: () => _updateStatus(
                                            id: r['id'] as int,
                                            status: 'cancelled',
                                            paymentStatus: 'rejected',
                                          ),
                                          child: const Text('Cancelar reserva'),
                                        ),
                                      )
                                    else if (status == 'cancelled')
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () => _updateStatus(
                                            id: r['id'] as int,
                                            status: 'confirmed',
                                            paymentStatus: 'verified',
                                          ),
                                          child: const Text('Confirmar de nuevo'),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}