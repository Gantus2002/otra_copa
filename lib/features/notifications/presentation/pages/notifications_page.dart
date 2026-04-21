import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../reservations/presentation/pages/my_reservations_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> pendingReservations = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _loadNotifications() async {
    _safeSetState(() {
      isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        _safeSetState(() {
          pendingReservations = [];
          isLoading = false;
        });
        return;
      }

      final response = await client
          .from('court_reservations')
          .select('''
            id,
            reservation_date,
            start_time,
            end_time,
            status,
            expires_at,
            total_price,
            courts(name)
          ''')
          .eq('user_id', user.id)
          .eq('status', 'pending_payment')
          .order('expires_at', ascending: true);

      _safeSetState(() {
        pendingReservations = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('Error cargando notificaciones: $e');
    }
  }

  String _formatDate(dynamic raw) {
    final text = (raw ?? '').toString();
    final parts = text.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return text;
  }

  String _shortTime(dynamic raw) {
    final text = (raw ?? '').toString();
    if (text.length >= 5) return text.substring(0, 5);
    return text;
  }

  String _remainingTimeText(dynamic expiresAtRaw) {
    if (expiresAtRaw == null) return 'Sin vencimiento';

    final expiresAt = DateTime.tryParse(expiresAtRaw.toString());
    if (expiresAt == null) return 'Sin vencimiento';

    final diff = expiresAt.difference(DateTime.now());

    if (diff.isNegative) {
      return 'Vencida';
    }

    final totalSeconds = diff.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds restantes';
  }

  bool _isUrgent(dynamic expiresAtRaw) {
    if (expiresAtRaw == null) return false;

    final expiresAt = DateTime.tryParse(expiresAtRaw.toString());
    if (expiresAt == null) return false;

    final diff = expiresAt.difference(DateTime.now());
    return diff.inSeconds > 0 && diff.inMinutes <= 5;
  }

  void _openMyReservations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyReservationsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingReservations.isEmpty
              ? RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 80),
                      Icon(Icons.notifications_none, size: 64),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No tenés notificaciones por ahora.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Reservas pendientes',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Estas reservas están esperando pago o están por vencer.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...pendingReservations.map((reservation) {
                        final court =
                            (reservation['courts'] as Map<String, dynamic>?)?['name']
                                    ?.toString() ??
                                'Cancha';
                        final date = _formatDate(reservation['reservation_date']);
                        final startTime = _shortTime(reservation['start_time']);
                        final endTime = _shortTime(reservation['end_time']);
                        final totalPrice =
                            (reservation['total_price'] ?? '').toString();
                        final expiresAt = reservation['expires_at'];
                        final urgent = _isUrgent(expiresAt);

                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _openMyReservations,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: theme.colorScheme.surface,
                              border: Border.all(
                                color: urgent
                                    ? Colors.orange.withOpacity(0.6)
                                    : theme.colorScheme.outlineVariant
                                        .withOpacity(0.25),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (urgent)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        '⚠ Por vencer',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          court,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _InfoChip(label: date),
                                      _InfoChip(label: '$startTime - $endTime'),
                                      if (totalPrice.isNotEmpty)
                                        _InfoChip(label: 'Gs. $totalPrice'),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Vence en: ${_remainingTimeText(expiresAt)}',
                                    style: TextStyle(
                                      color: urgent
                                          ? Colors.orange
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontWeight:
                                          urgent ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tocá para ver tus reservas',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({
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
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}