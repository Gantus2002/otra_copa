import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CourtReservationPage extends StatefulWidget {
  final Map<String, dynamic> venue;
  final Map<String, dynamic> court;

  const CourtReservationPage({
    super.key,
    required this.venue,
    required this.court,
  });

  @override
  State<CourtReservationPage> createState() => _CourtReservationPageState();
}

class _CourtReservationPageState extends State<CourtReservationPage> {
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  bool isSaving = false;

  List<Map<String, dynamic>> availabilityRules = [];
  List<Map<String, dynamic>> blockedSlots = [];
  List<Map<String, dynamic>> reservations = [];
  List<_TimeSlot> availableSlots = [];

  String paymentMethod = 'cash_venue';

  @override
  void initState() {
    super.initState();
    _loadAvailability();
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

  Future<void> _copyText(String label, String value) async {
    if (value.trim().isEmpty) {
      _showSnackBar('$label no disponible');
      return;
    }

    await Clipboard.setData(ClipboardData(text: value));
    _showSnackBar('$label copiado');
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(today) ? today : selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );

    if (picked == null) return;

    _safeSetState(() {
      selectedDate = picked;
    });

    await _loadAvailability();
  }

  int _dayOfWeekForDb(DateTime date) {
    if (date.weekday == DateTime.sunday) return 0;
    return date.weekday;
  }

