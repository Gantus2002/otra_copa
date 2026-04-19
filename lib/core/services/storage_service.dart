import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndUploadImage({
    required String folder,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return null;

    final file = File(picked.path);
    final ext = picked.path.split('.').last.toLowerCase();
    final fileName =
        '$folder/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from('app-images').upload(
          fileName,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('app-images').getPublicUrl(fileName);
  }
}