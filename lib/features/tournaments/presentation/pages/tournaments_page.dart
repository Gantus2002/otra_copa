import 'package:flutter/material.dart';
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
  final TextEditingController _searchController = TextEditingController();

  late String selectedLocation;
  String selectedType = 'Liga';
  String selectedMode = '5 vs 5';
  String selectedCategory = 'Masculino';

  final List<Map<String, String>> tournaments = [
    {
      'name': 'Torneo Apertura 2026',
      'date': '20/04/2026',
      'location': 'Asunción',
      'type': 'Liga',
      'mode': '5 vs 5',
      'category': 'Masculino',
    },
    {
      'name': 'Copa Facultades',
      'date': '25/04/2026',
      'location': 'San Lorenzo',
      'type': 'Eliminatoria',
      'mode': '7 vs 7',
      'category': 'Mixto',
    },
    {
      'name': 'Relámpago F5',
      'date': '27/04/2026',
      'location': 'Luque',
      'type': 'Relámpago',
      'mode': '5 vs 5',
      'category': 'Femenino',
    },
  ];

  @override
  void initState() {
    super.initState();
    selectedLocation = widget.selectedCity;
  }

  List<Map<String, String>> get filteredTournaments {
    return tournaments.where((tournament) {
      final query = _searchController.text.toLowerCase();

      final matchesSearch = tournament['name']!.toLowerCase().contains(query);
      final matchesLocation = tournament['location'] == selectedLocation;
      final matchesType = tournament['type'] == selectedType;
      final matchesMode = tournament['mode'] == selectedMode;
      final matchesCategory = tournament['category'] == selectedCategory;

      return matchesSearch &&
          matchesLocation &&
          matchesType &&
          matchesMode &&
          matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar torneo'),
      ),
      body: SafeArea(
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
              initialValue: selectedLocation,
              decoration: const InputDecoration(
                labelText: 'Ubicación',
              ),
              items: const [
                DropdownMenuItem(value: 'Asunción', child: Text('Asunción')),
                DropdownMenuItem(value: 'San Lorenzo', child: Text('San Lorenzo')),
                DropdownMenuItem(value: 'Luque', child: Text('Luque')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedLocation = value!;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: const InputDecoration(
                labelText: 'Tipo de torneo',
              ),
              items: const [
                DropdownMenuItem(value: 'Liga', child: Text('Liga')),
                DropdownMenuItem(value: 'Eliminatoria', child: Text('Eliminatoria')),
                DropdownMenuItem(value: 'Relámpago', child: Text('Relámpago')),
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
                DropdownMenuItem(value: '5 vs 5', child: Text('5 vs 5')),
                DropdownMenuItem(value: '7 vs 7', child: Text('7 vs 7')),
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
                DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
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
              'Torneos disponibles',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (filteredTournaments.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No se encontraron torneos con esos filtros.'),
                ),
              ),
            ...filteredTournaments.map(
              (tournament) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament['name']!,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Fecha: ${tournament['date']}'),
                        Text('Ubicación: ${tournament['location']}'),
                        Text('Tipo: ${tournament['type']}'),
                        Text('Modalidad: ${tournament['mode']}'),
                        Text('Categoría: ${tournament['category']}'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TournamentDetailPage(
                                  name: tournament['name']!,
                                  date: tournament['date']!,
                                  location: tournament['location']!,
                                  type: tournament['type']!,
                                  mode: tournament['mode']!,
                                  category: tournament['category']!,
                                ),
                              ),
                            );
                          },
                          child: const Text('Ver más'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}