  String _dateToDb(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _dateForMessage(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  TimeOfDay _parseTime(String value) {
    final clean = value.length >= 5 ? value.substring(0, 5) : value;
    final parts = clean.split(':');

    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _overlaps(
    String startA,
    String endA,
    String startB,
    String endB,
  ) {
    return startA.compareTo(endB) < 0 && startB.compareTo(endA) < 0;
  }

  List<_TimeSlot> _generateSlots() {
    final slots = <_TimeSlot>[];

    for (final rule in availabilityRules) {
      final start = _parseTime((rule['start_time'] ?? '').toString());
      final end = _parseTime((rule['end_time'] ?? '').toString());

      int currentHour = start.hour;
      int currentMinute = start.minute;

      while (true) {
        final slotStart = TimeOfDay(hour: currentHour, minute: currentMinute);
        final nextHour = currentHour + 1;
        final nextMinute = currentMinute;
        final slotEnd = TimeOfDay(hour: nextHour, minute: nextMinute);

        final slotStartText = _formatTimeOfDay(slotStart);
        final slotEndText = _formatTimeOfDay(slotEnd);
        final endText = _formatTimeOfDay(end);

        if (slotEndText.compareTo(endText) > 0) {
          break;
        }

        final blocked = blockedSlots.any(
          (b) => _overlaps(
            slotStartText,
            slotEndText,
            (b['start_time'] ?? '').toString().substring(0, 5),
            (b['end_time'] ?? '').toString().substring(0, 5),
          ),
        );

        final reserved = reservations.any(
          (r) => _overlaps(
            slotStartText,
            slotEndText,
            (r['start_time'] ?? '').toString().substring(0, 5),
            (r['end_time'] ?? '').toString().substring(0, 5),
          ),
        );

        if (!blocked && !reserved) {
          slots.add(
            _TimeSlot(
              start: slotStartText,
              end: slotEndText,
            ),
          );
        }

        currentHour = nextHour;
        currentMinute = nextMinute;
      }
    }

    return slots;
  }

  Future<void> _loadAvailability() async {
    _safeSetState(() {
      isLoading = true;
    });

    try {
      final courtId = widget.court['id'];
      final selectedDateDb = _dateToDb(selectedDate);
      final dayOfWeek = _dayOfWeekForDb(selectedDate);

      final rulesResponse = await Supabase.instance.client
          .from('court_availability_rules')
          .select()
          .eq('court_id', courtId)
          .eq('day_of_week', dayOfWeek)
          .eq('is_active', true)
          .order('start_time');

      final blockedResponse = await Supabase.instance.client
          .from('court_blocked_slots')
          .select()
          .eq('court_id', courtId)
          .eq('blocked_date', selectedDateDb)
          .order('start_time');

      final reservationsResponse = await Supabase.instance.client
          .from('court_reservations')
          .select()
          .eq('court_id', courtId)
          .eq('reservation_date', selectedDateDb)
          .inFilter('status', ['pending_payment', 'confirmed'])
          .order('start_time');

      availabilityRules = List<Map<String, dynamic>>.from(rulesResponse);
      blockedSlots = List<Map<String, dynamic>>.from(blockedResponse);
      reservations = List<Map<String, dynamic>>.from(reservationsResponse);

      final generated = _generateSlots();

      _safeSetState(() {
        availableSlots = generated;
        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('Error cargando horarios: $e');
    }
  }

  double _hourPrice() {
    final price = widget.court['price_per_hour'];
    if (price is num) return price.toDouble();
    return 0;
  }

  int _reservationPercentage() {
    final p = widget.venue['reservation_percentage'];
    if (p is int) return p;
    if (p is num) return p.toInt();
    return 20;
  }

  int _timeLimitMinutes() {
    final m = widget.venue['payment_time_limit_minutes'];
    if (m is int) return m;
    if (m is num) return m.toInt();
    return 10;
  }

  double _depositAmount() {
    final total = _hourPrice();
    final percentage = _reservationPercentage();
    return (total * percentage) / 100;
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

  Future<void> _openWhatsAppForProof(_TimeSlot slot) async {
    final phone = (widget.venue['whatsapp'] ?? '').toString().trim();

    if (phone.isEmpty) {
      _showSnackBar('Esta cancha no tiene WhatsApp configurado');
      return;
    }

    final alias = (widget.venue['transfer_alias'] ?? '').toString().trim();
    final cbu = (widget.venue['transfer_cbu'] ?? '').toString().trim();
    final deposit = _depositAmount().toStringAsFixed(0);
    final total = _hourPrice().toStringAsFixed(0);

    final message = Uri.encodeComponent(
      'Hola, acabo de reservar una cancha.\n\n'
      'Complejo: ${(widget.venue['name'] ?? '').toString()}\n'
      'Cancha: ${(widget.court['name'] ?? '').toString()}\n'
      'Fecha: ${_dateForMessage(selectedDate)}\n'
      'Horario: ${slot.start} - ${slot.end}\n'
      'Método de pago: ${_paymentMethodText(paymentMethod)}\n'
      'Monto total: Gs. $total\n'
      'Monto de seña: Gs. $deposit\n'
      'Alias: ${alias.isEmpty ? '-' : alias}\n'
      'CBU: ${cbu.isEmpty ? '-' : cbu}\n\n'
      'Adjunto el comprobante de pago.',
    );

    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$normalizedPhone?text=$message');

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok) {
      _showSnackBar('No se pudo abrir WhatsApp');
    }
  }

  Future<void> _showTransferPendingSheet({
    required _TimeSlot slot,
    required DateTime expiresAt,
  }) async {
    final alias = (widget.venue['transfer_alias'] ?? '').toString().trim();
    final cbu = (widget.venue['transfer_cbu'] ?? '').toString().trim();
    final deposit = _depositAmount().toStringAsFixed(0);
    final total = _hourPrice().toStringAsFixed(0);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _PendingTransferSheet(
          venueName: (widget.venue['name'] ?? '').toString(),
          courtName: (widget.court['name'] ?? '').toString(),
          reservationDate: _dateForMessage(selectedDate),
          slotLabel: '${slot.start} - ${slot.end}',
          totalAmount: total,
          depositAmount: deposit,
          reservationPercentage: _reservationPercentage(),
          alias: alias,
          cbu: cbu,
          expiresAt: expiresAt,
          timeLimitMinutes: _timeLimitMinutes(),
          onCopyAlias: () => _copyText('Alias', alias),
          onCopyCbu: () => _copyText('CBU', cbu),
          onOpenWhatsApp: () => _openWhatsAppForProof(slot),
        );
      },
    );
  }

  Future<void> _reserveSlot(_TimeSlot slot) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('Tenés que iniciar sesión');
      return;
    }

    _safeSetState(() {
      isSaving = true;
    });

    try {
      final totalPrice = _hourPrice();
      final expiresAt = DateTime.now().add(
        Duration(minutes: _timeLimitMinutes()),
      );

      await Supabase.instance.client.from('court_reservations').insert({
        'court_id': widget.court['id'],
        'venue_id': widget.venue['id'],
        'user_id': user.id,
        'reservation_date': _dateToDb(selectedDate),
        'start_time': slot.start,
        'end_time': slot.end,
        'total_price': totalPrice,
        'status': 'pending_payment',
        'payment_method': paymentMethod,
        'payment_status': 'pending',
        'expires_at': expiresAt.toIso8601String(),
      });

      if (paymentMethod == 'bank_transfer') {
        await _showTransferPendingSheet(
          slot: slot,
          expiresAt: expiresAt,
        );
      } else {
        _showSnackBar('Reserva creada correctamente');
      }

      await _loadAvailability();
    } catch (e) {
      _showSnackBar('No se pudo reservar: $e');
    } finally {
      _safeSetState(() {
        isSaving = false;
      });
    }
  }

  String _priceText() {
    return 'Gs. ${_hourPrice().toStringAsFixed(0)} / hora';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueName = (widget.venue['name'] ?? 'Complejo').toString();
    final courtName = (widget.court['name'] ?? 'Cancha').toString();

    final alias = (widget.venue['transfer_alias'] ?? '').toString().trim();
    final cbu = (widget.venue['transfer_cbu'] ?? '').toString().trim();
    final deposit = _depositAmount().toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservar cancha'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text(
                  courtName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  venueName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _priceText(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Fecha'),
                    subtitle: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Método de pago',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'cash_venue',
                          child: Text('Pagar en cancha'),
                        ),
                        DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text('Transferencia'),
                        ),
                      ],
                      onChanged: (value) {
                        _safeSetState(() {
                          paymentMethod = value ?? 'cash_venue';
                        });
                      },
                    ),
                  ),
                ),
                if (paymentMethod == 'bank_transfer') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Datos para transferencia',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Seña: ${_reservationPercentage()}%'),
                        Text('Monto total: Gs. ${_hourPrice().toStringAsFixed(0)}'),
                        Text('Monto a transferir: Gs. $deposit'),
                        Text('Tiempo límite: ${_timeLimitMinutes()} minutos'),
                        const SizedBox(height: 10),
                        Text('Alias: ${alias.isEmpty ? '-' : alias}'),
                        Text('CBU: ${cbu.isEmpty ? '-' : cbu}'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  'Horarios disponibles',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (availableSlots.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: theme.colorScheme.surface,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.22),
                      ),
                    ),
                    child: const Text(
                      'No hay horarios disponibles para esta fecha.',
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: availableSlots.map((slot) {
                      return FilledButton.tonal(
                        onPressed: isSaving ? null : () => _reserveSlot(slot),
                        child: Text('${slot.start} - ${slot.end}'),
                      );
                    }).toList(),
                  ),
              ],
            ),
    );
  }
}

