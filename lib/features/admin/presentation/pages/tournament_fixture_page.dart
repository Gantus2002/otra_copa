import 'package:flutter/material.dart';
import '../../data/fixture_service.dart';
import 'match_detail_page.dart';

class TournamentFixturePage extends StatefulWidget {
  final int tournamentId;
  final String tournamentName;

  const TournamentFixturePage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<TournamentFixturePage> createState() => _TournamentFixturePageState();
}

class _TournamentFixturePageState extends State<TournamentFixturePage> {
  final FixtureService _fixtureService = FixtureService();

  List<Map<String, dynamic>> matches = [];
  bool isLoading = true;
  bool isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    try {
      final data = await _fixtureService.getMatchesWithTeams(widget.tournamentId);

      setState(() {
        matches = data;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando fixture: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _generateFixture() async {
    setState(() {
      isGenerating = true;
    });

    try {
      await _fixtureService.generateFixture(widget.tournamentId);
      await _loadMatches();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fixture generado correctamente'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generando fixture: $e')),
      );
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fixture - ${widget.tournamentName}'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ElevatedButton.icon(
                  onPressed: isGenerating ? null : _generateFixture,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    isGenerating ? 'Generando...' : 'Generar fixture',
                  ),
                ),
                const SizedBox(height: 20),
                if (matches.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text('Todavía no hay partidos generados'),
                    ),
                  )
                else
                  ...matches.map(
                    (match) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          '${match['home_team_name']} vs ${match['away_team_name']}',
                        ),
                        subtitle: Text(
                          'Ronda ${match['round_number']} • ${match['status']}',
                        ),
                        trailing: Text(
                          '${match['home_score']} - ${match['away_score']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MatchDetailPage(match: match),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}