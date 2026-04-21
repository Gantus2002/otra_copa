import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app_bar_with_notifications.dart';
import '../../../player/presentation/pages/player_public_profile_page.dart';

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
  String selectedFilter = 'today';

  RealtimeChannel? _channel;
  Timer? _ticker;
  Timer? _debounceReloadTimer;

  @override
  void initState() {
    super.initState();
    _loadReservations();
    _setupRealtime();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _debounceReloadTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
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

  void _setupRealtime() {
    final venueId = widget.venue['id'];
    if (venueId == null) return;

    _channel = Supabase.instance.client
        .channel('venue-reservations-${venueId.toString()}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'court_reservations',
          callback: (payload) {
            final newVenueId = payload.newRecord['venue_id'];
            final oldVenueId = payload.oldRecord['venue_id'];

            final affectsThisVenue =
                newVenueId == venueId || oldVenueId == venueId;

            if (!affectsThisVenue) return;

            _scheduleReloadFromRealtime();

            if (!mounted) return;

            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                _showSnackBar('Entró una nueva reserva');
                break;
              case PostgresChangeEvent.update:
                final status = (payload.newRecord['status'] ?? '').toString();

                if (status == 'confirmed') {
                  _showSnackBar('Reserva confirmada');
                } else if (status == 'cancelled') {
                  _showSnackBar('Reserva cancelada');
                } else if (status == 'expired') {
                  _showSnackBar('Una reserva venció');
                } else {
                  _showSnackBar('Reserva actualizada');
                }
                break;
              case PostgresChangeEvent.delete:
                _showSnackBar('Una reserva fue eliminada');
                break;
              default:
                break;
            }
          },
        )
        .subscribe();
  }

  void _scheduleReloadFromRealtime() {
    _debounceReloadTimer?.cancel();
    _debounceReloadTimer = Timer(const Duration(milliseconds: 500), () {
      _loadReservations(showLoader: false);
    });
  }

  Future<void> _expireOldReservations() async {
    try {
      await Supabase.instance.client
          .from('court_reservations')
          .update({
            'status': 'expired',
            'payment_status': 'rejected',
          })
          .eq('status', 'pending_payment')
          .lt('expires_at', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> _loadReservations({bool showLoader = true}) async {
    if (showLoader) {
      _safeSetState(() {
        isLoading = true;
      });
    }

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

      final loaded = List<Map<String, dynamic>>.from(response);

      loaded.sort((a, b) {
        final aStatus = (a['status'] ?? '').toString();
        final bStatus = (b['status'] ?? '').toString();

        if (aStatus == 'pending_payment' && bStatus != 'pending_payment') {
          return -1;
        }
        if (bStatus == 'pending_payment' && aStatus != 'pending_payment') {
          return 1;
        }

        return 0;
      });

      _safeSetState(() {
        reservations = loaded;
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

      await _loadReservations(showLoader: false);
      _showSnackBar('Reserva actualizada');
    } catch (e) {
      _showSnackBar('Error actualizando reserva: $e');
    }
  }

  Future<void> _confirmReservation({
    required int reservationId,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar reserva'),
        content: const Text(
          '¿Confirmar esta reserva? Esto va a bloquear el horario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _updateReservation(
      reservationId: reservationId,
      status: 'confirmed',
      paymentStatus: 'verified',
    );
  }

  Future<void> _cancelReservation({
    required int reservationId,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: const Text(
          '¿Seguro querés cancelar esta reserva?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _updateReservation(
      reservationId: reservationId,
      status: 'cancelled',
      paymentStatus: 'rejected',
    );
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

  void _openPlayerProfile(Map<String, dynamic> reservation) {
    final userId = (reservation['user_id'] ?? '').toString();
    if (userId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPublicProfilePage(
          userId: userId,
        ),
      ),
    );
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

    final totalSeconds = diff.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds restantes';
  }

  bool _isNearExpiration(dynamic expiresAtRaw) {
    if (expiresAtRaw == null) return false;

    final expiresAt = DateTime.tryParse(expiresAtRaw.toString());
    if (expiresAt == null) return false;

    final diff = expiresAt.difference(DateTime.now()).inMinutes;
    return diff >= 0 && diff <= 5;
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
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
    return reservations.where((reservation) {
      if (selectedFilter == 'all') return true;

      final date =
          DateTime.tryParse((reservation['reservation_date'] ?? '').toString());
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
    final theme = Theme.of(context);
    final venueName = (widget.venue['name'] ?? 'Mi complejo').toString();
    final filtered = _filteredReservations();

    return Scaffold(
      appBar: AppBarWithNotifications(title: 'Reservas - $venueName'),
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
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No hay reservas para este filtro.',
                              style: theme.textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadReservations,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            children: filtered.map((reservation) {
                              final reservationId = reservation['id'] as int;
                              final courtData =
                                  reservation['courts'] as Map<String, dynamic>?;
                              final profileData =
                                  reservation['profiles'] as Map<String, dynamic>?;

                              final courtName =
                                  (courtData?['name'] ?? 'Cancha').toString();
                              final playerName =
                                  (profileData?['full_name'] ?? 'Jugador')
                                      .toString();
                              final playerPhone =
                                  (profileData?['phone'] ?? '').toString();

                              final date =
                                  _formatDate(reservation['reservation_date']);
                              final startTime =
                                  _shortTime(reservation['start_time']);
                              final endTime = _shortTime(reservation['end_time']);
                              final status =
                                  (reservation['status'] ?? 'pending_payment')
                                      .toString();
                              final paymentMethod =
                                  (reservation['payment_method'] ?? '').toString();
                              final paymentStatus =
                                  (reservation['payment_status'] ?? 'pending')
                                      .toString();
                              final totalPrice = reservation['total_price'];
                              final expiresAt = reservation['expires_at'];
                              final nearExpiration = status == 'pending_payment' &&
                                  _isNearExpiration(expiresAt);

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: theme.colorScheme.surface,
                                  border: Border.all(
                                    color: nearExpiration
                                        ? Colors.orange.withOpacity(0.55)
                                        : theme.colorScheme.outlineVariant
                                            .withOpacity(0.22),
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
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (status == 'pending_payment')
                                        Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            '⚠ Pendiente de confirmación',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        courtName,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => _openPlayerProfile(reservation),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildAvatar(profileData),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      playerName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    if (playerPhone.isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        playerPhone,
                                                        style: theme.textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ],
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Ver perfil',
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                        color: theme
                                                            .colorScheme.primary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                Icons.chevron_right,
                                                size: 18,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _ReservationChip(label: date),
                                          _ReservationChip(
                                            label: '$startTime - $endTime',
                                          ),
                                          _ReservationChip(
                                            label: _paymentMethodText(
                                              paymentMethod,
                                            ),
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
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (status == 'pending_payment' &&
                                          expiresAt != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Vence en: ${_remainingTimeText(expiresAt)}',
                                          style: TextStyle(
                                            color: nearExpiration
                                                ? Colors.orange
                                                : theme.colorScheme
                                                    .onSurfaceVariant,
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
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
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
                                              icon: const Icon(
                                                Icons.chat_bubble_outline,
                                              ),
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
                                                  _confirmReservation(
                                                    reservationId: reservationId,
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.check_circle_outline,
                                                ),
                                                label: const Text('Confirmar'),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                  _cancelReservation(
                                                    reservationId: reservationId,
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.cancel_outlined,
                                                ),
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
                ),
              ],
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