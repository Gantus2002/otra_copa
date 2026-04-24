import 'package:flutter/material.dart';

import '../../data/tournament_remote_service.dart';
import '../../../invite/presentation/pages/join_by_code_page.dart';
import '../../../tournament_detail/presentation/pages/tournament_detail_page.dart';

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
  bool onlyMyCity = true;

  List<Map<String, dynamic>> tournaments = [];

  String selectedType = 'Todos';
  String selectedMode = 'Todos';
  String selectedCategory = 'Todos';

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  Future<void> _loadTournaments() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = onlyMyCity
          ? await _service.getTournamentsByCity(widget.selectedCity)
          : await _service.getAllVisibleTournaments();

      if (!mounted) return;

      setState(() {
        tournaments = data;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando torneos: $e'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredTournaments {
    final query = _normalize(_searchController.text);

    return tournaments.where((tournament) {
      final name = _normalize((tournament['name'] ?? '').toString());
      final location = _normalize((tournament['location'] ?? '').toString());
      final type = _normalize((tournament['tournament_type'] ?? '').toString());
      final mode = _normalize((tournament['game_mode'] ?? '').toString());
      final category = _normalize((tournament['category'] ?? '').toString());

      final matchesSearch =
          query.isEmpty || name.contains(query) || location.contains(query);

      final matchesType =
          selectedType == 'Todos' || type == _normalize(selectedType);

      final matchesMode =
          selectedMode == 'Todos' || mode == _normalize(selectedMode);

      final matchesCategory =
          selectedCategory == 'Todos' || category == _normalize(selectedCategory);

      return matchesSearch && matchesType && matchesMode && matchesCategory;
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

  String _joinModeText(Map<String, dynamic> tournament) {
    final joinMode = (tournament['join_mode'] ?? '').toString();

    switch (joinMode) {
      case 'player':
      case 'players':
        return 'Se une jugador';
      case 'team':
      case 'teams':
        return 'Se une equipo';
      case 'both':
        return 'Jugador o equipo';
      default:
        return 'Modo libre';
    }
  }

  void _openTournament(Map<String, dynamic> tournament) {
    final tournamentId = tournament['id'];

    if (tournamentId is! int) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el torneo'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentDetailPage(
          tournamentId: tournamentId,
        ),
      ),
    );
  }

  Future<void> _toggleCityFilter(bool value) async {
    setState(() {
      onlyMyCity = value;
      isLoading = true;
    });

    await _loadTournaments();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      selectedType = 'Todos';
      selectedMode = 'Todos';
      selectedCategory = 'Todos';
    });
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
                    _HeaderSearchCard(
                      selectedCity: widget.selectedCity,
                      onlyMyCity: onlyMyCity,
                      searchController: _searchController,
                      onSearchChanged: (_) => setState(() {}),
                      onOnlyMyCityChanged: _toggleCityFilter,
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
                          selectedType = value ?? 'Todos';
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
                        DropdownMenuItem(value: '11 vs 11', child: Text('11 vs 11')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedMode = value ?? 'Todos';
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
                          selectedCategory = value ?? 'Todos';
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Resultados (${results.length})',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Limpiar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (results.isEmpty)
                      _EmptyTournamentState(
                        onlyMyCity: onlyMyCity,
                        selectedCity: widget.selectedCity,
                        onShowAll: () => _toggleCityFilter(false),
                      )
                    else
                      ...results.map(
                        (tournament) => _TournamentCard(
                          tournament: tournament,
                          officialLabel: _officialLabel(tournament),
                          joinModeText: _joinModeText(tournament),
                          individualPrice:
                              _moneyText(tournament['entry_fee_individual']),
                          teamPrice: _moneyText(tournament['entry_fee_team']),
                          onTap: () => _openTournament(tournament),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _HeaderSearchCard extends StatelessWidget {
  final String selectedCity;
  final bool onlyMyCity;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onOnlyMyCityChanged;

  const _HeaderSearchCard({
    required this.selectedCity,
    required this.onlyMyCity,
    required this.searchController,
    required this.onSearchChanged,
    required this.onOnlyMyCityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
            selectedCity.trim().isEmpty
                ? 'Ciudad actual: Sin definir'
                : 'Ciudad actual: $selectedCity',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
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
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            value: onlyMyCity,
            onChanged: onOnlyMyCityChanged,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Mostrar solo mi ciudad',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              onlyMyCity
                  ? 'Filtrando por $selectedCity'
                  : 'Mostrando torneos de todas las ciudades',
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final Map<String, dynamic> tournament;
  final String officialLabel;
  final String joinModeText;
  final String individualPrice;
  final String teamPrice;
  final VoidCallback onTap;

  const _TournamentCard({
    required this.tournament,
    required this.officialLabel,
    required this.joinModeText,
    required this.individualPrice,
    required this.teamPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      tournament['is_official'] == true
                          ? Icons.verified
                          : Icons.emoji_events_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament['name']?.toString() ?? 'Torneo',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (tournament['location'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TournamentChip(
                        label: (tournament['tournament_type'] ?? '').toString(),
                      ),
                      _TournamentChip(
                        label: (tournament['game_mode'] ?? '').toString(),
                      ),
                      _TournamentChip(
                        label: (tournament['category'] ?? '').toString(),
                      ),
                      _TournamentChip(label: officialLabel),
                      _TournamentChip(label: joinModeText),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceMiniCard(
                          title: 'Individual',
                          value: individualPrice,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PriceMiniCard(
                          title: 'Equipo',
                          value: teamPrice,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Ver torneo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTournamentState extends StatelessWidget {
  final bool onlyMyCity;
  final String selectedCity;
  final VoidCallback onShowAll;

  const _EmptyTournamentState({
    required this.onlyMyCity,
    required this.selectedCity,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.22),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 42,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No encontramos torneos',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            onlyMyCity
                ? 'No hay torneos para $selectedCity con esos filtros.'
                : 'No hay torneos con esos filtros.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onlyMyCity) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onShowAll,
              icon: const Icon(Icons.public),
              label: const Text('Ver todas las ciudades'),
            ),
          ],
        ],
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