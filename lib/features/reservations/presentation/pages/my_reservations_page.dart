import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MyReservationsPage extends StatefulWidget {
  const MyReservationsPage({super.key});

  @override
  State<MyReservationsPage> createState() => _MyReservationsPageState();
}

class _MyReservationsPageState extends State<MyReservationsPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> reservations = [];
  bool isLoading = true;
  bool isCancelling = false;

  Timer? _timer;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _loadReservations();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadReservations() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        reservations = [];
        isLoading = false;
      });
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('court_reservations')
          .select('*, courts(name), venues(name, whatsapp)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      final loaded = List<Map<String, dynamic>>.from(response);

      loaded.sort((a, b) {
        final aActive = _isActiveReservation(a);
        final bActive = _isActiveReservation(b);

        if (aActive != bActive) {
          return aActive ? -1 : 1;
        }

        final aPending = (a['status'] ?? '') == 'pending_payment' && !_isExpired(a);
        final bPending = (b['status'] ?? '') == 'pending_payment' && !_isExpired(b);

        if (aPending && bPending) {
          final aExp = _expiresAt(a);
          final bExp = _expiresAt(b);

          if (aExp != null && bExp != null) {
            return aExp.compareTo(bExp);
          }
        }

        return 0;
      });

      setState(() {
        reservations = loaded;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showSnackBar('Error cargando reservas');
    }
  }

  DateTime? _expiresAt(Map<String, dynamic> reservation) {
    final raw = reservation['expires_at'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  bool _isExpired(Map<String, dynamic> reservation) {
    if (reservation['status'] != 'pending_payment') return false;

    final expiresAt = _expiresAt(reservation);
    if (expiresAt == null) return false;

    return expiresAt.isBefore(DateTime.now());
  }

  bool _isActiveReservation(Map<String, dynamic> reservation) {
    final status = (reservation['status'] ?? '').toString();

    if (status == 'confirmed') return true;
    if (status == 'pending_payment' && !_isExpired(reservation)) return true;

    return false;
  }

  String _formatRemaining(DateTime expiresAt) {
    final diff = expiresAt.difference(DateTime.now());

    if (diff.isNegative) return '00:00';

    final minutes = diff.inMinutes.toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  Duration _remainingDuration(Map<String, dynamic> reservation) {
    final expiresAt = _expiresAt(reservation);
    if (expiresAt == null) return Duration.zero;

    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  int _timeLimitMinutes(Map<String, dynamic> reservation) {
    final expiresAt = _expiresAt(reservation);
    if (expiresAt == null) return 10;

    final createdAtRaw = reservation['created_at'];
    if (createdAtRaw == null) return 10;

    final createdAt = DateTime.tryParse(createdAtRaw.toString());
    if (createdAt == null) return 10;

    final minutes = expiresAt.difference(createdAt).inMinutes;
    return minutes <= 0 ? 10 : minutes;
  }

  double _remainingProgress(Map<String, dynamic> reservation) {
    final limitMinutes = _timeLimitMinutes(reservation);
    final totalSeconds = limitMinutes * 60;
    if (totalSeconds <= 0) return 0;

    final remainingSeconds = _remainingDuration(reservation).inSeconds;
    final progress = remainingSeconds / totalSeconds;

    return progress.clamp(0.0, 1.0);
  }

  Color _statusColor(Map<String, dynamic> reservation) {
    final status = (reservation['status'] ?? '').toString();

    if (status == 'confirmed') return Colors.green;
    if (status == 'cancelled') return Colors.grey;
    if (status == 'pending_payment') {
      final remaining = _remainingDuration(reservation).inSeconds;
      if (_isExpired(reservation)) return Colors.red;
      if (remaining <= 120) return Colors.red;
      if (remaining <= 300) return Colors.orange;
      return Colors.amber.shade700;
    }

    return Colors.grey;
  }

  String _statusText(Map<String, dynamic> reservation) {
    final status = (reservation['status'] ?? '').toString();

    if (status == 'confirmed') return 'Confirmada';
    if (status == 'cancelled') return 'Cancelada';
    if (status == 'pending_payment') {
      return _isExpired(reservation) ? 'Vencida' : 'Pendiente';
    }

    return status.isEmpty ? 'Sin estado' : status;
  }

  String _moneyText(dynamic value) {
    if (value is num) {
      return 'Gs. ${value.toStringAsFixed(0)}';
    }

    final parsed = double.tryParse((value ?? '').toString());
    if (parsed != null) {
      return 'Gs. ${parsed.toStringAsFixed(0)}';
    }

    return 'Gs. 0';
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

  Future<void> _openWhatsApp(Map<String, dynamic> reservation) async {
    final phone = (reservation['venues']?['whatsapp'] ?? '')
        .toString()
        .replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.isEmpty) {
      _showSnackBar('Este complejo no tiene WhatsApp configurado');
      return;
    }

    final message = Uri.encodeComponent(
      'Hola, envío comprobante de mi reserva:\n\n'
      'Complejo: ${reservation['venues']?['name'] ?? ''}\n'
      'Cancha: ${reservation['courts']?['name'] ?? ''}\n'
      'Fecha: ${reservation['reservation_date'] ?? ''}\n'
      'Horario: ${reservation['start_time'] ?? ''} - ${reservation['end_time'] ?? ''}\n'
      'Monto total: ${_moneyText(reservation['total_price'])}',
    );

    final uri = Uri.parse('https://wa.me/$phone?text=$message');

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok) {
      _showSnackBar('No se pudo abrir WhatsApp');
    }
  }

  Future<void> _cancelReservation(Map<String, dynamic> reservation) async {
    final status = (reservation['status'] ?? '').toString();

    if (status != 'pending_payment') {
      _showSnackBar('Solo se pueden cancelar reservas pendientes');
      return;
    }

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cancelar reserva',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Esta acción va a liberar el horario y no se puede deshacer.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Volver'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Cancelar reserva'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() {
      isCancelling = true;
    });

    try {
      await Supabase.instance.client
          .from('court_reservations')
          .update({
            'status': 'cancelled',
            'payment_status': 'rejected',
          })
          .eq('id', reservation['id']);

      await _loadReservations();
      _showSnackBar('Reserva cancelada');
    } catch (e) {
      _showSnackBar('No se pudo cancelar la reserva');
    } finally {
      if (!mounted) return;
      setState(() {
        isCancelling = false;
      });
    }
  }

  List<Map<String, dynamic>> _activeReservations() {
    return reservations.where(_isActiveReservation).toList();
  }

  List<Map<String, dynamic>> _historyReservations() {
    return reservations.where((r) => !_isActiveReservation(r)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeReservations = _activeReservations();
    final historyReservations = _historyReservations();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reservas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Activas (${activeReservations.length})'),
            Tab(text: 'Historial (${historyReservations.length})'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadReservations,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ReservationsList(
                    reservations: activeReservations,
                    isCancelling: isCancelling,
                    statusColor: _statusColor,
                    statusText: _statusText,
                    formatRemaining: _formatRemaining,
                    paymentMethodText: _paymentMethodText,
                    moneyText: _moneyText,
                    isExpired: _isExpired,
                    remainingDuration: _remainingDuration,
                    remainingProgress: _remainingProgress,
                    onOpenWhatsApp: _openWhatsApp,
                    onCancelReservation: _cancelReservation,
                    emptyText: 'No tenés reservas activas.',
                  ),
                  _ReservationsList(
                    reservations: historyReservations,
                    isCancelling: isCancelling,
                    statusColor: _statusColor,
                    statusText: _statusText,
                    formatRemaining: _formatRemaining,
                    paymentMethodText: _paymentMethodText,
                    moneyText: _moneyText,
                    isExpired: _isExpired,
                    remainingDuration: _remainingDuration,
                    remainingProgress: _remainingProgress,
                    onOpenWhatsApp: _openWhatsApp,
                    onCancelReservation: _cancelReservation,
                    emptyText: 'Todavía no tenés historial de reservas.',
                  ),
                ],
              ),
            ),
    );
  }
}

