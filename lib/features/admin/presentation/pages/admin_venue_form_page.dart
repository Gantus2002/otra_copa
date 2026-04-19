import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminVenueFormPage extends StatefulWidget {
  final Map<String, dynamic>? venue;
  final String? forcedOwnerUserId;
  final bool lockOwnerToCurrentUser;

  const AdminVenueFormPage({
    super.key,
    this.venue,
    this.forcedOwnerUserId,
    this.lockOwnerToCurrentUser = false,
  });

  @override
  State<AdminVenueFormPage> createState() => _AdminVenueFormPageState();
}

class _AdminVenueFormPageState extends State<AdminVenueFormPage> {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final descriptionController = TextEditingController();
  final whatsappController = TextEditingController();
  final phoneController = TextEditingController();
  final imageController = TextEditingController();

  final aliasController = TextEditingController();
  final cbuController = TextEditingController();
  final percentageController = TextEditingController(text: '20');
  final timeLimitController = TextEditingController(text: '10');

  bool isSaving = false;

  final List<String> cities = const [
    'Asunción',
    'Luque',
    'San Lorenzo',
    'Fernando de la Mora',
    'Lambaré',
    'Capiatá',
    'Ciudad del Este',
    'Encarnación',
    'Pedro Juan Caballero',
    'Caaguazú',
    'Coronel Oviedo',
    'Villarrica',
    'Itauguá',
    'Mariano Roque Alonso',
    'Ñemby',
    'Villa Elisa',
  ];

  String? selectedCity;

  @override
  void initState() {
    super.initState();

    if (widget.venue != null) {
      final v = widget.venue!;
      nameController.text = (v['name'] ?? '').toString();
      selectedCity = (v['city'] ?? '').toString().trim().isEmpty
          ? null
          : (v['city'] ?? '').toString();
      addressController.text = (v['address'] ?? '').toString();
      descriptionController.text = (v['description'] ?? '').toString();
      whatsappController.text = (v['whatsapp'] ?? '').toString();
      phoneController.text = (v['phone'] ?? '').toString();
      imageController.text = (v['cover_image_url'] ?? '').toString();

      aliasController.text = (v['transfer_alias'] ?? '').toString();
      cbuController.text = (v['transfer_cbu'] ?? '').toString();
      percentageController.text =
          (v['reservation_percentage'] ?? 20).toString();
      timeLimitController.text =
          (v['payment_time_limit_minutes'] ?? 10).toString();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    descriptionController.dispose();
    whatsappController.dispose();
    phoneController.dispose();
    imageController.dispose();
    aliasController.dispose();
    cbuController.dispose();
    percentageController.dispose();
    timeLimitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (nameController.text.trim().isEmpty || selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nombre y ciudad son obligatorios'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final data = {
        'name': nameController.text.trim(),
        'city': selectedCity,
        'address': addressController.text.trim(),
        'description': descriptionController.text.trim(),
        'whatsapp': whatsappController.text.trim(),
        'phone': phoneController.text.trim(),
        'cover_image_url': imageController.text.trim(),
        'transfer_alias': aliasController.text.trim(),
        'transfer_cbu': cbuController.text.trim(),
        'reservation_percentage':
            int.tryParse(percentageController.text.trim()) ?? 20,
        'payment_time_limit_minutes':
            int.tryParse(timeLimitController.text.trim()) ?? 10,
        if (widget.forcedOwnerUserId != null)
          'owner_user_id': widget.forcedOwnerUserId,
      };

      if (widget.venue == null) {
        await Supabase.instance.client.from('venues').insert(data);
      } else {
        await Supabase.instance.client
            .from('venues')
            .update(data)
            .eq('id', widget.venue!['id']);
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
    final editing = widget.venue != null;

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
              labelText: 'Nombre del complejo',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedCity,
            decoration: const InputDecoration(
              labelText: 'Ciudad',
            ),
            items: cities
                .map(
                  (city) => DropdownMenuItem<String>(
                    value: city,
                    child: Text(city),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedCity = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: 'Dirección',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Descripción',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: whatsappController,
            decoration: const InputDecoration(
              labelText: 'WhatsApp',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: imageController,
            decoration: const InputDecoration(
              labelText: 'URL imagen portada',
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Datos para transferencia',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: aliasController,
            decoration: const InputDecoration(
              labelText: 'Alias transferencia',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cbuController,
            decoration: const InputDecoration(
              labelText: 'CBU (opcional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: percentageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '% seña para reservar',
              helperText: 'Ejemplo: 20',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: timeLimitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Tiempo límite para pagar (minutos)',
              helperText: 'Ejemplo: 10',
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