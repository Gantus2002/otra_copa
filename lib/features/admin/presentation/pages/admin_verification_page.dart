import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';
import 'admin_home_content_page.dart';

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
      appBar: AppBar(
        title: const Text('Panel Admin'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.view_carousel_outlined),
                    title: const Text('Contenido Home'),
                    subtitle: const Text('Gestionar banners y anuncios'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminHomeContentPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Solicitudes de verificación',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (requests.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay solicitudes'),
                    ),
                  )
                else
                  ...requests.map(
                    (r) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
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
                    ),
                  ),
              ],
            ),
    );
  }
}