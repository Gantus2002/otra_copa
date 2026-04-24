import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';

class AdminHomeContentPage extends StatefulWidget {
  const AdminHomeContentPage({super.key});

  @override
  State<AdminHomeContentPage> createState() => _AdminHomeContentPageState();
}

class _AdminHomeContentPageState extends State<AdminHomeContentPage> {
  List<Map<String, dynamic>> banners = [];
  List<Map<String, dynamic>> ads = [];
  List<Map<String, dynamic>> tournaments = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadData() async {
    _safeSetState(() => isLoading = true);

    try {
      final bannersData = await SupabaseService.client
          .from('home_banners')
          .select()
          .order('sort_order')
          .order('id', ascending: false);

      final adsData = await SupabaseService.client
          .from('home_ads')
          .select()
          .order('id', ascending: false);

      final tournamentsData = await SupabaseService.client
          .from('tournaments')
          .select('id, name')
          .order('id', ascending: false);

      _safeSetState(() {
        banners = List<Map<String, dynamic>>.from(bannersData);
        ads = List<Map<String, dynamic>>.from(adsData);
        tournaments = List<Map<String, dynamic>>.from(tournamentsData);
      });
    } catch (e) {
      _showSnackBar('Error cargando contenido: $e');
    } finally {
      _safeSetState(() => isLoading = false);
    }
  }

  Future<void> _deleteBanner(int id) async {
    try {
      final deleted = await SupabaseService.client
          .from('home_banners')
          .delete()
          .eq('id', id)
          .select();

      if (deleted.isEmpty) {
        _showSnackBar(
          'No se eliminó el banner. Revisá permisos/RLS en Supabase.',
        );
        return;
      }

      await _loadData();
      _showSnackBar('Banner eliminado');
    } catch (e) {
      _showSnackBar('Error eliminando banner: $e');
    }
  }

  Future<void> _deleteAd(int id) async {
    try {
      final deleted = await SupabaseService.client
          .from('home_ads')
          .delete()
          .eq('id', id)
          .select();

      if (deleted.isEmpty) {
        _showSnackBar(
          'No se eliminó el anuncio. Revisá permisos/RLS en Supabase.',
        );
        return;
      }

      await _loadData();
      _showSnackBar('Anuncio eliminado');
    } catch (e) {
      _showSnackBar('Error eliminando anuncio: $e');
    }
  }

  Future<void> _toggleBannerStatus(int id, bool currentValue) async {
    try {
      final updated = await SupabaseService.client
          .from('home_banners')
          .update({'is_active': !currentValue})
          .eq('id', id)
          .select();

      if (updated.isEmpty) {
        _showSnackBar(
          'No se actualizó el banner. Revisá permisos/RLS en Supabase.',
        );
        return;
      }

      await _loadData();
    } catch (e) {
      _showSnackBar('Error actualizando banner: $e');
    }
  }

  Future<void> _toggleAdStatus(int id, bool currentValue) async {
    try {
      final updated = await SupabaseService.client
          .from('home_ads')
          .update({'is_active': !currentValue})
          .eq('id', id)
          .select();

      if (updated.isEmpty) {
        _showSnackBar(
          'No se actualizó el anuncio. Revisá permisos/RLS en Supabase.',
        );
        return;
      }

      await _loadData();
    } catch (e) {
      _showSnackBar('Error actualizando anuncio: $e');
    }
  }

