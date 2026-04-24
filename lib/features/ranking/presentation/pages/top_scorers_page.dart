import 'package:flutter/material.dart';

import '../../data/top_scorers_service.dart';

class TopScorersPage extends StatefulWidget {
  final int tournamentId;

  const TopScorersPage({super.key, required this.tournamentId});

  @override
  State<TopScorersPage> createState() => _TopScorersPageState();
}

class _TopScorersPageState extends State<TopScorersPage> {
  final TopScorersService _service = TopScorersService();

  bool isLoading = true;
  List<Map<String, dynamic>> players = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _service.getTopScorers(widget.tournamentId);

    if (!mounted) return;

    setState(() {
      players = data;
      isLoading = false;
    });
  }

  Widget _avatar(String? url, String name) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(child: Text(name[0]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Top goleadores')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: players.length,
              itemBuilder: (_, i) {
                final p = players[i];

                return ListTile(
                  leading: _avatar(p['avatar'], p['name']),
                  title: Text(p['name']),
                  trailing: Text(
                    '${p['goals']} ⚽',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
    );
  }
}