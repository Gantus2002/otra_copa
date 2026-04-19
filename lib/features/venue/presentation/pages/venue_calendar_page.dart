import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VenueCalendarPage extends StatefulWidget {
  final Map<String, dynamic> venue;

  const VenueCalendarPage({
    super.key,
    required this.venue,
  });

  @override
  State<VenueCalendarPage> createState() => _VenueCalendarPageState();
}

class _VenueCalendarPageState extends State<VenueCalendarPage> {
  static final DateTime _calendarEpoch = DateTime(2025, 1, 1);

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static int _initialDayPage() {
    return _today().difference(_calendarEpoch).inDays;
  }

  late final PageController _dayPageController;
  final ScrollController _headerHorizontalController = ScrollController();
  final ScrollController _bodyHorizontalController = ScrollController();

  bool _syncingHeader = false;
  bool _syncingBody = false;

  DateTime selectedDate = _today();

  List<Map<String, dynamic>> reservations = [];
  List<Map<String, dynamic>> courts = [];
  List<Map<String, dynamic>> blockedSlots = [];

  bool isLoading = true;
  int? selectedCourtId;
  String? selectedSlotKey;
  String? pressedSlotKey;
  double zoom = 1.0;

  @override
  void initState() {
    super.initState();

    _dayPageController = PageController(
      initialPage: _initialDayPage(),
    );

    _headerHorizontalController.addListener(_syncHeaderToBody);
    _bodyHorizontalController.addListener(_syncBodyToHeader);

    _loadCalendarData();
  }

  @override
  void dispose() {
    _dayPageController.dispose();

    _headerHorizontalController
      ..removeListener(_syncHeaderToBody)
      ..dispose();

    _bodyHorizontalController
      ..removeListener(_syncBodyToHeader)
      ..dispose();

    super.dispose();
  }

  void _syncHeaderToBody() {
    if (_syncingBody) return;
    if (!_headerHorizontalController.hasClients ||
        !_bodyHorizontalController.hasClients) {
      return;
    }

    _syncingHeader = true;
    final target = _headerHorizontalController.offset.clamp(
      0.0,
      _bodyHorizontalController.position.maxScrollExtent,
    );
    _bodyHorizontalController.jumpTo(target);
    _syncingHeader = false;
  }