  Future<void> _openBannerForm({Map<String, dynamic>? banner}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminBannerFormPage(
          banner: banner,
          tournaments: tournaments,
        ),
      ),
    );

    if (!mounted) return;

    if (changed == true) {
      await _loadData();
    }
  }

  Future<void> _openAdForm({Map<String, dynamic>? ad}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAdFormPage(ad: ad),
      ),
    );

    if (!mounted) return;

    if (changed == true) {
      await _loadData();
    }
  }

  String _bannerTargetText(Map<String, dynamic> banner) {
    final type = banner['target_type']?.toString();
    final value = banner['target_value']?.toString();

    if (type == null || type.isEmpty || value == null || value.isEmpty) {
      return 'Sin destino';
    }

    if (type == 'tournament') {
      final matches = tournaments.where((t) => '${t['id']}' == value).toList();

      if (matches.isNotEmpty) {
        return 'Torneo: ${matches.first['name']}';
      }

      return 'Torneo ID: $value';
    }

    if (type == 'external') {
      return 'Link externo';
    }

    return 'Sin destino';
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _imageWithCacheBust(String url) {
    if (url.trim().isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contenido Home'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Banners del carrusel',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _openBannerForm(),
                        child: const Text('Agregar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (banners.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Todavía no hay banners'),
                      ),
                    )
                  else
                    ...banners.map(
                      (banner) {
                        final imageUrl =
                            banner['image_url']?.toString().trim() ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: Image.network(
                                    _imageWithCacheBust(imageUrl),
                                    key: ValueKey(
                                      '${banner['id']}_${banner['image_url']}',
                                    ),
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 120,
                                      alignment: Alignment.center,
                                      color: Colors.black12,
                                      child: const Text(
                                        'No se pudo cargar la imagen',
                                      ),
                                    ),
                                  ),
                                ),
                              ListTile(
                                title: Text(
                                  banner['title']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                      ? banner['title'].toString()
                                      : 'Banner',
                                ),
                                subtitle: Text(
                                  'Orden: ${banner['sort_order'] ?? 0}\n'
                                  'Activo: ${banner['is_active'] == true ? 'Sí' : 'No'}\n'
                                  '${_bannerTargetText(banner)}',
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await _openBannerForm(banner: banner);
                                    } else if (value == 'toggle') {
                                      await _toggleBannerStatus(
                                        banner['id'] as int,
                                        banner['is_active'] == true,
                                      );
                                    } else if (value == 'delete') {
                                      final confirm = await _confirmDelete(
                                        title: 'Eliminar banner',
                                        message:
                                            '¿Seguro que querés eliminar este banner?',
                                      );

                                      if (confirm == true) {
                                        await _deleteBanner(banner['id'] as int);
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text('Activar / Desactivar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Banner inferior',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _openAdForm(),
                        child: const Text('Agregar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (ads.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Todavía no hay anuncios'),
                      ),
                    )
                  else
                    ...ads.map(
                      (ad) {
                        final imageUrl =
                            ad['image_url']?.toString().trim() ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: Image.network(
                                    _imageWithCacheBust(imageUrl),
                                    key: ValueKey(
                                      '${ad['id']}_${ad['image_url']}',
                                    ),
                                    height: 100,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 100,
                                      alignment: Alignment.center,
                                      color: Colors.black12,
                                      child: const Text(
                                        'No se pudo cargar la imagen',
                                      ),
                                    ),
                                  ),
                                ),
                              ListTile(
                                title: Text(
                                  ad['title']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                      ? ad['title'].toString()
                                      : 'Anuncio',
                                ),
                                subtitle: Text(
                                  'Activo: ${ad['is_active'] == true ? 'Sí' : 'No'}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await _openAdForm(ad: ad);
                                    } else if (value == 'toggle') {
                                      await _toggleAdStatus(
                                        ad['id'] as int,
                                        ad['is_active'] == true,
                                      );
                                    } else if (value == 'delete') {
                                      final confirm = await _confirmDelete(
                                        title: 'Eliminar anuncio',
                                        message:
                                            '¿Seguro que querés eliminar este anuncio?',
                                      );

                                      if (confirm == true) {
                                        await _deleteAd(ad['id'] as int);
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text('Activar / Desactivar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

class AdminBannerFormPage extends StatefulWidget {
  final Map<String, dynamic>? banner;
  final List<Map<String, dynamic>> tournaments;

  const AdminBannerFormPage({
    super.key,
    this.banner,
    required this.tournaments,
  });

  @override
  State<AdminBannerFormPage> createState() => _AdminBannerFormPageState();
}

class _AdminBannerFormPageState extends State<AdminBannerFormPage> {
  final ImagePicker picker = ImagePicker();

  late final TextEditingController titleController;
  late final TextEditingController subtitleController;
  late final TextEditingController sortOrderController;
  late final TextEditingController externalUrlController;

  File? selectedImage;
  String? imageUrl;

  bool isActive = true;
  bool isSaving = false;

  String targetType = 'none';
  String? selectedTournamentId;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.banner?['title']?.toString() ?? '',
    );

    subtitleController = TextEditingController(
      text: widget.banner?['subtitle']?.toString() ?? '',
    );

    sortOrderController = TextEditingController(
      text: widget.banner?['sort_order']?.toString() ?? '0',
    );

    final existingType = widget.banner?['target_type']?.toString();
    final existingValue = widget.banner?['target_value']?.toString();

    externalUrlController = TextEditingController(
      text: existingType == 'external' ? (existingValue ?? '') : '',
    );

    imageUrl = widget.banner?['image_url']?.toString();
    isActive = widget.banner?['is_active'] == true || widget.banner == null;

    if (existingType == 'tournament') {
      targetType = 'tournament';
      selectedTournamentId = existingValue;
    } else if (existingType == 'external') {
      targetType = 'external';
    } else {
      targetType = 'none';
    }

    final tournamentExists = widget.tournaments.any(
      (t) => '${t['id']}' == selectedTournamentId,
    );

    if (!tournamentExists) {
      selectedTournamentId = null;
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> pickImage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (picked != null) {
      _safeSetState(() {
        selectedImage = File(picked.path);
      });
    }
  }

  Future<String> uploadImage(File file) async {
    final normalizedName = file.path.split('/').last.split('\\').last;
    final fileName =
        'banner_${DateTime.now().millisecondsSinceEpoch}_$normalizedName';

    await Supabase.instance.client.storage.from('home').upload(
          fileName,
          file,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'image/jpeg',
          ),
        );

    return Supabase.instance.client.storage.from('home').getPublicUrl(fileName);
  }

  Future<void> _save() async {
    _safeSetState(() => isSaving = true);

    try {
      String finalUrl = imageUrl ?? '';

      if (selectedImage != null) {
        finalUrl = await uploadImage(selectedImage!);
      }

      if (finalUrl.trim().isEmpty) {
        throw Exception('Seleccioná una imagen');
      }

      String finalTargetType = '';
      String finalTargetValue = '';

      if (targetType == 'tournament') {
        if (selectedTournamentId == null || selectedTournamentId!.isEmpty) {
          throw Exception('Seleccioná un torneo');
        }

        finalTargetType = 'tournament';
        finalTargetValue = selectedTournamentId!;
      } else if (targetType == 'external') {
        final url = externalUrlController.text.trim();

        if (url.isEmpty) {
          throw Exception('Ingresá una URL');
        }

        finalTargetType = 'external';
        finalTargetValue = url;
      }

      final payload = {
        'title': titleController.text.trim(),
        'subtitle': subtitleController.text.trim(),
        'image_url': finalUrl,
        'sort_order': int.tryParse(sortOrderController.text.trim()) ?? 0,
        'is_active': isActive,
        'target_type': finalTargetType,
        'target_value': finalTargetValue,
      };

      final saved = widget.banner == null
          ? await Supabase.instance.client
              .from('home_banners')
              .insert(payload)
              .select()
          : await Supabase.instance.client
              .from('home_banners')
              .update(payload)
              .eq('id', widget.banner!['id'])
              .select();

      if (saved.isEmpty) {
        throw Exception(
          'No se guardó ningún cambio. Revisá permisos/RLS en Supabase.',
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      _safeSetState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    subtitleController.dispose();
    sortOrderController.dispose();
    externalUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.banner != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar banner' : 'Nuevo banner'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: subtitleController,
            decoration: const InputDecoration(labelText: 'Subtítulo'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: pickImage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Seleccionar imagen'),
          ),
          if (selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  selectedImage!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (imageUrl != null &&
              imageUrl!.trim().isNotEmpty &&
              selectedImage == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl!,
                  key: ValueKey(imageUrl),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 150,
                    alignment: Alignment.center,
                    color: Colors.black12,
                    child: const Text('No se pudo cargar la imagen'),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: sortOrderController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Orden'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: targetType,
            decoration: const InputDecoration(labelText: 'Destino del banner'),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Sin destino')),
              DropdownMenuItem(value: 'tournament', child: Text('Abrir torneo')),
              DropdownMenuItem(value: 'external', child: Text('Link externo')),
            ],
            onChanged: (value) {
              _safeSetState(() {
                targetType = value ?? 'none';

                if (targetType != 'tournament') {
                  selectedTournamentId = null;
                }

                if (targetType != 'external') {
                  externalUrlController.clear();
                }
              });
            },
          ),
          if (targetType == 'tournament') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedTournamentId,
              decoration: const InputDecoration(labelText: 'Seleccionar torneo'),
              items: widget.tournaments
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: '${t['id']}',
                      child: Text(t['name']?.toString() ?? 'Torneo'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                _safeSetState(() {
                  selectedTournamentId = value;
                });
              },
            ),
          ],
          if (targetType == 'external') ...[
            const SizedBox(height: 12),
            TextField(
              controller: externalUrlController,
              decoration: const InputDecoration(labelText: 'URL externa'),
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            value: isActive,
            onChanged: (v) => _safeSetState(() => isActive = v),
            title: const Text('Activo'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isSaving ? null : _save,
            child: Text(isSaving ? 'Guardando...' : 'Guardar banner'),
          ),
        ],
      ),
    );
  }
}

class AdminAdFormPage extends StatefulWidget {
  final Map<String, dynamic>? ad;

  const AdminAdFormPage({
    super.key,
    this.ad,
  });

  @override
  State<AdminAdFormPage> createState() => _AdminAdFormPageState();
}

class _AdminAdFormPageState extends State<AdminAdFormPage> {
  final ImagePicker picker = ImagePicker();

  late final TextEditingController titleController;

  File? selectedImage;
  String? imageUrl;

  bool isActive = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.ad?['title']?.toString() ?? '',
    );

    imageUrl = widget.ad?['image_url']?.toString();
    isActive = widget.ad?['is_active'] == true || widget.ad == null;
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> pickImage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (picked != null) {
      _safeSetState(() {
        selectedImage = File(picked.path);
      });
    }
  }

  Future<String> uploadImage(File file) async {
    final normalizedName = file.path.split('/').last.split('\\').last;
    final fileName =
        'ad_${DateTime.now().millisecondsSinceEpoch}_$normalizedName';

    await Supabase.instance.client.storage.from('home').upload(
          fileName,
          file,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'image/jpeg',
          ),
        );

    return Supabase.instance.client.storage.from('home').getPublicUrl(fileName);
  }

  Future<void> _save() async {
    _safeSetState(() => isSaving = true);

    try {
      String finalUrl = imageUrl ?? '';

      if (selectedImage != null) {
        finalUrl = await uploadImage(selectedImage!);
      }

      if (finalUrl.trim().isEmpty) {
        throw Exception('Seleccioná una imagen');
      }

      final payload = {
        'title': titleController.text.trim(),
        'image_url': finalUrl,
        'is_active': isActive,
      };

      final saved = widget.ad == null
          ? await Supabase.instance.client.from('home_ads').insert(payload).select()
          : await Supabase.instance.client
              .from('home_ads')
              .update(payload)
              .eq('id', widget.ad!['id'])
              .select();

      if (saved.isEmpty) {
        throw Exception(
          'No se guardó ningún cambio. Revisá permisos/RLS en Supabase.',
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      _safeSetState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.ad != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar anuncio' : 'Nuevo anuncio'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: pickImage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Seleccionar imagen'),
          ),
          if (selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  selectedImage!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (imageUrl != null &&
              imageUrl!.trim().isNotEmpty &&
              selectedImage == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl!,
                  key: ValueKey(imageUrl),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    alignment: Alignment.center,
                    color: Colors.black12,
                    child: const Text('No se pudo cargar la imagen'),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: isActive,
            onChanged: (v) => _safeSetState(() => isActive = v),
            title: const Text('Activo'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isSaving ? null : _save,
            child: Text(isSaving ? 'Guardando...' : 'Guardar anuncio'),
          ),
        ],
      ),
    );
  }
}