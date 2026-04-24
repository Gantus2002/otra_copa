import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/team_service.dart';

class CreateTeamPage extends StatefulWidget {
  final Map<String, dynamic>? team;

  const CreateTeamPage({
    super.key,
    this.team,
  });

  @override
  State<CreateTeamPage> createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends State<CreateTeamPage> {
  final TeamService _service = TeamService();
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();

  bool isSaving = false;
  File? selectedLogo;
  String? logoUrl;

  String selectedCountry = 'Paraguay';
  String selectedCity = 'Asunción';

  final Map<String, List<String>> citiesByCountry = const {
    'Paraguay': [
      'Asunción',
      'Luque',
      'San Lorenzo',
      'Fernando de la Mora',
      'Lambaré',
      'Capiatá',
      'Ciudad del Este',
      'Encarnación',
    ],
    'Argentina': [
      'Formosa',
      'Clorinda',
      'Corrientes',
      'Resistencia',
      'Buenos Aires',
      'Córdoba',
    ],
    'Brasil': [
      'Foz do Iguaçu',
      'Curitiba',
      'São Paulo',
    ],
    'Uruguay': [
      'Montevideo',
      'Ciudad de la Costa',
    ],
    'Chile': [
      'Santiago',
      'Valparaíso',
    ],
  };

  bool get isEditing => widget.team != null;

  @override
  void initState() {
    super.initState();

    final team = widget.team;

    if (team != null) {
      _nameController.text = (team['name'] ?? '').toString();
      selectedCountry = (team['country'] ?? 'Paraguay').toString();
      selectedCity = (team['city'] ?? 'Asunción').toString();
      logoUrl = team['logo_url']?.toString();

      if (!citiesByCountry.containsKey(selectedCountry)) {
        selectedCountry = 'Paraguay';
      }

      if (!citiesByCountry[selectedCountry]!.contains(selectedCity)) {
        selectedCity = citiesByCountry[selectedCountry]!.first;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<String> get availableCities => citiesByCountry[selectedCountry] ?? [];

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );

    if (picked == null) return;

    setState(() {
      selectedLogo = File(picked.path);
    });
  }

  Future<String?> _uploadLogo() async {
    if (selectedLogo == null) return logoUrl;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return logoUrl;

    final fileName =
        'team_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await Supabase.instance.client.storage.from('team-logos').upload(
          fileName,
          selectedLogo!,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    return Supabase.instance.client.storage
        .from('team-logos')
        .getPublicUrl(fileName);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final finalLogoUrl = await _uploadLogo();

      if (isEditing) {
        await _service.updateTeam(
          teamId: widget.team!['id'] as int,
          name: _nameController.text.trim(),
          city: selectedCity,
          country: selectedCountry,
          logoUrl: finalLogoUrl,
        );

        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        final teamId = await _service.createTeam(
          name: _nameController.text.trim(),
          city: selectedCity,
          country: selectedCountry,
          logoUrl: finalLogoUrl,
        );

        if (!mounted) return;
        Navigator.pop(context, teamId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando equipo: $e')),
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

  Widget _logoPreview(ThemeData theme) {
    if (selectedLogo != null) {
      return ClipOval(
        child: Image.file(
          selectedLogo!,
          width: 86,
          height: 86,
          fit: BoxFit.cover,
        ),
      );
    }

    if (logoUrl != null && logoUrl!.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          logoUrl!,
          width: 86,
          height: 86,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _logoFallback(theme),
        ),
      );
    }

    return _logoFallback(theme);
  }

  Widget _logoFallback(ThemeData theme) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primaryContainer,
      ),
      child: Icon(
        Icons.shield_outlined,
        size: 38,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar equipo' : 'Crear equipo'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0F3144),
                    Color(0xFF174B61),
                    Color(0xFF1D6A77),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickLogo,
                    child: Stack(
                      children: [
                        _logoPreview(theme),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.photo_camera_outlined,
                              size: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Actualizá los datos de tu equipo'
                          : 'Crealo una vez y usalo para torneos, invitaciones y rankings.',
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1.3,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos del equipo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nameController,
                      validator: (v) => _required(v, 'el nombre del equipo'),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nombre del equipo',
                        hintText: 'Ej: Americans FC',
                        prefixIcon: const Icon(Icons.shield_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedCountry,
                      decoration: InputDecoration(
                        labelText: 'País',
                        prefixIcon: const Icon(Icons.public),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      items: citiesByCountry.keys
                          .map(
                            (country) => DropdownMenuItem(
                              value: country,
                              child: Text(country),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedCountry = value;
                          selectedCity = citiesByCountry[value]!.first;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedCity,
                      decoration: InputDecoration(
                        labelText: 'Ciudad',
                        prefixIcon: const Icon(Icons.location_city),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      items: availableCities
                          .map(
                            (city) => DropdownMenuItem(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedCity = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ubicación: $selectedCity, $selectedCountry',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: isSaving ? null : _save,
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(isEditing ? Icons.save_outlined : Icons.add_circle_outline),
                        label: Text(
                          isSaving
                              ? 'Guardando...'
                              : isEditing
                                  ? 'Guardar cambios'
                                  : 'Crear equipo',
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
    );
  }
}