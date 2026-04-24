import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationPage extends StatefulWidget {
  final String selectedCity;

  const LocationPage({
    super.key,
    required this.selectedCity,
  });

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final TextEditingController searchController = TextEditingController();

  bool isLocating = false;

  final List<String> cities = [
    'Asunción',
    'Luque',
    'San Lorenzo',
    'Fernando de la Mora',
    'Lambaré',
    'Capiatá',
    'Ciudad del Este',
    'Encarnación',
    'Formosa',
    'Clorinda',
    'Corrientes',
  ];

  List<String> get filteredCities {
    final query = searchController.text.toLowerCase().trim();

    if (query.isEmpty) return cities;

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
    Navigator.pop(context, city);
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      isLocating = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage('Activá la ubicación/GPS del celular.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Permiso de ubicación denegado.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Permiso denegado permanentemente. Activá ubicación desde ajustes.',
        );
        await Geolocator.openAppSettings();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        _showMessage('No pudimos detectar tu ciudad.');
        return;
      }

      final place = placemarks.first;

      final city = _cleanLocationValue(
        place.locality,
        fallback: _cleanLocationValue(
          place.subAdministrativeArea,
          fallback: _cleanLocationValue(
            place.administrativeArea,
            fallback: '',
          ),
        ),
      );

      if (city.trim().isEmpty) {
        _showMessage('No pudimos detectar tu ciudad.');
        return;
      }

      _selectCity(city);
    } catch (e) {
      _showMessage('No se pudo obtener tu ubicación: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLocating = false;
        });
      }
    }
  }

  String _cleanLocationValue(String? value, {required String fallback}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return fallback;
    return text;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar ciudad',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isLocating ? null : _useCurrentLocation,
              icon: isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                isLocating ? 'Detectando ubicación...' : 'Usar mi ubicación',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ciudades disponibles',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
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