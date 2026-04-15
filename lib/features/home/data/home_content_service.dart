import '../../../core/services/supabase_service.dart';

class HomeContentService {
  Future<List<Map<String, dynamic>>> getActiveBanners() async {
    final response = await SupabaseService.client
        .from('home_banners')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getActiveAd() async {
    final response = await SupabaseService.client
        .from('home_ads')
        .select()
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();

    return response;
  }
}