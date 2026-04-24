import 'package:flutter/material.dart';

import '../../data/mvp_leaderboard_service.dart';

class MvpLeaderboardPage extends StatefulWidget {
  final int tournamentId;

  const MvpLeaderboardPage({
    super.key,
    required this.tournamentId,
  });

  @override
  State<MvpLeaderboardPage> createState() => _MvpLeaderboardPageState();
}

class _MvpLeaderboardPageState extends State<MvpLeaderboardPage> {
  final MvpLeaderboardService _service = MvpLeaderboardService();

  bool isLoading = true;
  List<Map<String, dynamic>> players = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _service.getMvpLeaderboard(widget.tournamentId);

    if (!mounted) return;

    setState(() {
      players = data;
      isLoading = false;
    });
  }

  Widget _avatar(String? url, String name) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(url),
      );
    }

    return CircleAvatar(
      radius: 26,
      child: Text(name.isNotEmpty ? name[0] : 'J'),
    );
  }

  Color _podiumColor(int index) {
    if (index == 0) return Colors.amber;
    if (index == 1) return Colors.grey;
    if (index == 2) return Colors.brown;
    return Colors.transparent;
  }

  Widget _topPlayerCard(Map<String, dynamic> p, int index) {
    final name = p['name'];
    final avatar = p['avatar_url'];
    final mvp = p['mvp'];

    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: index == 0 ? 36 : 30,
            backgroundColor: _podiumColor(index).withOpacity(0.3),
            child: _avatar(avatar, name),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('$mvp MVP ⭐'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MVP Leaderboard'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 🔥 HEADER PRO
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1E1E2F),
                        Color(0xFF2A2A40),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.star, color: Colors.amber, size: 34),
                      SizedBox(height: 12),
                      Text(
                        'Jugadores más valiosos',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Ranking basado en MVPs del torneo',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 🏆 PODIO
                if (players.length >= 3)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _topPlayerCard(players[1], 1),
                      _topPlayerCard(players[0], 0),
                      _topPlayerCard(players[2], 2),
                    ],
                  ),

                const SizedBox(height: 24),

                // 📋 LISTA
                ...List.generate(players.length, (i) {
                  final p = players[i];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Stack(
                        children: [
                          _avatar(p['avatar_url'], p['name']),
                          Positioned(
                            left: -2,
                            top: -2,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        p['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'PJ ${p['matches_played']} • G ${p['goals']}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${p['mvp']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const Text('MVP'),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}