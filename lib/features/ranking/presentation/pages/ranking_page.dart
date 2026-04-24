import 'package:flutter/material.dart';

import '../../../player/presentation/pages/player_public_profile_page.dart';
import '../../data/ranking_service.dart';

class RankingPage extends StatefulWidget {
  final int? tournamentId;
  final String? tournamentName;
  final String city;

  const RankingPage({
    super.key,
    this.tournamentId,
    this.tournamentName,
    required this.city,
  });

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  final RankingService _service = RankingService();

  bool isLoading = true;
  bool showTournamentRanking = true;

  List<Map<String, dynamic>> ranking = [];

  @override
  void initState() {
    super.initState();
    showTournamentRanking = widget.tournamentId != null;
    _loadRanking();
  }

  Future<void> _loadRanking() async {
    setState(() => isLoading = true);

    try {
      final data = showTournamentRanking && widget.tournamentId != null
          ? await _service.getTournamentPlayerRanking(widget.tournamentId!)
          : await _service.getLocalPlayerRanking(widget.city);

      if (!mounted) return;

      setState(() {
        ranking = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando ranking: $e')),
      );
    }
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPublicProfilePage(userId: userId),
      ),
    );
  }

  Widget _avatar(String? url, String name) {
    if (url != null && url.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(url),
      );
    }

    return CircleAvatar(
      radius: 24,
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'J'),
    );
  }

  Color _podiumColor(int index) {
    if (index == 0) return Colors.amber.shade700;
    if (index == 1) return Colors.blueGrey.shade300;
    if (index == 2) return Colors.brown.shade300;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = showTournamentRanking && widget.tournamentName != null
        ? 'Ranking - ${widget.tournamentName}'
        : 'Ranking local - ${widget.city}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRanking,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.leaderboard,
                    color: Colors.white,
                    size: 34,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Se calcula por goles, MVP y partidos jugados. No es global: se filtra por torneo o ciudad.',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (widget.tournamentId != null)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Torneo'),
                    icon: Icon(Icons.emoji_events_outlined),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Local'),
                    icon: Icon(Icons.location_city),
                  ),
                ],
                selected: {showTournamentRanking},
                onSelectionChanged: (value) {
                  setState(() {
                    showTournamentRanking = value.first;
                  });
                  _loadRanking();
                },
              ),
            const SizedBox(height: 18),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 70),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (ranking.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    showTournamentRanking
                        ? 'Todavía no hay estadísticas en este torneo.'
                        : 'Todavía no hay jugadores con estadísticas en ${widget.city}.',
                  ),
                ),
              )
            else
              ...List.generate(ranking.length, (index) {
                final player = ranking[index];

                final name = (player['full_name'] ?? 'Jugador').toString();
                final avatar = player['avatar_url']?.toString();
                final userId = (player['user_id'] ?? '').toString();

                final goals = player['goals'] ?? 0;
                final mvp = player['mvp'] ?? 0;
                final matches = player['matches_played'] ?? 0;
                final score = player['score'] ?? 0;

                final podium = index < 3;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: podium
                          ? _podiumColor(index).withOpacity(0.65)
                          : theme.colorScheme.outlineVariant.withOpacity(0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _avatar(avatar, name),
                        Positioned(
                          left: -6,
                          top: -6,
                          child: Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: podium
                                  ? _podiumColor(index)
                                  : theme.colorScheme.surfaceContainerHighest,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: podium ? Colors.white : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MiniStat(label: 'PJ', value: '$matches'),
                          _MiniStat(label: 'G', value: '$goals'),
                          _MiniStat(label: 'MVP', value: '$mvp'),
                        ],
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$score',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const Text(
                          'PTS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    onTap: userId.isEmpty ? null : () => _openProfile(userId),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}