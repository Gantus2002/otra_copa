import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';

class SupabaseTestPage extends StatefulWidget {
  const SupabaseTestPage({super.key});

  @override
  State<SupabaseTestPage> createState() => _SupabaseTestPageState();
}

class _SupabaseTestPageState extends State<SupabaseTestPage> {
  String status = 'Probando conexión...';

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    try {
      final result = await SupabaseService.client
          .from('app_ping')
          .select()
          .limit(1);

      setState(() {
        status = 'Conexión OK: ${result.length} fila(s) leída(s)';
      });
    } catch (e) {
      setState(() {
        status = 'Error de conexión: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba Supabase'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            status,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}