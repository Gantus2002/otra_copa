import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../player/data/player_stats_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final PlayerStatsService _statsService = PlayerStatsService();

  List<Map<String, dynamic>> stats = [];
  bool isLoading = true;

  int totalGoals = 0;
  int totalMatches = 0;
  int totalMvp = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    final data = await _statsService.getPlayerStats(user.id);

    int goals = 0;
    int matches = 0;
    int mvp = 0;

    for (var stat in data) {
      goals += (stat['goals'] ?? 0) as int;
      matches += (stat['matches_played'] ?? 0) as int;
      mvp += (stat['mvp'] ?? 0) as int;
    }

    setState(() {
      stats = data;
      totalGoals = goals;
      totalMatches = matches;
      totalMvp = mvp;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  user?.email ?? '',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Estadísticas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                _statCard('Partidos jugados', totalMatches),
                _statCard('Goles', totalGoals),
                _statCard('MVP', totalMvp),
              ],
            ),
    );
  }

  Widget _statCard(String title, int value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}