  void _syncBodyToHeader() {
    if (_syncingHeader) return;
    if (!_headerHorizontalController.hasClients ||
        !_bodyHorizontalController.hasClients) {
      return;
    }

    _syncingBody = true;
    final target = _bodyHorizontalController.offset.clamp(
      0.0,
      _headerHorizontalController.position.maxScrollExtent,
    );
    _headerHorizontalController.jumpTo(target);
    _syncingBody = false;
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

  DateTime _dateFromPage(int page) {
    return _calendarEpoch.add(Duration(days: page));
  }

  Future<void> _goToPreviousDay() async {
    if (!_dayPageController.hasClients) return;

    await _dayPageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goToNextDay() async {
    if (!_dayPageController.hasClients) return;

    await _dayPageController.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  String _dateToDb(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _dateForUi(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  String _weekdayForUi(DateTime date) {
    const names = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return names[date.weekday - 1];
  }

  String _shortTime(dynamic raw) {
    final text = (raw ?? '').toString();
    if (text.length >= 5) return text.substring(0, 5);
    return text;
  }

  String _slotKey({
    required int courtId,
    required String start,
    required String end,
  }) {
    return '$courtId|$start|$end';
  }

  Future<void> _loadCalendarData() async {
    _safeSetState(() => isLoading = true);

    try {
      final dateStr = _dateToDb(selectedDate);

      final courtsResponse = await Supabase.instance.client
          .from('courts')
          .select()
          .eq('venue_id', widget.venue['id'])
          .eq('is_active', true)
          .order('id', ascending: true);

      final reservationsResponse = await Supabase.instance.client
          .from('court_reservations')
          .select(
            '*, courts(name), profiles!court_reservations_user_id_fkey(full_name)',
          )
          .eq('venue_id', widget.venue['id'])
          .eq('reservation_date', dateStr)
          .order('start_time', ascending: true);

      final blockedResponse = await Supabase.instance.client
          .from('court_blocked_slots')
          .select()
          .eq('blocked_date', dateStr)
          .order('start_time', ascending: true);

      final loadedCourts = List<Map<String, dynamic>>.from(courtsResponse);

      _safeSetState(() {
        courts = loadedCourts;
        reservations = List<Map<String, dynamic>>.from(reservationsResponse);
        blockedSlots = List<Map<String, dynamic>>.from(blockedResponse);

        final currentExists =
            loadedCourts.any((c) => c['id'] == selectedCourtId);
        if (!currentExists) {
          selectedCourtId = null;
        }

        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() => isLoading = false);
      _showSnackBar('Error cargando calendario: $e');
    }
  }

  List<Map<String, String>> _generateHours() {
    final hours = <Map<String, String>>[];

    for (int i = 8; i < 24; i++) {
      hours.add({
        'start': '${i.toString().padLeft(2, '0')}:00',
        'end': '${(i + 1).toString().padLeft(2, '0')}:00',
      });
    }

    return hours;
  }

  Map<String, dynamic>? _findReservationForSlot({
    required int courtId,
    required String start,
    required String end,
  }) {
    for (final reservation in reservations) {
      final reservationCourtId = reservation['court_id'];
      final startTime = _shortTime(reservation['start_time']);
      final endTime = _shortTime(reservation['end_time']);
      final status = (reservation['status'] ?? '').toString();

      if (reservationCourtId == courtId &&
          startTime == start &&
          endTime == end &&
          status != 'cancelled' &&
          status != 'expired') {
        return reservation;
      }
    }

    return null;
  }

  Map<String, dynamic>? _findBlockedSlot({
    required int courtId,
    required String start,
    required String end,
  }) {
    for (final blocked in blockedSlots) {
      final blockedCourtId = blocked['court_id'];
      final startTime = _shortTime(blocked['start_time']);
      final endTime = _shortTime(blocked['end_time']);

      if (blockedCourtId == courtId &&
          startTime == start &&
          endTime == end) {
        return blocked;
      }
    }

    return null;
  }

  Color _slotColor(
    Map<String, dynamic>? reservation,
    Map<String, dynamic>? blocked,
  ) {
    if (blocked != null) return Colors.grey;
    if (reservation == null) return Colors.green;

    final status = (reservation['status'] ?? '').toString();
    if (status == 'confirmed') return Colors.red;
    if (status == 'pending_payment') return Colors.orange;
    return Colors.green;
  }

  String _slotStatusLabel(
    Map<String, dynamic>? reservation,
    Map<String, dynamic>? blocked,
  ) {
    if (blocked != null) return 'Bloqueado';
    if (reservation == null) return 'Disponible';

    final status = (reservation['status'] ?? '').toString();
    if (status == 'confirmed') return 'Reservada';
    if (status == 'pending_payment') return 'Pendiente';
    return 'Disponible';
  }

  String _slotPersonLabel(
    Map<String, dynamic>? reservation,
    Map<String, dynamic>? blocked,
  ) {
    if (blocked != null) {
      final reason = (blocked['reason'] ?? '').toString().trim();
      return reason.isNotEmpty ? reason : 'Bloqueado';
    }

    if (reservation == null) {
      return 'Libre';
    }

    final manualNote = (reservation['manual_note'] ?? '').toString().trim();
    if (manualNote.isNotEmpty) return manualNote;

    final profile = reservation['profiles'] as Map<String, dynamic>?;
    final fullName = (profile?['full_name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;

    return 'Reserva';
  }

  Future<void> _blockSlot({
    required int courtId,
    required String start,
    required String end,
  }) async {
    try {
      await Supabase.instance.client.from('court_blocked_slots').insert({
        'court_id': courtId,
        'blocked_date': _dateToDb(selectedDate),
        'start_time': start,
        'end_time': end,
        'reason': 'Bloqueado manualmente',
      });

      await _loadCalendarData();
      _showSnackBar('Horario bloqueado');
    } catch (e) {
      _showSnackBar('Error bloqueando horario: $e');
    }
  }

  Future<void> _unblockSlot(int blockedId) async {
    try {
      await Supabase.instance.client
          .from('court_blocked_slots')
          .delete()
          .eq('id', blockedId);

      await _loadCalendarData();
      _showSnackBar('Bloqueo eliminado');
    } catch (e) {
      _showSnackBar('Error eliminando bloqueo: $e');
    }
  }

  Future<void> _createManualReservation({
    required int courtId,
    required String start,
    required String end,
  }) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final priceController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reserva manual',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Fecha: ${_dateForUi(selectedDate)}'),
                Text('Horario: $start - $end'),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la reserva',
                    hintText: 'Ej: Juan / Amigo / Reserva externa',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto total (opcional)',
                    hintText: 'Ej: 120000',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Guardar'),
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

    if (confirmed != true) return;

    try {
      final noteName = nameController.text.trim();
      final notePhone = phoneController.text.trim();
      final parsedPrice =
          double.tryParse(priceController.text.trim().replaceAll(',', '.')) ?? 0;

      await Supabase.instance.client.from('court_reservations').insert({
        'court_id': courtId,
        'venue_id': widget.venue['id'],
        'reservation_date': _dateToDb(selectedDate),
        'start_time': start,
        'end_time': end,
        'status': 'confirmed',
        'payment_method': 'cash_venue',
        'payment_status': 'verified',
        'total_price': parsedPrice,
        'manual_note': noteName.isEmpty && notePhone.isEmpty
            ? 'Reserva manual'
            : 'Reserva manual - ${noteName.isEmpty ? 'Sin nombre' : noteName}${notePhone.isEmpty ? '' : ' - $notePhone'}',
      });

      await _loadCalendarData();
      _showSnackBar('Reserva manual creada');
    } catch (e) {
      _showSnackBar('Error creando reserva manual: $e');
    }
  }

  Future<void> _showFreeSlotActions({
    required Map<String, dynamic> court,
    required String start,
    required String end,
  }) async {
    final courtName = (court['name'] ?? 'Cancha').toString();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                courtName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text('Fecha: ${_dateForUi(selectedDate)}'),
              Text('Horario: $start - $end'),
              const SizedBox(height: 8),
              const Text('Estado: Disponible'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _blockSlot(
                          courtId: court['id'] as int,
                          start: start,
                          end: end,
                        );
                      },
                      child: const Text('Bloquear'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _createManualReservation(
                          courtId: court['id'] as int,
                          start: start,
                          end: end,
                        );
                      },
                      child: const Text('Reserva manual'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showBlockedSlotSheet({
    required Map<String, dynamic> court,
    required String start,
    required String end,
    required Map<String, dynamic> blocked,
  }) async {
    final courtName = (court['name'] ?? 'Cancha').toString();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final reason = (blocked['reason'] ?? '').toString().trim();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                courtName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text('Fecha: ${_dateForUi(selectedDate)}'),
              Text('Horario: $start - $end'),
              const SizedBox(height: 8),
              const Text('Estado: Bloqueado'),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Motivo: $reason'),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _unblockSlot(blocked['id'] as int);
                  },
                  child: const Text('Desbloquear'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReservationSheet({
    required Map<String, dynamic> court,
    required String start,
    required String end,
    required Map<String, dynamic> reservation,
  }) async {
    final courtName = (court['name'] ?? 'Cancha').toString();
    final profile = reservation['profiles'] as Map<String, dynamic>?;
    final playerName = (profile?['full_name'] ?? 'Jugador').toString();
    final status = (reservation['status'] ?? '').toString();
    final paymentMethod = (reservation['payment_method'] ?? '').toString();
    final paymentStatus = (reservation['payment_status'] ?? '').toString();
    final totalPrice = reservation['total_price'];
    final manualNote = (reservation['manual_note'] ?? '').toString();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courtName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Fecha: ${_dateForUi(selectedDate)}'),
                Text('Horario: $start - $end'),
                const SizedBox(height: 10),
                if (manualNote.trim().isNotEmpty) ...[
                  Text('Detalle: $manualNote'),
                  const SizedBox(height: 10),
                ],
                Text('Jugador: $playerName'),
                const SizedBox(height: 10),
                Text('Estado: ${_statusText(status)}'),
                Text('Método: ${_paymentMethodText(paymentMethod)}'),
                Text('Pago: ${_paymentStatusText(paymentStatus)}'),
                if (totalPrice != null) Text('Total: Gs. $totalPrice'),
                const SizedBox(height: 20),
                if (status == 'pending_payment') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _updateReservation(
                              reservationId: reservation['id'] as int,
                              status: 'cancelled',
                              paymentStatus: 'rejected',
                            );
                          },
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _updateReservation(
                              reservationId: reservation['id'] as int,
                              status: 'confirmed',
                              paymentStatus: 'verified',
                            );
                          },
                          child: const Text('Confirmar'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSlotDetail({
    required Map<String, dynamic> court,
    required String start,
    required String end,
    required Map<String, dynamic>? reservation,
    required Map<String, dynamic>? blocked,
  }) async {
    if (blocked != null) {
      await _showBlockedSlotSheet(
        court: court,
        start: start,
        end: end,
        blocked: blocked,
      );
      return;
    }

    if (reservation == null) {
      await _showFreeSlotActions(
        court: court,
        start: start,
        end: end,
      );
      return;
    }

    await _showReservationSheet(
      court: court,
      start: start,
      end: end,
      reservation: reservation,
    );
  }

  Future<void> _updateReservation({
    required int reservationId,
    required String status,
    String? paymentStatus,
  }) async {
    try {
      final data = <String, dynamic>{'status': status};

      if (paymentStatus != null) {
        data['payment_status'] = paymentStatus;
      }

      await Supabase.instance.client
          .from('court_reservations')
          .update(data)
          .eq('id', reservationId);

      await _loadCalendarData();
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

  Widget _buildHeaderRow({
    required ThemeData theme,
    required double timeColumnWidth,
    required double headerHeight,
    required double courtColumnWidth,
    required bool smallPhone,
    required List<Map<String, dynamic>> visibleCourts,
  }) {
    return Row(
      children: [
        SizedBox(
          width: timeColumnWidth,
          height: headerHeight,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: headerHeight,
            child: Scrollbar(
              controller: _headerHorizontalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _headerHorizontalController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: visibleCourts.map((court) {
                    return Container(
                      width: courtColumnWidth,
                      height: headerHeight,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.18),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (court['name'] ?? 'Cancha').toString(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: smallPhone ? 13 : 14,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyGrid({
    required ThemeData theme,
    required List<Map<String, String>> hours,
    required double timeColumnWidth,
    required double slotHeight,
    required double courtColumnWidth,
    required bool smallPhone,
    required List<Map<String, dynamic>> visibleCourts,
  }) {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: timeColumnWidth,
            child: Column(
              children: hours.map((h) {
                final start = h['start']!;
                final end = h['end']!;

                return Container(
                  width: timeColumnWidth,
                  height: slotHeight,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.18),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$start\n$end',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: smallPhone ? 11 : 12,
                        height: 1.25,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Scrollbar(
              controller: _bodyHorizontalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _bodyHorizontalController,
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: hours.map((h) {
                    final start = h['start']!;
                    final end = h['end']!;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: visibleCourts.map((court) {
                          final reservation = _findReservationForSlot(
                            courtId: court['id'] as int,
                            start: start,
                            end: end,
                          );

                          final blocked = _findBlockedSlot(
                            courtId: court['id'] as int,
                            start: start,
                            end: end,
                          );

                          final color = _slotColor(reservation, blocked);
                          final statusLabel =
                              _slotStatusLabel(reservation, blocked);
                          final personLabel =
                              _slotPersonLabel(reservation, blocked);

                          final slotKey = _slotKey(
                            courtId: court['id'] as int,
                            start: start,
                            end: end,
                          );

                          final isSelected = selectedSlotKey == slotKey;
                          final isPressed = pressedSlotKey == slotKey;

                          return Container(
                            width: courtColumnWidth,
                            height: slotHeight,
                            margin: const EdgeInsets.only(right: 10),
                            child: _AnimatedCalendarSlot(
                              color: color,
                              start: start,
                              end: end,
                              statusLabel: statusLabel,
                              personLabel: personLabel,
                              isSelected: isSelected,
                              isPressed: isPressed,
                              smallPhone: smallPhone,
                              onTapDown: () {
                                _safeSetState(() {
                                  pressedSlotKey = slotKey;
                                });
                              },
                              onTapCancel: () {
                                _safeSetState(() {
                                  if (pressedSlotKey == slotKey) {
                                    pressedSlotKey = null;
                                  }
                                });
                              },
                              onTap: () async {
                                _safeSetState(() {
                                  selectedSlotKey = slotKey;
                                  pressedSlotKey = null;
                                });

                                await _showSlotDetail(
                                  court: court,
                                  start: start,
                                  end: end,
                                  reservation: reservation,
                                  blocked: blocked,
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = _generateHours();
    final venueName = (widget.venue['name'] ?? 'Calendario').toString();

    final visibleCourts = selectedCourtId == null
        ? courts
        : courts.where((court) => court['id'] == selectedCourtId).toList();

    final width = MediaQuery.of(context).size.width;
    final smallPhone = width < 380;

    final timeColumnWidth = smallPhone ? 76.0 : 84.0;
    final courtColumnWidth = (smallPhone ? 184.0 : 210.0) * zoom;
    final slotHeight = (smallPhone ? 92.0 : 102.0) * zoom;
    const headerHeight = 56.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendario - $venueName'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                IconButton(
                  onPressed: _goToPreviousDay,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: SizedBox(
                    height: 78,
                    child: PageView.builder(
                      controller: _dayPageController,
                      onPageChanged: (page) async {
                        final newDate = _dateFromPage(page);

                        _safeSetState(() {
                          selectedDate = newDate;
                          selectedSlotKey = null;
                          pressedSlotKey = null;
                        });

                        await _loadCalendarData();
                      },
                      itemBuilder: (context, index) {
                        final date = _dateFromPage(index);

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withOpacity(0.22),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _dateForUi(date),
                                style: TextStyle(
                                  fontSize: smallPhone ? 18 : 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _weekdayForUi(date),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _goToNextDay,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: selectedCourtId,
                    decoration: const InputDecoration(
                      labelText: 'Cancha',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todas las canchas'),
                      ),
                      ...courts.map(
                        (court) => DropdownMenuItem<int?>(
                          value: court['id'] as int,
                          child: Text((court['name'] ?? 'Cancha').toString()),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      _safeSetState(() {
                        selectedCourtId = value;
                        selectedSlotKey = null;
                        pressedSlotKey = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _ZoomButton(
                  label: 'A-',
                  onTap: () {
                    _safeSetState(() {
                      zoom = (zoom - 0.1).clamp(0.85, 1.35);
                    });
                  },
                ),
                const SizedBox(width: 8),
                _ZoomButton(
                  label: 'A+',
                  onTap: () {
                    _safeSetState(() {
                      zoom = (zoom + 0.1).clamp(0.85, 1.35);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: isLoading
                  ? const Center(
                      key: ValueKey('loading'),
                      child: CircularProgressIndicator(),
                    )
                  : visibleCourts.isEmpty
                      ? const Center(
                          key: ValueKey('empty'),
                          child: Text('No hay canchas activas para mostrar'),
                        )
                      : Padding(
                          key: ValueKey(
                            '${_dateToDb(selectedDate)}-${selectedCourtId ?? 'all'}',
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              _buildHeaderRow(
                                theme: theme,
                                timeColumnWidth: timeColumnWidth,
                                headerHeight: headerHeight,
                                courtColumnWidth: courtColumnWidth,
                                smallPhone: smallPhone,
                                visibleCourts: visibleCourts,
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: _buildBodyGrid(
                                  theme: theme,
                                  hours: hours,
                                  timeColumnWidth: timeColumnWidth,
                                  slotHeight: slotHeight,
                                  courtColumnWidth: courtColumnWidth,
                                  smallPhone: smallPhone,
                                  visibleCourts: visibleCourts,
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedCalendarSlot extends StatelessWidget {
  final Color color;
  final String start;
  final String end;
  final String statusLabel;
  final String personLabel;
  final bool isSelected;
  final bool isPressed;
  final bool smallPhone;
  final VoidCallback onTap;
  final VoidCallback onTapDown;
  final VoidCallback onTapCancel;

  const _AnimatedCalendarSlot({
    required this.color,
    required this.start,
    required this.end,
    required this.statusLabel,
    required this.personLabel,
    required this.isSelected,
    required this.isPressed,
    required this.smallPhone,
    required this.onTap,
    required this.onTapDown,
    required this.onTapCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scale = isPressed ? 0.97 : 1.0;
    final shadowOpacity = isSelected ? 0.18 : 0.10;
    final borderWidth = isSelected ? 2.0 : 1.2;
    final bgOpacity = isSelected ? 0.20 : 0.13;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: color.withOpacity(bgOpacity),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color,
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(shadowOpacity),
              blurRadius: isSelected ? 18 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            splashColor: color.withOpacity(0.18),
            highlightColor: color.withOpacity(0.08),
            onTapDown: (_) => onTapDown(),
            onTapCancel: onTapCancel,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: smallPhone ? 8 : 10,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: smallPhone ? 155 : 175,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$start - $end',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: smallPhone ? 12 : 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: smallPhone ? 12 : 13,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          personLabel,
                          style: TextStyle(
                            fontSize: smallPhone ? 11 : 12,
                            color: color.withOpacity(0.95),
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ZoomButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}