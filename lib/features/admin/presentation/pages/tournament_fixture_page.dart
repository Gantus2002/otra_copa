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
      final data = await _fixtureService.getMatchesWithTeams(
        widget.tournamentId,
      );

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
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
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
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Widget _teamLogo(String? logoUrl) {
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          logoUrl,
          width: 34,
          height: 34,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const CircleAvatar(
            radius: 17,
            child: Icon(Icons.shield_outlined, size: 17),
          ),
        ),
      );
    }

    return const CircleAvatar(
      radius: 17,
      child: Icon(Icons.shield_outlined, size: 17),
    );
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
          : RefreshIndicator(
              onRefresh: _loadMatches,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: theme.colorScheme.surface,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fixture del torneo',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Generá todos los cruces automáticamente con los equipos aprobados.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isGenerating ? null : _generateFixture,
                            icon: isGenerating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.calendar_month),
                            label: Text(
                              isGenerating ? 'Generando...' : 'Generar fixture',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (matches.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
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

                        final homeLogo = match['home_team_logo_url']?.toString();
                        final awayLogo = match['away_team_logo_url']?.toString();

                        final roundNumber =
                            (match['round_number'] ?? '-').toString();
                        final status = (match['status'] ?? 'pending').toString();
                        final homeScore = (match['home_score'] ?? 0).toString();
                        final awayScore = (match['away_score'] ?? 0).toString();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MatchDetailPage(match: match),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Ronda $roundNumber',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _statusText(status),
                                        style: TextStyle(
                                          color: _statusColor(context, status),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            _teamLogo(homeLogo),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                homeTeam,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          '$homeScore - $awayScore',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                awayTeam,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.end,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _teamLogo(awayLogo),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}