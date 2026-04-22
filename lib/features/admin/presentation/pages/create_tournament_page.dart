import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../tournaments/data/tournament_remote_service.dart';

class CreateTournamentPage extends StatefulWidget {
  const CreateTournamentPage({super.key});

  @override
  State<CreateTournamentPage> createState() => _CreateTournamentPageState();
}

class _CreateTournamentPageState extends State<CreateTournamentPage> {
  final _formKey = GlobalKey<FormState>();
  final TournamentRemoteService _remoteService = TournamentRemoteService();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController teamsController = TextEditingController();
  final TextEditingController individualCostController =
      TextEditingController();
  final TextEditingController teamCostController = TextEditingController();
  final TextEditingController prizesController = TextEditingController();
  final TextEditingController startDateController = TextEditingController();

  String tournamentType = 'Liga';
  String gameMode = '5 vs 5';
  String category = 'Masculino';
  String tieBreaker = 'Penales';
  String duration = '40 minutos';
  String joinMode = 'both';

  bool hasReferees = true;
  bool hasOffside = false;
  bool hasCardSanctions = true;
  bool acceptedTerms = false;
  bool isLoading = false;
  bool isOfficial = false;

  bool canCreateOfficial = false;
  bool loadingPermissions = true;
  String currentRole = 'player';
  bool currentVerified = false;

  String? generatedCode;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    teamsController.dispose();
    individualCostController.dispose();
    teamCostController.dispose();
    prizesController.dispose();
    startDateController.dispose();
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

  Future<void> _loadPermissions() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _safeSetState(() {
        loadingPermissions = false;
      });
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role, verified')
          .eq('id', user.id)
          .maybeSingle();

      final role = (profile?['role'] ?? 'player').toString().trim();
      final verified = profile?['verified'] == true;

      final allowed = verified &&
          (role == 'organizer' ||
              role == 'venue' ||
              role == 'admin' ||
              role == 'super_admin');

