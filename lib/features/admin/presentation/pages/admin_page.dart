import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../invite/data/join_request_service.dart';
import 'tournament_players_page.dart';

class AdminPage extends StatefulWidget {
  final int tournamentId;
  final String tournamentName;

  const AdminPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final JoinRequestService _service = JoinRequestService();

  List<Map<String, dynamic>> requests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenRequests();
  }

  void _listenRequests() {
    final client = Supabase.instance.client;

    client
        .from('join_requests')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', widget.tournamentId)
        .listen((data) {
      setState(() {
        requests = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    });
  }

  Future<void> _approve(Map<String, dynamic> request) async {
    final client = Supabase.instance.client;

    try {
      await client.from('tournament_players').insert({
        'tournament_id': request['tournament_id'],
        'player_name': request['player_name'],
        'user_id': request['user_id'],
      });

      await _service.updateStatus(request['id'], 'approved');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jugador aprobado correctamente'),
        ),
      );
    } catch (e) {
      final message = e.toString();

      if (message.contains('duplicate key') ||
          message.contains('tournament_players_unique_user_tournament')) {
        await _service.updateStatus(request['id'], 'approved');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ese jugador ya estaba confirmado en el torneo'),
          ),
        );
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error aprobando jugador: $e'),
        ),
      );
    }
  }

  Future<void> _reject(int id) async {
    await _service.updateStatus(id, 'rejected');
  }

  @override
  Widget build(BuildContext context) {
    final pending = requests.where((r) => r['status'] == 'pending').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tournamentName),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TournamentPlayersPage(
                    tournamentId: widget.tournamentId,
                    tournamentName: widget.tournamentName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pending.isEmpty
              ? const Center(child: Text('No hay solicitudes pendientes'))
              : ListView.builder(
                  itemCount: pending.length,
                  itemBuilder: (context, index) {
                    final request = pending[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(request['player_name'] ?? ''),
                        subtitle: const Text('Solicitud pendiente'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _approve(request),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _reject(request['id']),
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