import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCourtFormPage extends StatefulWidget {
  final Map<String, dynamic> venue;
  final Map<String, dynamic>? court;

  const AdminCourtFormPage({
    super.key,
    required this.venue,
    this.court,
  });

  @override
  State<AdminCourtFormPage> createState() => _AdminCourtFormPageState();
}

class _AdminCourtFormPageState extends State<AdminCourtFormPage> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();

  bool isSaving = false;
  bool isIndoor = false;

  final List<String> sportTypes = const [
    'Fútbol 5',
    'Fútbol 6',
    'Fútbol 7',
    'Fútbol 8',
    'Fútbol 11',
    'Pádel',
    'Tenis',
    'Vóley',
    'Básquet',
    'Squash',
  ];

  final List<String> surfaceTypes = const [
    'Sintético',
    'Cemento',
    'Parquet',
    'Tierra batida',
    'Césped natural',
    'Goma',
  ];

  String? selectedSportType;
  String? selectedSurfaceType;

  @override
  void initState() {
    super.initState();

    if (widget.court != null) {
      final c = widget.court!;
      nameController.text = (c['name'] ?? '').toString();
      descriptionController.text = (c['description'] ?? '').toString();
      priceController.text = (c['price_per_hour'] ?? '').toString();
      selectedSportType = (c['sport_type'] ?? '').toString().trim().isEmpty
          ? null
          : (c['sport_type'] ?? '').toString();
      selectedSurfaceType = (c['surface_type'] ?? '').toString().trim().isEmpty
          ? null
          : (c['surface_type'] ?? '').toString();
      isIndoor = c['is_indoor'] == true;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (nameController.text.trim().isEmpty || selectedSportType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nombre y tipo de deporte son obligatorios'),
        ),
      );
      return;
    }

    final parsedPrice = double.tryParse(
      priceController.text.trim().replaceAll(',', '.'),
    );

    setState(() {
      isSaving = true;
    });

    try {
      final data = {
        'venue_id': widget.venue['id'],
        'name': nameController.text.trim(),
        'sport_type': selectedSportType,
        'surface_type': selectedSurfaceType,
        'description': descriptionController.text.trim(),
        'price_per_hour': parsedPrice ?? 0,
        'is_indoor': isIndoor,
      };

      if (widget.court == null) {
        await Supabase.instance.client.from('courts').insert(data);
      } else {
        await Supabase.instance.client
            .from('courts')
            .update(data)
            .eq('id', widget.court!['id']);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando cancha: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.court != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar cancha' : 'Nueva cancha'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre de la cancha',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedSportType,
            decoration: const InputDecoration(
              labelText: 'Tipo de deporte',
            ),
            items: sportTypes
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedSportType = value;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedSurfaceType,
            decoration: const InputDecoration(
              labelText: 'Superficie',
            ),
            items: surfaceTypes
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedSurfaceType = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio por hora',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: isIndoor,
            onChanged: (value) {
              setState(() {
                isIndoor = value;
              });
            },
            title: const Text('¿Es indoor?'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Descripción',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isSaving ? null : _save,
            child: Text(
              isSaving ? 'Guardando...' : 'Guardar',
            ),
          ),
        ],
      ),
    );
  }
}