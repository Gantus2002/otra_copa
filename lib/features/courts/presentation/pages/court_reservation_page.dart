import 'package:flutter/material.dart';
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(now) ? now : selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
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

    final message = Uri.encodeComponent(
      'Hola, quiero enviar el comprobante de reserva.\n'
      'Complejo: ${(widget.venue['name'] ?? '').toString()}\n'
      'Cancha: ${(widget.court['name'] ?? '').toString()}\n'
      'Fecha: ${_dateToDb(selectedDate)}\n'
      'Horario: ${slot.start} - ${slot.end}\n'
      'Monto de seña: Gs. $deposit\n'
      'Alias: ${alias.isEmpty ? '-' : alias}\n'
      'CBU: ${cbu.isEmpty ? '-' : cbu}',
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

      _showSnackBar('Reserva creada correctamente');

      if (paymentMethod == 'bank_transfer') {
        await _openWhatsAppForProof(slot);
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

class _TimeSlot {
  final String start;
  final String end;

  _TimeSlot({
    required this.start,
    required this.end,
  });
}