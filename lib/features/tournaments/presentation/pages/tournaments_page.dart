import 'package:flutter/material.dart';
import '../../data/tournament_remote_service.dart';

class TournamentsPage extends StatefulWidget {
  final String selectedCity;

  const TournamentsPage({
    super.key,
    required this.selectedCity,
  });

  @override
  State<TournamentsPage> createState() => _TournamentsPageState();
}

class _TournamentsPageState extends State<TournamentsPage> {
  final TournamentRemoteService _service = TournamentRemoteService();
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;
  List<Map<String, dynamic>> tournaments = [];

  String selectedType = 'Todos';
  String selectedMode = 'Todos';
  String selectedCategory = 'Todos';

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    try {
      final data = await _service.getAllVisibleTournaments();

      setState(() {
        tournaments = data;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando torneos: $e'),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredTournaments {
    return tournaments.where((tournament) {
      final query = _searchController.text.toLowerCase();

      final name = (tournament['name'] ?? '').toString().toLowerCase();
      final location = (tournament['location'] ?? '').toString();
      final type = (tournament['tournament_type'] ?? '').toString();
      final mode = (tournament['game_mode'] ?? '').toString();
      final category = (tournament['category'] ?? '').toString();

      final matchesSearch = name.contains(query);

      final matchesLocation = widget.selectedCity.isEmpty ||
          location.toLowerCase().contains(widget.selectedCity.toLowerCase());

      final matchesType = selectedType == 'Todos' || type == selectedType;
      final matchesMode = selectedMode == 'Todos' || mode == selectedMode;
      final matchesCategory =
          selectedCategory == 'Todos' || category == selectedCategory;

      return matchesSearch &&
          matchesLocation &&
          matchesType &&
          matchesMode &&
          matchesCategory;
    }).toList();
  }

  String _officialLabel(Map<String, dynamic> tournament) {
    return tournament['is_official'] == true ? 'Oficial' : 'No oficial';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = filteredTournaments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar torneo'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadTournaments,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Ciudad actual: ${widget.selectedCity}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Buscar torneo',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de torneo',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                        DropdownMenuItem(value: 'Liga', child: Text('Liga')),
                        DropdownMenuItem(
                          value: 'Eliminatoria',
                          child: Text('Eliminatoria'),
                        ),
                        DropdownMenuItem(
                          value: 'Relámpago',
                          child: Text('Relámpago'),
                        ),
                        DropdownMenuItem(
                          value: 'Por invitación',
                          child: Text('Por invitación'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedMode,
                      decoration: const InputDecoration(
                        labelText: 'Modalidad',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                        DropdownMenuItem(value: '5 vs 5', child: Text('5 vs 5')),
                        DropdownMenuItem(value: '6 vs 6', child: Text('6 vs 6')),
                        DropdownMenuItem(value: '7 vs 7', child: Text('7 vs 7')),
                        DropdownMenuItem(value: '8 vs 8', child: Text('8 vs 8')),
                        DropdownMenuItem(
                          value: '11 vs 11',
                          child: Text('11 vs 11'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedMode = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'Masculino',
                          child: Text('Masculino'),
                        ),
                        DropdownMenuItem(
                          value: 'Femenino',
                          child: Text('Femenino'),
                        ),
                        DropdownMenuItem(value: 'Mixto', child: Text('Mixto')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Resultados',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (results.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No encontramos torneos con esos filtros.',
                          ),
                        ),
                      )
                    else
                      ...results.map(
                        (tournament) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Icon(
                              tournament['is_official'] == true
                                  ? Icons.verified
                                  : Icons.emoji_events_outlined,
                            ),
                            title: Text(
                              tournament['name']?.toString() ?? 'Torneo',
                            ),
                            subtitle: Text(
                              '${tournament['location'] ?? ''}\n'
                              '${tournament['tournament_type'] ?? ''} • '
                              '${tournament['game_mode'] ?? ''} • '
                              '${tournament['category'] ?? ''}\n'
                              '${_officialLabel(tournament)}',
                            ),
                            isThreeLine: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}