class _PendingTransferSheet extends StatefulWidget {
  final String venueName;
  final String courtName;
  final String reservationDate;
  final String slotLabel;
  final String totalAmount;
  final String depositAmount;
  final int reservationPercentage;
  final String alias;
  final String cbu;
  final DateTime expiresAt;
  final int timeLimitMinutes;
  final Future<void> Function() onOpenWhatsApp;
  final Future<void> Function() onCopyAlias;
  final Future<void> Function() onCopyCbu;

  const _PendingTransferSheet({
    required this.venueName,
    required this.courtName,
    required this.reservationDate,
    required this.slotLabel,
    required this.totalAmount,
    required this.depositAmount,
    required this.reservationPercentage,
    required this.alias,
    required this.cbu,
    required this.expiresAt,
    required this.timeLimitMinutes,
    required this.onOpenWhatsApp,
    required this.onCopyAlias,
    required this.onCopyCbu,
  });

  @override
  State<_PendingTransferSheet> createState() => _PendingTransferSheetState();
}

class _PendingTransferSheetState extends State<_PendingTransferSheet> {
  Timer? _timer;
  Duration remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _refreshRemaining();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refreshRemaining() {
    final diff = widget.expiresAt.difference(DateTime.now());
    final safe = diff.isNegative ? Duration.zero : diff;

    if (!mounted) return;

    setState(() {
      remaining = safe;
    });
  }

  String _formatRemaining(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Color _countdownColor(BuildContext context) {
    if (remaining.inSeconds <= 60) return Colors.red;
    if (remaining.inSeconds <= 180) return Colors.orange;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countdownColor = _countdownColor(context);
    final expired = remaining == Duration.zero;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reserva creada',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'La reserva quedó pendiente de pago.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: countdownColor.withOpacity(0.10),
                border: Border.all(
                  color: countdownColor.withOpacity(0.35),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    expired ? 'Tiempo vencido' : 'Tiempo restante para pagar',
                    style: TextStyle(
                      color: countdownColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatRemaining(remaining),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: countdownColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vence a las ${widget.expiresAt.hour.toString().padLeft(2, '0')}:${widget.expiresAt.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _InfoCard(
              children: [
                _InfoRow(label: 'Complejo', value: widget.venueName),
                _InfoRow(label: 'Cancha', value: widget.courtName),
                _InfoRow(label: 'Fecha', value: widget.reservationDate),
                _InfoRow(label: 'Horario', value: widget.slotLabel),
                _InfoRow(label: 'Monto total', value: 'Gs. ${widget.totalAmount}'),
                _InfoRow(
                  label: 'Seña (${widget.reservationPercentage}%)',
                  value: 'Gs. ${widget.depositAmount}',
                ),
                _InfoRow(
                  label: 'Límite',
                  value: '${widget.timeLimitMinutes} minutos',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoCard(
              children: [
                _CopyableRow(
                  label: 'Alias',
                  value: widget.alias.isEmpty ? '-' : widget.alias,
                  onCopy: widget.alias.isEmpty ? null : widget.onCopyAlias,
                ),
                const SizedBox(height: 12),
                _CopyableRow(
                  label: 'CBU',
                  value: widget.cbu.isEmpty ? '-' : widget.cbu,
                  onCopy: widget.cbu.isEmpty ? null : widget.onCopyCbu,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: expired ? null : widget.onOpenWhatsApp,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Enviar comprobante por WhatsApp'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  final String label;
  final String value;
  final Future<void> Function()? onCopy;

  const _CopyableRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_outlined),
          tooltip: 'Copiar',
        ),
      ],
    );
  }
}

class _TimeSlot {
  final String start;
  final String end;

  _TimeSlot({
    required this.start,
    required this.end,
  });
}