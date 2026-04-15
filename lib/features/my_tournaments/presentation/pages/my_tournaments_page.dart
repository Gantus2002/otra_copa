import 'package:flutter/material.dart';
import '../../../tournaments/data/tournament_remote_service.dart';
import '../../../admin/presentation/pages/admin_page.dart';

class MyTournamentsPage extends StatefulWidget {
  const MyTournamentsPage({super.key});

  @override
  State<MyTournamentsPage> createState() => _MyTournamentsPageState();
}

class _MyTournamentsPageState extends State<MyTournamentsPage> {
  final TournamentRemoteService _service = TournamentRemoteService();

  bool isLoading = true;
  List<Map<String, dynamic>> tournaments = [];

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    try {
      final data = await _service.getMyCreatedTournaments();

      setState(() {
        tournaments = data;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando torneos: $e'),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _typeLabel(Map<String, dynamic> tournament) {
    final type = tournament['tournament_type']?.toString() ?? 'Torneo';
    final official = tournament['is_official'] == true;

    return official ? '$type • Oficial' : '$type • No oficial';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis torneos'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tournaments.isEmpty
              ? const Center(
                  child: Text('Todavía no creaste torneos'),
                )
              : RefreshIndicator(
                  onRefresh: _loadTournaments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tournaments.length,
                    itemBuilder: (context, index) {
                      final tournament = tournaments[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.emoji_events_outlined),
                          title: Text(tournament['name']?.toString() ?? 'Torneo'),
                          subtitle: Text(
                            '${tournament['location'] ?? ''}\n${_typeLabel(tournament)}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminPage(
                                  tournamentId: tournament['id'] as int,
                                  tournamentName:
                                      tournament['name']?.toString() ?? 'Torneo',
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}