import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class RequestVerificationPage extends StatefulWidget {
  const RequestVerificationPage({super.key});

  @override
  State<RequestVerificationPage> createState() =>
      _RequestVerificationPageState();
}

class _RequestVerificationPageState extends State<RequestVerificationPage> {
  final TextEditingController orgController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  String selectedRole = 'organizer';
  bool loading = false;

  Future<void> submit() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    setState(() => loading = true);

    try {
      await SupabaseService.client.from('verification_requests').insert({
        'user_id': user.id,
        'requested_role': selectedRole,
        'organization_name': orgController.text.trim(),
        'contact_name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'notes': notesController.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar verificación')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField(
            value: selectedRole,
            items: const [
              DropdownMenuItem(value: 'organizer', child: Text('Organización')),
              DropdownMenuItem(value: 'venue', child: Text('Cancha')),
            ],
            onChanged: (v) => setState(() => selectedRole = v!),
          ),
          TextField(controller: orgController, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Responsable')),
          TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Teléfono')),
          TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Notas')),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: loading ? null : submit,
            child: const Text('Enviar solicitud'),
          )
        ],
      ),
    );
  }
}