class CommunityPost {
  final String id;
  final String title;
  final String description;
  final String category;
  final String location;
  final String date;
  final bool isAnonymous;
  final String userId;

  CommunityPost({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.date,
    required this.isAnonymous,
    required this.userId,
  });

  factory CommunityPost.fromMap(Map<String, dynamic> map) {
    return CommunityPost(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      location: '${map['city'] ?? ''}, ${map['state'] ?? ''}',
      date: map['submitted_at'] ?? '',
      isAnonymous: map['is_anonymous'] ?? false,
      userId: map['userid'] ?? '',
    );
  }
}