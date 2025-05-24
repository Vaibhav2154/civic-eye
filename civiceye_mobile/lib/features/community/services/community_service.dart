import 'package:civiceye/features/community/models/community_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<CommunityPost>> getPosts() async {
    try {
      final response = await supabase
          .from('reports')
          .select('*')
          .eq('isapublicpost', true) // Only fetch public posts
          .order('submitted_at', ascending: false);

      return List<CommunityPost>.from(
        response.map((post) => CommunityPost.fromMap(post)),
      );
    } catch (e) {
      print('Error fetching community posts: $e');
      return [];
    }
  }
}