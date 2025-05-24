import 'package:civiceye/core/theme/app_pallete.dart';
import 'package:civiceye/features/community/models/community_model.dart';
import 'package:civiceye/features/community/services/community_service.dart';
import 'package:civiceye/features/report_crime/report_crime.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final CommunityService _communityService = CommunityService();
  bool _isLoading = true;
  List<CommunityPost> _posts = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final posts = await _communityService.getPosts();
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load posts: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color.fromARGB(255, 6, 53, 182), primaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              "Community Reports",
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // const Text(
            //   "Community Reports",
            //   style: TextStyle(
            //     fontSize: 24,
            //     fontWeight: FontWeight.bold,
            //     color: textColor,
            //   ),
            // ),
            const SizedBox(height: 10),
            const Text(
              "View public incident reports shared by community members.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 20),
            
            // Refresh button
            if (!_isLoading)
              ElevatedButton.icon(
                onPressed: _loadPosts,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryColor.withOpacity(0.7),
                  foregroundColor: Colors.white,
                ),
              ),
              
            const SizedBox(height: 20),
            
            // Posts list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: secondaryColor))
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadPosts,
                                child: const Text('Try Again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: secondaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _posts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.article_outlined,
                                    color: Colors.white70,
                                    size: 48,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No public reports available',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _posts.length,
                              itemBuilder: (context, index) {
                                return CommunityPostCard(post: _posts[index]);
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final String? userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReportCrimePage(userId: userId),
              ),
            ).then((_) {
              // Refresh posts when returning from report page
              _loadPosts();
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please log in to create a post')),
            );
          }
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class CommunityPostCard extends StatelessWidget {
  final CommunityPost post;

  const CommunityPostCard({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    // Format the date
    DateTime postDate = DateTime.parse(post.date);
    String formattedDate = DateFormat('MMM d, yyyy').format(postDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      color: primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: secondaryColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getCategoryIcon(post.category),
                  color: secondaryColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    post.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.description,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white70,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            // Location and Date information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(
                      post.location,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Category chip
            Wrap(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: secondaryColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _formatCategory(post.category),
                    style: TextStyle(color: secondaryColor, fontSize: 12),
                  ),
                ),
                if (post.isAnonymous)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Anonymous',
                      style: TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'corruption':
        return Icons.attach_money;
      case 'harassment':
        return Icons.person_off;
      case 'theft':
        return Icons.money_off;
      case 'violence':
        return Icons.dangerous;
      case 'discrimination':
        return Icons.people_alt;
      default:
        return Icons.report_problem;
    }
  }

  String _formatCategory(String category) {
    return category.isNotEmpty 
        ? '${category[0].toUpperCase()}${category.substring(1)}'
        : 'Other';
  }
}