import 'package:flutter/material.dart';
import '../../../tournament_detail/presentation/pages/tournament_detail_page.dart';

class MyTournamentsPage extends StatelessWidget {
  const MyTournamentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tournaments = [
      {
        'name': 'Copa Universidad',
        'date': '20/04/2026',
        'location': 'Asunción',
        'status': 'Próximo partido',
        'role': 'Jugador',
        'type': 'Liga',
        'mode': '5 vs 5',
        'category': 'Masculino',
      },
      {
        'name': 'Torneo Apertura 2026',
        'date': '25/04/2026',
        'location': 'San Lorenzo',
        'status': 'Inscripción confirmada',
        'role': 'Jugador',
        'type': 'Eliminatoria',
        'mode': '7 vs 7',
        'category': 'Mixto',
      },
      {
        'name': 'Relámpago F5',
        'date': '27/04/2026',
        'location': 'Luque',
        'status': 'Organizando',
        'role': 'Organizador',
        'type': 'Relámpago',
        'mode': '5 vs 5',
        'category': 'Femenino',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis torneos'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Tus torneos activos',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Acá vas a poder ver todos los torneos en los que participás o administrás.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar en mis torneos',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
            ...tournaments.map(
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
                        Text('Estado: ${tournament['status']}'),
                        Text('Rol: ${tournament['role']}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
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
                                child: const Text('Ver torneo'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {},
                                child: const Text('Ver partido'),
                              ),
                            ),
                          ],
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