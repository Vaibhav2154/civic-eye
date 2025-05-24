import 'package:civiceye/core/theme/app_pallete.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class LegalContactsPage extends StatefulWidget {
  const LegalContactsPage({super.key});

  @override
  State<LegalContactsPage> createState() => _LegalContactsPageState();
}

class _LegalContactsPageState extends State<LegalContactsPage> with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'NGO', 'Lawyer', 'Verified'];
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _fetchLegalContacts();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchLegalContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase
          .from('legal_contacts')
          .select('*')
          .order('priority_level', ascending: false);

      setState(() {
        _contacts = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load contacts: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredContacts {
    if (_selectedFilter == 'All') {
      return _contacts;
    } else if (_selectedFilter == 'Verified') {
      return _contacts.where((contact) => contact['verified'] == true).toList();
    } else {
      return _contacts.where((contact) => contact['type'] == _selectedFilter).toList();
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Legal Assistance Request',
    );
    
    if (!await launchUrl(emailUri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open email client for $email'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _launchCall(String phoneNumber) async {
    final Uri callUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    
    if (!await launchUrl(callUri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open phone app for $phoneNumber'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _shareContact(Map<String, dynamic> contact) async {
    String shareText = "Legal Contact Information\n\n";
    shareText += "Name: ${contact['name']}\n";
    shareText += "Type: ${contact['type']}\n";
    
    if (contact['specialization'] != null) {
      shareText += "Specialization: ${contact['specialization']}\n";
    }
    
    if (contact['region_covered'] != null) {
      shareText += "Regions Covered: ${contact['region_covered']}\n";
    }
    
    if (contact['email'] != null) {
      shareText += "Email: ${contact['email']}\n";
    }
    
    if (contact['phone_number'] != null) {
      shareText += "Phone: ${contact['phone_number']}\n";
    }
    
    await Share.share(shareText, subject: 'Legal Contact Information');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color.fromARGB(255, 6, 53, 182),
                primaryColor.withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              "Legal Contacts",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 3.0,
                    color: Colors.black45,
                  ),
                ],
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                ),
                onPressed: _fetchLegalContacts,
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: secondaryColor),
                  )
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
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _fetchLegalContacts,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: secondaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _filteredContacts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  color: Colors.white70,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No contacts found for the selected filter',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          )
                        : FadeTransition(
                            opacity: _fadeAnimation,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredContacts.length,
                              itemBuilder: (context, index) {
                                final contact = _filteredContacts[index];
                                return _buildContactCard(contact);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showRequestContactDialog();
        },
        backgroundColor: secondaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Request Contact', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showRequestContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor.withOpacity(0.95),
        title: const Text('Request a Legal Contact', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Need assistance with finding a legal contact in your area? Fill out a quick form and we\'ll try to connect you with someone suitable.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact request form will be available soon!'),
                    backgroundColor: primaryColor,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text('Continue to Form'),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _filterOptions.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? secondaryFgColor : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              showCheckmark: false,
              backgroundColor: primaryColor.withOpacity(0.2),
              selectedColor: secondaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? secondaryColor : Colors.white24,
                  width: 1,
                ),
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    final priorityColor = _getPriorityColor(contact['priority_level']);
    final isNGO = contact['type'] == 'NGO';
    
    return Hero(
      tag: 'contact-${contact['id']}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor.withOpacity(0.3),
                    primaryColor.withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: secondaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with name and verification badge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          secondaryColor.withOpacity(0.4),
                          primaryColor.withOpacity(0.4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isNGO ? Colors.teal.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isNGO ? Colors.teal : Colors.orange,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isNGO ? Colors.teal : Colors.orange).withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            isNGO ? Icons.corporate_fare : Icons.gavel,
                            color: isNGO ? Colors.teal : Colors.orange,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      contact['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (contact['verified'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green.withOpacity(0.5)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified, color: Colors.green, size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            'Verified',
                                            style: TextStyle(color: Colors.green, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contact['type'] ?? 'Unknown',
                                style: TextStyle(
                                  color: isNGO ? Colors.teal : Colors.orange,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Body content
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (contact['specialization'] != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.category, size: 16, color: secondaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Specialization',
                                style: TextStyle(color: secondaryColor, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            contact['specialization'],
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (contact['region_covered'] != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: secondaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Regions Covered',
                                style: TextStyle(color: secondaryColor, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            contact['region_covered'],
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (contact['languages_supported'] != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.language, size: 16, color: secondaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Languages',
                                style: TextStyle(color: secondaryColor, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (contact['languages_supported'] as String)
                                .split(',')
                                .map((lang) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: secondaryColor.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        lang.trim(),
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Priority indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: priorityColor.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.priority_high, color: priorityColor, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${contact['priority_level'] ?? 'Medium'} Priority",
                                    style: TextStyle(color: priorityColor, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Share button
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.white70),
                              onPressed: () => _shareContact(contact),
                              tooltip: 'Share contact info',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Contact buttons
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(0.3),
                          secondaryColor.withOpacity(0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildContactButton(
                          icon: Icons.email,
                          label: 'Email',
                          color: Colors.indigo,
                          onPressed: () {
                            final email = contact['email'];
                            if (email != null) {
                              _launchEmail(email);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No email available')),
                              );
                            }
                          },
                        ),
                        _buildContactButton(
                          icon: Icons.phone,
                          label: 'Call',
                          color: Colors.green,
                          onPressed: () {
                            final phone = contact['phone_number'];
                            if (phone != null) {
                              _launchCall(phone);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No phone number available')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: ElevatedButton.icon(
          icon: Icon(icon, color: Colors.white),
          label: Text(label),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 5,
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}