      _safeSetState(() {
        currentRole = role;
        currentVerified = verified;
        canCreateOfficial = allowed;
        loadingPermissions = false;
      });
    } catch (_) {
      _safeSetState(() {
        loadingPermissions = false;
      });
      _showSnackBar('No se pudieron cargar los permisos');
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );

    if (picked == null) return;

    final formatted =
        '${picked.day.toString().padLeft(2, '0')}/'
        '${picked.month.toString().padLeft(2, '0')}/'
        '${picked.year}';

    _safeSetState(() {
      startDateController.text = formatted;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (!acceptedTerms) {
      _showSnackBar('Tenés que aceptar los términos y condiciones.');
      return;
    }

    if (isOfficial && !canCreateOfficial) {
      _showSnackBar(
        'Solo perfiles verificados como organizador, cancha o administradores pueden crear torneos oficiales.',
      );
      return;
    }

    _safeSetState(() {
      isLoading = true;
    });

    try {
      String? code;
      if (tournamentType == 'Por invitación') {
        code = _generateInviteCode();
      }

      final teamsCount = int.tryParse(teamsController.text.trim()) ?? 0;
      final entryFeeIndividual =
          double.tryParse(individualCostController.text.trim());
      final entryFeeTeam = double.tryParse(teamCostController.text.trim());

      await _remoteService.createTournament(
        name: nameController.text.trim(),
        location: locationController.text.trim(),
        tournamentType: tournamentType,
        gameMode: gameMode,
        category: category,
        isOfficial: isOfficial,
        inviteCode: code,
        startDate: startDateController.text.trim(),
        teamsCount: teamsCount,
        prizes: prizesController.text.trim(),
        joinMode: joinMode,
        hasReferees: hasReferees,
        hasOffside: hasOffside,
        hasCardSanctions: hasCardSanctions,
        duration: duration,
        tieBreaker: tieBreaker,
        entryFeeIndividual: entryFeeIndividual,
        entryFeeTeam: entryFeeTeam,
      );

      _safeSetState(() {
        generatedCode = code;
      });

      _showSnackBar(
        tournamentType == 'Por invitación'
            ? 'Torneo guardado. Código: $code'
            : 'Torneo guardado correctamente.',
      );
    } catch (e) {
      _showSnackBar('Error al guardar torneo: $e');
    } finally {
      _safeSetState(() {
        isLoading = false;
      });
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'organizer':
        return 'Organizador';
      case 'venue':
        return 'Cancha';
      case 'admin':
        return 'Administrador';
      case 'super_admin':
        return 'Super administrador';
      default:
        return 'Jugador';
    }
  }

  String _officialSubtitle() {
    if (loadingPermissions) {
      return 'Verificando permisos...';
    }

    if (canCreateOfficial) {
      return 'Tu perfil está habilitado para crear torneos oficiales.';
    }

    if (!currentVerified) {
      return 'Necesitás tener el perfil verificado para activar esta opción.';
    }

    return 'Solo perfiles verificados como organizador, cancha o administradores pueden activar esta opción.';
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresá $label';
    }
    return null;
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _glassCard(BuildContext context, Widget child) {
    final theme = Theme.of(context);

    return Container(
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
      child: child,
    );
  }

  Widget _joinModeTile({
    required BuildContext context,
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isSelected = joinMode == value;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        _safeSetState(() {
          joinMode = value;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.8)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withOpacity(0.22),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear torneo'),
      ),
      body: loadingPermissions
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.14),
                            theme.colorScheme.primaryContainer.withOpacity(0.28),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color:
                              theme.colorScheme.outlineVariant.withOpacity(0.22),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Configurá tu torneo',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Completá los datos principales para publicar un torneo.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _glassCard(
                            context,
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.verified_user_outlined,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tu rol actual: ${_roleLabel(currentRole)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          currentVerified
                                              ? 'Perfil verificado'
                                              : 'Perfil no verificado',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    _sectionTitle(
                      context,
                      'Información principal',
                      'Los datos básicos que van a ver los jugadores',
                    ),
                    const SizedBox(height: 14),
                    _glassCard(
                      context,
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: nameController,
                              decoration:
                                  _inputDecoration('Nombre del torneo'),
                              validator: (value) => _requiredValidator(
                                value,
                                'el nombre del torneo',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: locationController,
                              decoration: _inputDecoration('Ubicación'),
                              validator: (value) =>
                                  _requiredValidator(value, 'la ubicación'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: tournamentType,
                              decoration:
                                  _inputDecoration('Tipo de torneo'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Liga',
                                  child: Text('Liga'),
                                ),
                                DropdownMenuItem(
                                  value: 'Eliminatoria',
                                  child: Text('Eliminatoria'),
                                ),
                                DropdownMenuItem(
                                  value: 'Relámpago',
                                  child: Text('Relámpago'),
                                ),
                                DropdownMenuItem(
                                  value: 'Por invitación',
                                  child: Text('Por invitación'),
                                ),
                              ],
                              onChanged: (value) {
                                _safeSetState(() {
                                  tournamentType = value ?? 'Liga';
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: gameMode,
                              decoration:
                                  _inputDecoration('Modalidad de juego'),
                              items: const [
                                DropdownMenuItem(
                                  value: '5 vs 5',
                                  child: Text('5 vs 5'),
                                ),
                                DropdownMenuItem(
                                  value: '6 vs 6',
                                  child: Text('6 vs 6'),
                                ),
                                DropdownMenuItem(
                                  value: '7 vs 7',
                                  child: Text('7 vs 7'),
                                ),
                                DropdownMenuItem(
                                  value: '8 vs 8',
                                  child: Text('8 vs 8'),
                                ),
                                DropdownMenuItem(
                                  value: '11 vs 11',
                                  child: Text('11 vs 11'),
                                ),
                              ],
                              onChanged: (value) {
                                _safeSetState(() {
                                  gameMode = value ?? '5 vs 5';
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: category,
                              decoration: _inputDecoration('Categoría'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Masculino',
                                  child: Text('Masculino'),
                                ),
                                DropdownMenuItem(
                                  value: 'Femenino',
                                  child: Text('Femenino'),
                                ),
                                DropdownMenuItem(
                                  value: 'Mixto',
                                  child: Text('Mixto'),
                                ),
                              ],
                              onChanged: (value) {
                                _safeSetState(() {
                                  category = value ?? 'Masculino';
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: startDateController,
                              readOnly: true,
                              onTap: _pickStartDate,
                              decoration: _inputDecoration(
                                'Fecha de inicio',
                                hint: 'Seleccionar fecha',
                              ).copyWith(
                                suffixIcon:
                                    const Icon(Icons.calendar_month_outlined),
                              ),
                              validator: (value) => _requiredValidator(
                                value,
                                'la fecha de inicio',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: teamsController,
                              keyboardType: TextInputType.number,
                              decoration:
                                  _inputDecoration('Cantidad de equipos'),
                              validator: (value) => _requiredValidator(
                                value,
                                'la cantidad de equipos',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _sectionTitle(
                      context,
                      'Modo de inscripción',
                      'Definí si entran jugadores, equipos o ambos',
                    ),
                    const SizedBox(height: 14),
                    _glassCard(
                      context,
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _joinModeTile(
                              context: context,
                              value: 'players',
                              icon: Icons.person_outline,
                              title: 'Jugadores',
                              subtitle: 'Solo jugadores individuales',
                            ),
                            const SizedBox(height: 10),
                            _joinModeTile(
                              context: context,
                              value: 'teams',
                              icon: Icons.groups_2_outlined,
                              title: 'Equipos',
                              subtitle: 'Solo equipos completos',
                            ),
                            const SizedBox(height: 10),
                            _joinModeTile(
                              context: context,
                              value: 'both',
                              icon: Icons.compare_arrows_outlined,
                              title: 'Ambos',
                              subtitle:
                                  'Jugadores y equipos pueden inscribirse',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _sectionTitle(
                      context,
                      'Costos y premios',
                      'Mostrá claramente cuánto cuesta inscribirse',
                    ),
                    const SizedBox(height: 14),
                    _glassCard(
                      context,
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: individualCostController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(
                                'Costo de inscripción individual',
                                hint: 'Ej: 50000',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: teamCostController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(
                                'Costo de inscripción por equipo',
                                hint: 'Ej: 350000',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: prizesController,
                              decoration: _inputDecoration(
                                'Premios',
                                hint: 'Ej: trofeo + efectivo + medallas',
                              ),
                              validator: (value) =>
                                  _requiredValidator(value, 'los premios'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _sectionTitle(
                      context,
                      'Configuración especial',
                      'Opciones avanzadas y visibilidad del torneo',
                    ),
                    const SizedBox(height: 14),
                    _glassCard(
                      context,
                      SwitchListTile(
                        value: isOfficial,
                        onChanged: canCreateOfficial
                            ? (value) {
                                _safeSetState(() {
                                  isOfficial = value;
                                });
                              }
                            : null,
                        title: const Text(
                          'Torneo oficial',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(_officialSubtitle()),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _sectionTitle(
                      context,
                      'Reglas del torneo',
                      'Definí las condiciones principales del partido',
                    ),
                    const SizedBox(height: 14),
                    _glassCard(
                      context,
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SwitchListTile(
                            value: hasReferees,
                            onChanged: (value) {
                              _safeSetState(() {
                                hasReferees = value;
                              });
                            },
                            title: const Text('¿Con árbitros?'),
                          ),
                          SwitchListTile(
                            value: hasOffside,
                            onChanged: (value) {
                              _safeSetState(() {
                                hasOffside = value;
                              });
                            },
                            title: const Text('¿Se aplica offside?'),
                          ),
                          SwitchListTile(
                            value: hasCardSanctions,
                            onChanged: (value) {
                              _safeSetState(() {
                                hasCardSanctions = value;
                              });
                            },
                            title: const Text('¿Sanciones por tarjetas?'),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: DropdownButtonFormField<String>(
                              initialValue: duration,
                              decoration:
                                  _inputDecoration('Duración del partido'),
                              items: const [
                                DropdownMenuItem(
                                  value: '20 minutos',
                                  child: Text('20 minutos'),
                                ),
                                DropdownMenuItem(
                                  value: '30 minutos',
                                  child: Text('30 minutos'),
                                ),
                                DropdownMenuItem(
                                  value: '40 minutos',
                                  child: Text('40 minutos'),
                                ),
                                DropdownMenuItem(
                                  value: '50 minutos',
                                  child: Text('50 minutos'),
                                ),
                              ],
                              onChanged: (value) {
                                _safeSetState(() {
                                  duration = value ?? '40 minutos';
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: DropdownButtonFormField<String>(
                              initialValue: tieBreaker,
                              decoration:
                                  _inputDecoration('En caso de empate'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Gol de oro',
                                  child: Text('Gol de oro'),
                                ),
                                DropdownMenuItem(
                                  value: 'Penales',
                                  child: Text('Penales'),
                                ),
                              ],
                              onChanged: (value) {
                                _safeSetState(() {
                                  tieBreaker = value ?? 'Penales';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    _glassCard(
                      context,
                      CheckboxListTile(
                        value: acceptedTerms,
                        onChanged: (value) {
                          _safeSetState(() {
                            acceptedTerms = value ?? false;
                          });
                        },
                        title: const Text(
                          'Acepto los términos y condiciones',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Confirmo que la información cargada del torneo es correcta.',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),

                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isLoading ? null : _submitForm,
                        icon: const Icon(Icons.emoji_events_outlined),
                        label: Text(
                          isLoading ? 'Guardando...' : 'Crear torneo',
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    if (tournamentType == 'Por invitación' &&
                        generatedCode != null)
                      _glassCard(
                        context,
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.qr_code_2,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Código generado: $generatedCode',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}