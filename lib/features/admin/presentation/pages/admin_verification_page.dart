import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';

class AdminVerificationPage extends StatefulWidget {
  const AdminVerificationPage({super.key});

  @override
  State<AdminVerificationPage> createState() =>
      _AdminVerificationPageState();
}

class _AdminVerificationPageState extends State<AdminVerificationPage> {
  List<Map<String, dynamic>> requests = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data = await SupabaseService.client
        .from('verification_requests')
        .select()
        .order('created_at', ascending: false);

    setState(() {
      requests = List<Map<String, dynamic>>.from(data);
      loading = false;
    });
  }

  Future<void> approve(Map<String, dynamic> req) async {
    await SupabaseService.client
        .from('profiles')
        .update({
          'role': req['requested_role'],
          'verified': true,
        })
        .eq('id', req['user_id']);

    await SupabaseService.client
        .from('verification_requests')
        .update({'status': 'approved'})
        .eq('id', req['id']);

    load();
  }

  Future<void> reject(Map<String, dynamic> req) async {
    await SupabaseService.client
        .from('verification_requests')
        .update({'status': 'rejected'})
        .eq('id', req['id']);

    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel Admin')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? const Center(child: Text('No hay solicitudes'))
              : ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (_, i) {
                    final r = requests[i];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(r['organization_name']?.toString() ?? ''),
                        subtitle: Text(
                          '${r['contact_name'] ?? ''} • ${r['requested_role'] ?? ''}\nEstado: ${r['status'] ?? ''}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => approve(r),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => reject(r),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}