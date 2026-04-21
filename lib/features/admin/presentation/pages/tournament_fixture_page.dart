import 'package:flutter/material.dart';

import '../../../../core/widgets/app_bar_with_notifications.dart';
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

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _loadMatches() async {
    try {
      final data = await _fixtureService.getMatchesWithTeams(widget.tournamentId);

      _safeSetState(() {
        matches = data;
      });
    } catch (e) {
      _showSnackBar('Error cargando fixture: $e');
    } finally {
      _safeSetState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _generateFixture() async {
    _safeSetState(() {
      isGenerating = true;
    });

    try {
      await _fixtureService.generateFixture(widget.tournamentId);
      await _loadMatches();

      _showSnackBar('Fixture generado correctamente');
    } catch (e) {
      _showSnackBar('Error generando fixture: $e');
    } finally {
      _safeSetState(() {
        isGenerating = false;
      });
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'finished':
        return 'Finalizado';
      case 'in_progress':
        return 'En juego';
      case 'scheduled':
        return 'Programado';
      case 'pending':
      default:
        return 'Pendiente';
    }
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'finished':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'scheduled':
        return Colors.blue;
      case 'pending':
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBarWithNotifications(
        title: 'Fixture - ${widget.tournamentName}',
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
                    (match) {
                      final homeTeam =
                          (match['home_team_name'] ?? 'Equipo local').toString();
                      final awayTeam =
                          (match['away_team_name'] ?? 'Equipo visitante')
                              .toString();
                      final roundNumber =
                          (match['round_number'] ?? '-').toString();
                      final status = (match['status'] ?? 'pending').toString();
                      final homeScore = (match['home_score'] ?? 0).toString();
                      final awayScore = (match['away_score'] ?? 0).toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text('$homeTeam vs $awayTeam'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ronda $roundNumber'),
                              const SizedBox(height: 4),
                              Text(
                                _statusText(status),
                                style: TextStyle(
                                  color: _statusColor(context, status),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$homeScore - $awayScore',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
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
                      );
                    },
                  ),
              ],
            ),
    );
  }
}