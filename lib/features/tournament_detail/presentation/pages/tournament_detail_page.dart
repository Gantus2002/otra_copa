import 'package:flutter/material.dart';

class TournamentDetailPage extends StatelessWidget {
  final String name;
  final String date;
  final String location;
  final String type;
  final String mode;
  final String category;

  const TournamentDetailPage({
    super.key,
    required this.name,
    required this.date,
    required this.location,
    required this.type,
    required this.mode,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del torneo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 10),
            Text('Fecha: $date'),
            Text('Ubicación: $location'),
            Text('Tipo: $type'),
            Text('Modalidad: $mode'),
            Text('Categoría: $category'),
          ],
        ),
      ),
    );
  }
}