class _ReservationsList extends StatelessWidget {
  final List<Map<String, dynamic>> reservations;
  final bool isCancelling;
  final Color Function(Map<String, dynamic>) statusColor;
  final String Function(Map<String, dynamic>) statusText;
  final String Function(DateTime) formatRemaining;
  final String Function(String) paymentMethodText;
  final String Function(dynamic) moneyText;
  final bool Function(Map<String, dynamic>) isExpired;
  final Duration Function(Map<String, dynamic>) remainingDuration;
  final double Function(Map<String, dynamic>) remainingProgress;
  final Future<void> Function(Map<String, dynamic>) onOpenWhatsApp;
  final Future<void> Function(Map<String, dynamic>) onCancelReservation;
  final String emptyText;

  const _ReservationsList({
    required this.reservations,
    required this.isCancelling,
    required this.statusColor,
    required this.statusText,
    required this.formatRemaining,
    required this.paymentMethodText,
    required this.moneyText,
    required this.isExpired,
    required this.remainingDuration,
    required this.remainingProgress,
    required this.onOpenWhatsApp,
    required this.onCancelReservation,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (reservations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.surface,
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.22),
              ),
            ),
            child: Text(emptyText),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: reservations.length,
      itemBuilder: (context, index) {
        final reservation = reservations[index];

        final expires = reservation['expires_at'] != null
            ? DateTime.tryParse(reservation['expires_at'].toString())
            : null;

        final pending = (reservation['status'] ?? '') == 'pending_payment';
        final expired = isExpired(reservation);
        final countdownColor = statusColor(reservation);
        final remaining = remainingDuration(reservation);
        final progress = remainingProgress(reservation);
        final soon = pending && !expired && remaining.inSeconds <= 120;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: theme.colorScheme.surface,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.20),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 12,
                offset: const Offset(0, 6),
                color: Colors.black.withOpacity(0.04),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (reservation['courts']?['name'] ?? '').toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                (reservation['venues']?['name'] ?? '').toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _ReservationInfoRow(
                icon: Icons.calendar_month_outlined,
                text: (reservation['reservation_date'] ?? '').toString(),
              ),
              const SizedBox(height: 6),
              _ReservationInfoRow(
                icon: Icons.schedule_outlined,
                text:
                    '${reservation['start_time'] ?? ''} - ${reservation['end_time'] ?? ''}',
              ),
              const SizedBox(height: 6),
              _ReservationInfoRow(
                icon: Icons.payments_outlined,
                text:
                    '${paymentMethodText((reservation['payment_method'] ?? '').toString())} • ${moneyText(reservation['total_price'])}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: countdownColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusText(reservation),
                      style: TextStyle(
                        color: countdownColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (pending && expires != null && !expired)
                    Text(
                      formatRemaining(expires),
                      style: TextStyle(
                        color: countdownColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
              if (pending && !expired) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
              if (soon) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.red.withOpacity(0.10),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.25),
                    ),
                  ),
                  child: const Text(
                    'Tu reserva está por vencer. Enviá el comprobante cuanto antes.',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (pending) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: expired ? null : () => onOpenWhatsApp(reservation),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Enviar comprobante'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isCancelling || expired
                        ? null
                        : () => onCancelReservation(reservation),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar reserva'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ReservationInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ReservationInfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}