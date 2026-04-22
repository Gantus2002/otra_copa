import 'package:flutter/material.dart';

import '../../data/tournament_remote_service.dart';
import '../../../invite/presentation/pages/join_by_code_page.dart';

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

      final matchesSearch =
          name.contains(query) || location.toLowerCase().contains(query);

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

  String _moneyText(dynamic value) {
    if (value == null) return 'A confirmar';
    if (value is num) return 'Gs. ${value.toStringAsFixed(0)}';
    final parsed = double.tryParse(value.toString());
    if (parsed == null) return 'A confirmar';
    return 'Gs. ${parsed.toStringAsFixed(0)}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = filteredTournaments;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar torneo'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const JoinByCodePage(),
            ),
          );
        },
        icon: const Icon(Icons.qr_code_2),
        label: const Text('Unirme por código'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadTournaments,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.14),
                            theme.colorScheme.primaryContainer.withOpacity(0.28),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.22),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explorá torneos',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ciudad actual: ${widget.selectedCity}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Buscar torneo o ubicación',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (_) {
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Filtros',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (results.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: theme.colorScheme.surface,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withOpacity(0.22),
                          ),
                        ),
                        child: const Text(
                          'No encontramos torneos con esos filtros.',
                        ),
                      )
                    else
                      ...results.map(
                        (tournament) => Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: theme.colorScheme.surface,
                            border: Border.all(
                              color:
                                  theme.colorScheme.outlineVariant.withOpacity(0.22),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: tournament['is_official'] == true
                                            ? Colors.green.withOpacity(0.14)
                                            : theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        tournament['is_official'] == true
                                            ? Icons.verified
                                            : Icons.emoji_events_outlined,
                                        color: tournament['is_official'] == true
                                            ? Colors.green
                                            : theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        tournament['name']?.toString() ?? 'Torneo',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _TournamentChip(
                                      label: (tournament['location'] ?? '')
                                          .toString(),
                                    ),
                                    _TournamentChip(
                                      label: (tournament['tournament_type'] ?? '')
                                          .toString(),
                                    ),
                                    _TournamentChip(
                                      label: (tournament['game_mode'] ?? '')
                                          .toString(),
                                    ),
                                    _TournamentChip(
                                      label: (tournament['category'] ?? '')
                                          .toString(),
                                    ),
                                    _TournamentChip(
                                      label: _officialLabel(tournament),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _PriceMiniCard(
                                        title: 'Individual',
                                        value: _moneyText(
                                          tournament['entry_fee'] ??
                                              tournament['entry_fee_individual'],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _PriceMiniCard(
                                        title: 'Equipo',
                                        value: _moneyText(
                                          tournament['team_entry_fee'] ??
                                              tournament['entry_fee_team'],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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

class _TournamentChip extends StatelessWidget {
  final String label;

  const _TournamentChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PriceMiniCard extends StatelessWidget {
  final String title;
  final String value;

  const _PriceMiniCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}