import 'package:flutter/material.dart';

import '../../../../core/widgets/app_bar_with_notifications.dart';
import '../../data/standings_service.dart';

class TournamentStandingsPage extends StatefulWidget {
  final int tournamentId;
  final String tournamentName;

  const TournamentStandingsPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<TournamentStandingsPage> createState() => _TournamentStandingsPageState();
}

class _TournamentStandingsPageState extends State<TournamentStandingsPage> {
  final StandingsService _service = StandingsService();

  bool isLoading = true;
  List<Map<String, dynamic>> standings = [];

  @override
  void initState() {
    super.initState();
    _loadStandings();
  }

  Future<void> _loadStandings() async {
    try {
      final data = await _service.getStandings(widget.tournamentId);

      if (!mounted) return;
      setState(() {
        standings = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando tabla: $e')),
      );
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
            child: Icon(Icons.shield_outlined, size: 16),
          ),
        ),
      );
    }

    return const CircleAvatar(
      radius: 17,
      child: Icon(Icons.shield_outlined, size: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBarWithNotifications(
        title: 'Tabla - ${widget.tournamentName}',
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStandings,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Tabla de posiciones',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Se calcula automáticamente con partidos finalizados.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (standings.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Todavía no hay equipos en la tabla.'),
                      ),
                    )
                  else
                    Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('#')),
                            DataColumn(label: Text('Equipo')),
                            DataColumn(label: Text('PJ')),
                            DataColumn(label: Text('PG')),
                            DataColumn(label: Text('PE')),
                            DataColumn(label: Text('PP')),
                            DataColumn(label: Text('GF')),
                            DataColumn(label: Text('GC')),
                            DataColumn(label: Text('DG')),
                            DataColumn(label: Text('PTS')),
                          ],
                          rows: List.generate(standings.length, (index) {
                            final team = standings[index];

                            return DataRow(
                              cells: [
                                DataCell(Text('${index + 1}')),
                                DataCell(
                                  Row(
                                    children: [
                                      _teamLogo(team['logo_url']?.toString()),
                                      const SizedBox(width: 8),
                                      Text(
                                        (team['name'] ?? 'Equipo').toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text('${team['pj']}')),
                                DataCell(Text('${team['pg']}')),
                                DataCell(Text('${team['pe']}')),
                                DataCell(Text('${team['pp']}')),
                                DataCell(Text('${team['gf']}')),
                                DataCell(Text('${team['gc']}')),
                                DataCell(Text('${team['dg']}')),
                                DataCell(
                                  Text(
                                    '${team['pts']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}