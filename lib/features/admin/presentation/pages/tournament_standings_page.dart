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
  State<TournamentStandingsPage> createState() =>
      _TournamentStandingsPageState();
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

  Widget _teamLogo(String? logoUrl, {double size = 34}) {
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CircleAvatar(
            radius: size / 2,
            child: Icon(Icons.shield_outlined, size: size * 0.48),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      child: Icon(Icons.shield_outlined, size: size * 0.48),
    );
  }

  Widget _podiumCard(
    BuildContext context,
    Map<String, dynamic> team,
    int position,
  ) {
    final theme = Theme.of(context);
    final name = (team['name'] ?? 'Equipo').toString();
    final pts = team['pts'] ?? 0;
    final dg = team['dg'] ?? 0;
    final logoUrl = team['logo_url']?.toString();

    final Color badgeColor;
    if (position == 1) {
      badgeColor = Colors.amber.shade700;
    } else if (position == 2) {
      badgeColor = Colors.blueGrey.shade300;
    } else {
      badgeColor = Colors.brown.shade300;
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: badgeColor.withOpacity(0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeColor,
              ),
              child: Text(
                '$position',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _teamLogo(logoUrl, size: position == 1 ? 58 : 48),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '$pts pts',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'DG $dg',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCell(String value, {bool bold = false}) {
    return SizedBox(
      width: 34,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _teamRow(
    BuildContext context,
    Map<String, dynamic> team,
    int index,
  ) {
    final theme = Theme.of(context);

    final name = (team['name'] ?? 'Equipo').toString();
    final logoUrl = team['logo_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: index < 3
              ? theme.colorScheme.primary.withOpacity(0.28)
              : theme.colorScheme.outlineVariant.withOpacity(0.22),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          _teamLogo(logoUrl, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          _statCell('${team['pj']}'),
          _statCell('${team['pg']}'),
          _statCell('${team['pe']}'),
          _statCell('${team['pp']}'),
          _statCell('${team['gf']}'),
          _statCell('${team['gc']}'),
          _statCell('${team['dg']}'),
          _statCell('${team['pts']}', bold: true),
        ],
      ),
    );
  }

  Widget _tableHeader(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    TextStyle style = TextStyle(
      color: color,
      fontWeight: FontWeight.w900,
      fontSize: 11,
    );

    Widget cell(String text) {
      return SizedBox(
        width: 34,
        child: Text(text, textAlign: TextAlign.center, style: style),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          const SizedBox(width: 26),
          const SizedBox(width: 36),
          const SizedBox(width: 10),
          Expanded(child: Text('Equipo', style: style)),
          cell('PJ'),
          cell('PG'),
          cell('PE'),
          cell('PP'),
          cell('GF'),
          cell('GC'),
          cell('DG'),
          cell('PTS'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topThree = standings.take(3).toList();

    return Scaffold(
      appBar: AppBarWithNotifications(
        title: 'Tabla - ${widget.tournamentName}',
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStandings,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0F3144),
                          Color(0xFF174B61),
                          Color(0xFF1D6A77),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          color: Colors.white,
                          size: 36,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Tabla de posiciones',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Se calcula automáticamente con partidos finalizados.',
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (standings.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Todavía no hay equipos en la tabla. Aprobá equipos y finalizá partidos para ver posiciones.',
                        ),
                      ),
                    )
                  else ...[
                    if (topThree.isNotEmpty) ...[
                      Text(
                        'Podio',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (topThree.length >= 2)
                            _podiumCard(context, topThree[1], 2)
                          else
                            const Spacer(),
                          const SizedBox(width: 10),
                          _podiumCard(context, topThree[0], 1),
                          const SizedBox(width: 10),
                          if (topThree.length >= 3)
                            _podiumCard(context, topThree[2], 3)
                          else
                            const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      'Clasificación completa',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 720,
                        child: Column(
                          children: [
                            _tableHeader(context),
                            ...List.generate(
                              standings.length,
                              (index) =>
                                  _teamRow(context, standings[index], index),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}