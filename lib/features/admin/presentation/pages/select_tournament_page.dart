import 'package:flutter/material.dart';
import '../../../tournaments/data/tournament_remote_service.dart';
import 'admin_page.dart';

class SelectTournamentPage extends StatefulWidget {
  const SelectTournamentPage({super.key});

  @override
  State<SelectTournamentPage> createState() => _SelectTournamentPageState();
}

class _SelectTournamentPageState extends State<SelectTournamentPage> {
  final TournamentRemoteService _service = TournamentRemoteService();

  List<Map<String, dynamic>> tournaments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    try {
      final data = await _service.getMyTournaments();

      setState(() {
        tournaments = data;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando torneos: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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
              ? const Center(child: Text('No tenés torneos creados'))
              : ListView.builder(
                  itemCount: tournaments.length,
                  itemBuilder: (context, index) {
                    final tournament = tournaments[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(tournament['name'] ?? ''),
                        subtitle: Text(
                          '${tournament['location']} • ${tournament['tournament_type']}',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminPage(
                                tournamentId: tournament['id'],
                                tournamentName: tournament['name'] ?? '',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}