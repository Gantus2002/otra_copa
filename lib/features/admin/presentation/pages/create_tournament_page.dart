import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  String? generatedCode;

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    teamsController.dispose();
    costController.dispose();
    prizesController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tenés que aceptar los términos y condiciones.'),
        ),
      );
      return;
    }

    setState(() {
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
        inviteCode: code,
      );

      setState(() {
        generatedCode = code;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tournamentType == 'Por invitación'
                ? 'Torneo guardado en Supabase. Código: $code'
                : 'Torneo guardado en Supabase.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar torneo: $e'),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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
                initialValue: tournamentType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de torneo',
                ),
                items: const [
                  DropdownMenuItem(value: 'Liga', child: Text('Liga')),
                  DropdownMenuItem(value: 'Eliminatoria', child: Text('Eliminatoria')),
                  DropdownMenuItem(value: 'Relámpago', child: Text('Relámpago')),
                  DropdownMenuItem(value: 'Por invitación', child: Text('Por invitación')),
                ],
                onChanged: (value) {
                  setState(() {
                    tournamentType = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: gameMode,
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
                  setState(() {
                    gameMode = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                ),
                items: const [
                  DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                  DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                  DropdownMenuItem(value: 'Mixto', child: Text('Mixto')),
                ],
                onChanged: (value) {
                  setState(() {
                    category = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
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
                  setState(() {
                    hasReferees = value;
                  });
                },
                title: const Text('¿Con árbitros?'),
              ),
              SwitchListTile(
                value: hasOffside,
                onChanged: (value) {
                  setState(() {
                    hasOffside = value;
                  });
                },
                title: const Text('¿Se aplica offside?'),
              ),
              SwitchListTile(
                value: hasCardSanctions,
                onChanged: (value) {
                  setState(() {
                    hasCardSanctions = value;
                  });
                },
                title: const Text('¿Sanciones por tarjetas?'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: duration,
                decoration: const InputDecoration(
                  labelText: 'Duración del partido',
                ),
                items: const [
                  DropdownMenuItem(value: '20 minutos', child: Text('20 minutos')),
                  DropdownMenuItem(value: '30 minutos', child: Text('30 minutos')),
                  DropdownMenuItem(value: '40 minutos', child: Text('40 minutos')),
                  DropdownMenuItem(value: '50 minutos', child: Text('50 minutos')),
                ],
                onChanged: (value) {
                  setState(() {
                    duration = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tieBreaker,
                decoration: const InputDecoration(
                  labelText: 'En caso de empate',
                ),
                items: const [
                  DropdownMenuItem(value: 'Gol de oro', child: Text('Gol de oro')),
                  DropdownMenuItem(value: 'Penales', child: Text('Penales')),
                ],
                onChanged: (value) {
                  setState(() {
                    tieBreaker = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: acceptedTerms,
                onChanged: (value) {
                  setState(() {
                    acceptedTerms = value ?? false;
                  });
                },
                title: const Text('Acepto los términos y condiciones'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _submitForm,
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