import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class VenueReservationsPage extends StatefulWidget {
  final Map<String, dynamic> venue;

  const VenueReservationsPage({
    super.key,
    required this.venue,
  });

  @override
  State<VenueReservationsPage> createState() => _VenueReservationsPageState();
}

class _VenueReservationsPageState extends State<VenueReservationsPage> {
  List<Map<String, dynamic>> reservations = [];
  bool isLoading = true;

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

  Future<void> _expireOldReservations() async {
    try {
      await Supabase.instance.client
          .from('court_reservations')
          .update({
            'status': 'expired',
          })
          .eq('status', 'pending_payment')
          .lt('expires_at', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> _loadReservations() async {
    _safeSetState(() {
      isLoading = true;
    });

    try {
      await _expireOldReservations();

      final response = await Supabase.instance.client
          .from('court_reservations')
          .select(
            '*, courts(name), profiles!court_reservations_user_id_fkey(full_name, avatar_url, phone)',
          )
          .eq('venue_id', widget.venue['id'])
          .order('reservation_date', ascending: true)
          .order('start_time', ascending: true);

      _safeSetState(() {
        reservations = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('Error cargando reservas: $e');
    }
  }

  Future<void> _updateReservation({
    required int reservationId,
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
          .eq('id', reservationId);

      await _loadReservations();
      _showSnackBar('Reserva actualizada');
    } catch (e) {
      _showSnackBar('Error actualizando reserva: $e');
    }
  }

  Future<void> _openWhatsApp({
    required String playerPhone,
    required String playerName,
    required String courtName,
    required String date,
    required String startTime,
    required String endTime,
    required String status,
  }) async {
    final cleanPhone = playerPhone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanPhone.isEmpty) {
      _showSnackBar('Este usuario no tiene teléfono cargado');
      return;
    }

    final venueName = (widget.venue['name'] ?? 'Complejo').toString();

    final message = Uri.encodeComponent(
      'Hola $playerName, te escribimos desde $venueName.\n'
      'Reserva: $courtName\n'
      'Fecha: $date\n'
      'Horario: $startTime - $endTime\n'
      'Estado actual: ${_statusText(status)}',
    );

    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$message');

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      _showSnackBar('No se pudo abrir WhatsApp');
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
        return 'Pendiente de pago';
    }
  }

  String _paymentMethodText(String method) {
    switch (method) {
      case 'cash_venue':
        return 'Pagar en cancha';
      case 'bank_transfer':
        return 'Transferencia';
      default:
        return method;
    }
  }

  String _paymentStatusText(String status) {
    switch (status) {
      case 'verified':
        return 'Pago verificado';
      case 'rejected':
        return 'Pago rechazado';
      case 'pending':
      default:
        return 'Pago pendiente';
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

  String _shortTime(dynamic raw) {
    final text = (raw ?? '').toString();
    if (text.length >= 5) return text.substring(0, 5);
    return text;
  }

  String _formatDate(dynamic raw) {
    final text = (raw ?? '').toString();
    final parts = text.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return text;
  }

  Widget _buildAvatar(Map<String, dynamic>? profile) {
    final name = (profile?['full_name'] ?? 'Jugador').toString();
    final avatarUrl = (profile?['avatar_url'] ?? '').toString();
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'J';

    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: Colors.transparent,
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return CircleAvatar(
                radius: 22,
                child: Text(initial),
              );
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 22,
      child: Text(initial),
    );
  }

  String _remainingTimeText(dynamic expiresAtRaw) {
    if (expiresAtRaw == null) return 'Sin vencimiento';

    final expiresAt = DateTime.tryParse(expiresAtRaw.toString());
    if (expiresAt == null) return 'Sin vencimiento';

    final now = DateTime.now();
    final diff = expiresAt.difference(now);

    if (diff.isNegative) {
      return 'Vencida';
    }

    final minutes = diff.inMinutes;
    if (minutes <= 0) {
      return 'Menos de 1 min';
    }

    return '$minutes min restantes';
  }

  bool _isNearExpiration(dynamic expiresAtRaw) {
    if (expiresAtRaw == null) return false;

    final expiresAt = DateTime.tryParse(expiresAtRaw.toString());
    if (expiresAt == null) return false;

    final diff = expiresAt.difference(DateTime.now()).inMinutes;
    return diff >= 0 && diff <= 5;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueName = (widget.venue['name'] ?? 'Mi complejo').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('Reservas - $venueName'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : reservations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay reservas para este complejo.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReservations,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: reservations.map((reservation) {
                      final reservationId = reservation['id'] as int;
                      final courtData =
                          reservation['courts'] as Map<String, dynamic>?;
                      final profileData =
                          reservation['profiles'] as Map<String, dynamic>?;

                      final courtName =
                          (courtData?['name'] ?? 'Cancha').toString();
                      final playerName =
                          (profileData?['full_name'] ?? 'Jugador').toString();
                      final playerPhone =
                          (profileData?['phone'] ?? '').toString();

                      final date = _formatDate(reservation['reservation_date']);
                      final startTime = _shortTime(reservation['start_time']);
                      final endTime = _shortTime(reservation['end_time']);
                      final status =
                          (reservation['status'] ?? 'pending_payment').toString();
                      final paymentMethod =
                          (reservation['payment_method'] ?? '').toString();
                      final paymentStatus =
                          (reservation['payment_status'] ?? 'pending').toString();
                      final totalPrice = reservation['total_price'];
                      final expiresAt = reservation['expires_at'];
                      final nearExpiration =
                          status == 'pending_payment' &&
                              _isNearExpiration(expiresAt);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: theme.colorScheme.surface,
                          border: Border.all(
                            color: nearExpiration
                                ? Colors.orange.withOpacity(0.55)
                                : theme.colorScheme.outlineVariant.withOpacity(0.22),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                courtName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildAvatar(profileData),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          playerName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (playerPhone.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            playerPhone,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ReservationChip(label: date),
                                  _ReservationChip(label: '$startTime - $endTime'),
                                  _ReservationChip(
                                    label: _paymentMethodText(paymentMethod),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Estado: ${_statusText(status)}',
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pago: ${_paymentStatusText(paymentStatus)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (status == 'pending_payment' && expiresAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Vence en: ${_remainingTimeText(expiresAt)}',
                                  style: TextStyle(
                                    color: nearExpiration
                                        ? Colors.orange
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: nearExpiration
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (totalPrice != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Total: Gs. $totalPrice',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: playerPhone.trim().isEmpty
                                          ? null
                                          : () {
                                              _openWhatsApp(
                                                playerPhone: playerPhone,
                                                playerName: playerName,
                                                courtName: courtName,
                                                date: date,
                                                startTime: startTime,
                                                endTime: endTime,
                                                status: status,
                                              );
                                            },
                                      icon: const Icon(Icons.chat_bubble_outline),
                                      label: const Text('WhatsApp'),
                                    ),
                                  ),
                                ],
                              ),
                              if (status == 'pending_payment') ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          _updateReservation(
                                            reservationId: reservationId,
                                            status: 'confirmed',
                                            paymentStatus: 'verified',
                                          );
                                        },
                                        icon: const Icon(Icons.check_circle_outline),
                                        label: const Text('Confirmar'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          _updateReservation(
                                            reservationId: reservationId,
                                            status: 'cancelled',
                                            paymentStatus: 'rejected',
                                          );
                                        },
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('Cancelar'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}

class _ReservationChip extends StatelessWidget {
  final String label;

  const _ReservationChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}