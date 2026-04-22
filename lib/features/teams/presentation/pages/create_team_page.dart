import 'package:flutter/material.dart';

import '../../data/team_service.dart';

class CreateTeamPage extends StatefulWidget {
  const CreateTeamPage({super.key});

  @override
  State<CreateTeamPage> createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends State<CreateTeamPage> {
  final TeamService _service = TeamService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  bool isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final teamId = await _service.createTeam(
        name: _nameController.text.trim(),
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, teamId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creando equipo: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return 'Ingresá $label';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear equipo'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Creá tu equipo para invitar amigos y usarlo en torneos más adelante.',
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    validator: (v) => _required(v, 'el nombre del equipo'),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del equipo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityController,
                    validator: (v) => _required(v, 'la ciudad'),
                    decoration: const InputDecoration(
                      labelText: 'Ciudad',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _countryController,
                    validator: (v) => _required(v, 'el país'),
                    decoration: const InputDecoration(
                      labelText: 'País',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isSaving ? null : _save,
                      child: Text(
                        isSaving ? 'Creando...' : 'Crear equipo',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}