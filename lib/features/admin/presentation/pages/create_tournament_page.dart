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
  final TextEditingController costController = TextEditingController();
  final TextEditingController prizesController = TextEditingController();
  final TextEditingController startDateController = TextEditingController();

  String tournamentType = 'Liga';
  String gameMode = '5 vs 5';
  String category = 'Masculino';
  String tieBreaker = 'Penales';
  String duration = '40 minutos';

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
    } catch (e) {
      _safeSetState(() {
        loadingPermissions = false;
      });
      _showSnackBar('No se pudieron cargar los permisos');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    teamsController.dispose();
    costController.dispose();
    prizesController.dispose();
    startDateController.dispose();
    super.dispose();
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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

      await _remoteService.createTournament(
        name: nameController.text.trim(),
        location: locationController.text.trim(),
        tournamentType: tournamentType,
        gameMode: gameMode,
        category: category,
        isOfficial: isOfficial,
        inviteCode: code,
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
      case 'player':
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear torneo'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Configurá tu torneo',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Completá los datos principales para publicar un torneo.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tu rol actual: ${_roleLabel(currentRole)}'),
                      const SizedBox(height: 4),
                      Text(
                        currentVerified
                            ? 'Perfil verificado'
                            : 'Perfil no verificado',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del torneo',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresá el nombre del torneo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Ubicación',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresá la ubicación';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tournamentType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de torneo',
                ),
                items: const [
                  DropdownMenuItem(value: 'Liga', child: Text('Liga')),
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
                value: gameMode,
                decoration: const InputDecoration(
                  labelText: 'Modalidad de juego',
                ),
                items: const [
                  DropdownMenuItem(value: '5 vs 5', child: Text('5 vs 5')),
                  DropdownMenuItem(value: '6 vs 6', child: Text('6 vs 6')),
                  DropdownMenuItem(value: '7 vs 7', child: Text('7 vs 7')),
                  DropdownMenuItem(value: '8 vs 8', child: Text('8 vs 8')),
                  DropdownMenuItem(value: '11 vs 11', child: Text('11 vs 11')),
                ],
                onChanged: (value) {
                  _safeSetState(() {
                    gameMode = value ?? '5 vs 5';
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Masculino',
                    child: Text('Masculino'),
                  ),
                  DropdownMenuItem(
                    value: 'Femenino',
                    child: Text('Femenino'),
                  ),
                  DropdownMenuItem(value: 'Mixto', child: Text('Mixto')),
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
                decoration: const InputDecoration(
                  labelText: 'Fecha de inicio',
                  hintText: 'Ej: 25/04/2026',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresá la fecha de inicio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: teamsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad de equipos',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresá la cantidad de equipos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Costo de inscripción por equipo',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresá el costo de inscripción';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: prizesController,
                decoration: const InputDecoration(
                  labelText: 'Premios',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresá los premios';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Card(
                child: SwitchListTile(
                  value: isOfficial,
                  onChanged: canCreateOfficial
                      ? (value) {
                          _safeSetState(() {
                            isOfficial = value;
                          });
                        }
                      : null,
                  title: const Text('Torneo oficial'),
                  subtitle: Text(_officialSubtitle()),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Reglas del torneo',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: duration,
                decoration: const InputDecoration(
                  labelText: 'Duración del partido',
                ),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tieBreaker,
                decoration: const InputDecoration(
                  labelText: 'En caso de empate',
                ),
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
              const SizedBox(height: 20),
              CheckboxListTile(
                value: acceptedTerms,
                onChanged: (value) {
                  _safeSetState(() {
                    acceptedTerms = value ?? false;
                  });
                },
                title: const Text('Acepto los términos y condiciones'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading || loadingPermissions ? null : _submitForm,
                child: Text(isLoading ? 'Guardando...' : 'Crear torneo'),
              ),
              const SizedBox(height: 16),
              if (tournamentType == 'Por invitación' && generatedCode != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Código generado: $generatedCode',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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