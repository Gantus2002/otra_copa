import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StandingsPage extends StatefulWidget {
  final int tournamentId;
  final String tournamentName;

  const StandingsPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<StandingsPage> createState() => _StandingsPageState();
}

class _StandingsPageState extends State<StandingsPage> {
  List<Map<String, dynamic>> table = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStandings();
  }

  Future<void> _loadStandings() async {
    final client = Supabase.instance.client;

    final teamsResponse = await client
        .from('tournament_teams')
        .select()
        .eq('tournament_id', widget.tournamentId);

    final matchesResponse = await client
        .from('matches')
        .select()
        .eq('tournament_id', widget.tournamentId);

    final teams = List<Map<String, dynamic>>.from(teamsResponse);
    final matches = List<Map<String, dynamic>>.from(matchesResponse);

    final Map<int, Map<String, dynamic>> standings = {};

    for (var team in teams) {
      standings[team['id']] = {
        'name': team['name'],
        'points': 0,
        'played': 0,
      };
    }

    for (var match in matches) {
      if (match['status'] != 'finished') continue;

      final homeId = match['home_team_id'];
      final awayId = match['away_team_id'];
      final homeScore = match['home_score'] ?? 0;
      final awayScore = match['away_score'] ?? 0;

      standings[homeId]!['played']++;
      standings[awayId]!['played']++;

      if (homeScore > awayScore) {
        standings[homeId]!['points'] += 3;
      } else if (awayScore > homeScore) {
        standings[awayId]!['points'] += 3;
      } else {
        standings[homeId]!['points'] += 1;
        standings[awayId]!['points'] += 1;
      }
    }

    final sorted = standings.values.toList()
      ..sort((a, b) => b['points'].compareTo(a['points']));

    setState(() {
      table = sorted;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tabla - ${widget.tournamentName}'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: table.length,
              itemBuilder: (context, index) {
                final team = table[index];

                return ListTile(
                  leading: Text('#${index + 1}'),
                  title: Text(team['name']),
                  subtitle: Text('PJ: ${team['played']}'),
                  trailing: Text(
                    '${team['points']} pts',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
    );
  }
}