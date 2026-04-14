import 'package:flutter/material.dart';

class LocationPage extends StatefulWidget {
  final String selectedCity;
  final ValueChanged<String> onCitySelected;

  const LocationPage({
    super.key,
    required this.selectedCity,
    required this.onCitySelected,
  });

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final TextEditingController searchController = TextEditingController();

  final List<String> cities = [
    'Asunción',
    'Luque',
    'San Lorenzo',
    'Fernando de la Mora',
    'Lambaré',
    'Capiatá',
    'Ciudad del Este',
  ];

  List<String> get filteredCities {
    final query = searchController.text.toLowerCase();
    return cities
        .where((city) => city.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _selectCity(String city) {
    widget.onCitySelected(city);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ubicación seleccionada: $city'),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar ubicaciones',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Función de GPS pendiente'),
                  ),
                );
              },
              icon: const Icon(Icons.my_location),
              label: const Text('LOCALIZARME'),
            ),
            const SizedBox(height: 24),
            Text(
              '¿Dónde estás jugando?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...filteredCities.map(
              (city) => Card(
                child: ListTile(
                  title: Text(city),
                  trailing: city == widget.selectedCity
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () => _selectCity(city),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}