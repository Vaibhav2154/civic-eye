import 'dart:convert';
import 'dart:developer';
import 'package:civiceye/core/constants/api_constants.dart';
import 'package:civiceye/core/theme/app_pallete.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Supabase client
  final SupabaseClient _supabase = Supabase.instance.client;

  // History data - Fix: Changed to use chat_sessions instead of messages for history
  List<Map<String, dynamic>> _chatHistory = [];
  String? _currentChatId;
  bool _isLoadingHistory = false;
  bool _isSendingMessage = false; // Fix: Add loading state for message sending

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadChatHistory();
  }

  void _initializeChat() {
    setState(() {
      _messages.clear();
      _messages.add({
        'text': 'Hello! I am your Lawgic AI assistant. How can I help you today?',
        'isUser': false,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    _createNewChatSession();
  }

  Future<void> _createNewChatSession() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      // Create a payload without user_id
      final payload = {
        'title': 'New Chat',
        'created_at': DateTime.now().toIso8601String(),
        'last_active_at': DateTime.now().toIso8601String(),
        // Remove the user_id field since it doesn't exist in the schema
      };
      
      final response = await _supabase
          .from('chat_sessions')
          .insert(payload)
          .select()
          .single();

      setState(() {
        _currentChatId = response['id'].toString();
      });
      
      await _loadChatHistory();
    } catch (e) {
      log('Error creating chat session: $e');
      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create new chat session')),
        );
      }
    }
  }

  // Fix: Load chat sessions (not messages) for history sidebar
  Future<void> _loadChatHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      
      // Fix: Query chat_sessions table instead of chat_messages for history
      final response = await _supabase
          .from('chat_sessions')
          .select('id, title, created_at, last_active_at')
          .order('last_active_at', ascending: false)
          .limit(20);

      setState(() {
        _chatHistory = List<Map<String, dynamic>>.from(response);
        _isLoadingHistory = false;
      });
    } catch (e) {
      log('Error loading chat history: $e');
      setState(() {
        _isLoadingHistory = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load chat history')),
        );
      }
    }
  }

  Future<void> _loadChatMessages(String chatId) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select('*')
          .eq('chat_session_id', chatId)
          .order('created_at', ascending: true);

      setState(() {
        _messages.clear();
        // Always add initial greeting
        _messages.add({
          'text': 'Hello! I am your Lawgic AI assistant. How can I help you today?',
          'isUser': false,
          'timestamp': DateTime.now().toIso8601String(),
        });

        // Add stored messages
        for (var msg in response) {
          _messages.add({
            'text': msg['message'],
            'isUser': msg['is_user'],
            'timestamp': msg['created_at'],
          });
        }
        _currentChatId = chatId;
      });

      _scrollToBottom();
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Close drawer
      }
    } catch (e) {
      log('Error loading chat messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load chat messages')),
        );
      }
    }
  }

  Future<void> _saveChatMessage(String message, bool isUser) async {
    if (_currentChatId == null) return;

    try {
      // Create a payload without user_id
      final payload = {
        'chat_session_id': int.parse(_currentChatId!),
        'message': message,
        'is_user': isUser,
        'created_at': DateTime.now().toIso8601String(),
        'chat_id': _generateUuid(),
        // Remove the user_id field
      };
      
      await _supabase.from('chat_messages').insert(payload);

      // Update last_active_at for the chat session
      await _supabase
          .from('chat_sessions')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('id', int.parse(_currentChatId!));

      // Update chat title if it's the first user message
      if (isUser && _messages.where((m) => m['isUser'] == true).length == 1) {
        String title = message.length > 30 ? '${message.substring(0, 30)}...' : message;
        await _supabase
            .from('chat_sessions')
            .update({'title': title})
            .eq('id', int.parse(_currentChatId!));
      }
    } catch (e) {
      log('Error saving message: $e');
    }
  }

  // Fix: Add UUID generator
  String _generateUuid() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (1000 + (DateTime.now().microsecond % 9000)).toString();
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      log('Attempting to delete chat with ID: $chatId');
      
      // Make sure we have a valid integer ID
      final int chatIdInt;
      try {
        chatIdInt = int.parse(chatId);
      } catch (e) {
        log('Invalid chat ID format: $e');
        throw Exception('Invalid chat ID format');
      }

      // Check if messages exist for this chat
      final messagesExist = await _supabase
          .from('chat_messages')
          .select('id')
          .eq('chat_session_id', chatIdInt)
          .limit(1);
    
      log('Messages exist check: ${messagesExist.length}');
    
      // Delete messages first (due to foreign key constraint)
      if (messagesExist.isNotEmpty) {
        await _supabase
            .from('chat_messages')
            .delete()
            .eq('chat_session_id', chatIdInt);
        log('Deleted messages for chat ID: $chatIdInt');
      }

      // Now delete the chat session
      await _supabase
          .from('chat_sessions')
          .delete()
          .eq('id', chatIdInt);
      log('Deleted chat session with ID: $chatIdInt');

      // If current chat is deleted, create new one
      if (_currentChatId == chatId) {
        _initializeChat();
      }

      await _loadChatHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted successfully')),
        );
      }
    } catch (e) {
      log('Error deleting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting chat: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSendingMessage) return;

    String userMessage = _messageController.text.trim();

    setState(() {
      _messages.add({
        'text': userMessage,
        'isUser': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _messageController.clear();
      _isSendingMessage = true; // Fix: Set loading state
    });

    // Save user message
    await _saveChatMessage(userMessage, true);
    _scrollToBottom();

    try {
      String baseUrl = ApiConstants.baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/chatbot/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'question': userMessage}),
      );

      String botAnswer;
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        botAnswer = responseData['answer'] ?? 'No response received';
      } else {
        botAnswer = 'Sorry, I couldn\'t get a response. Please try again later.';
        log('HTTP Error: ${response.statusCode} - ${response.body}');
      }

      setState(() {
        _messages.add({
          'text': botAnswer,
          'isUser': false,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _isSendingMessage = false; // Fix: Clear loading state
      });

      // Save bot message
      await _saveChatMessage(botAnswer, false);
      
    } catch (e) {
      log('Error sending message: $e');
      final errorMsg = 'An error occurred. Please check your connection.';
      
      setState(() {
        _messages.add({
          'text': errorMsg,
          'isUser': false,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _isSendingMessage = false; // Fix: Clear loading state
      });
      
      await _saveChatMessage(errorMsg, false);
    }

    _scrollToBottom();
    await _loadChatHistory(); // Refresh history
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      log('Error formatting timestamp: $e');
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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
              "Lawgic",
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
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.add_comment_outlined,
                  color: Colors.white,
                ),
                onPressed: _isSendingMessage ? null : () { // Fix: Disable when sending
                  _initializeChat();
                },
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
      drawer: _buildHistoryDrawer(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble(
                  message: message['text'],
                  isUser: message['isUser'],
                );
              },
            ),
          ),
          if (_isSendingMessage) // Fix: Show loading indicator
            Container(
              padding: const EdgeInsets.all(16.0),
              child: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'AI is thinking...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      backgroundColor: backgroundColor,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundColor, primaryColor.withOpacity(0.1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color.fromARGB(255, 6, 53, 182),
                    primaryColor.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Chat History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _chatHistory.isEmpty
                      ? const Center(
                          child: Text(
                            'No chat history',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _chatHistory.length,
                          itemBuilder: (context, index) {
                            final chat = _chatHistory[index];
                            final isCurrentChat = chat['id'].toString() == _currentChatId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              decoration: BoxDecoration(
                                color: isCurrentChat
                                    ? primaryColor.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: isCurrentChat
                                    ? Border.all(
                                        color: secondaryColor,
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: isCurrentChat
                                      ? secondaryColor
                                      : primaryColor.withOpacity(0.7),
                                  child: const Icon(
                                    Icons.chat_bubble_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  chat['title'] ?? 'Untitled Chat', // Fix: Use title instead of message
                                  style: TextStyle(
                                    color: isCurrentChat ? Colors.white : Colors.white70,
                                    fontWeight: isCurrentChat ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  _formatTimestamp(chat['last_active_at'] ?? chat['created_at']),
                                  style: TextStyle(
                                    color: isCurrentChat ? Colors.white60 : Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: isCurrentChat ? Colors.white : Colors.white54,
                                  ),
                                  color: primaryColor,
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      // Log the ID to confirm it's correct
                                      log('Selected chat ID for deletion: ${chat['id'].toString()}');
                                      _showDeleteConfirmation(chat['id'].toString());
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red, size: 20),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: isCurrentChat
                                    ? null
                                    : () {
                                        _loadChatMessages(chat['id'].toString());
                                      },
                              ),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  _initializeChat();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'New Chat',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String chatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: primaryColor,
        title: const Text(
          'Delete Chat',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this chat? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chatId);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.15),
            border: Border(
              top: BorderSide(
                color: secondaryColor.withOpacity(0.3),
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !_isSendingMessage, // Fix: Disable input when sending
                  decoration: InputDecoration(
                    hintText: _isSendingMessage 
                        ? 'Please wait...' 
                        : 'Type your civic query...',
                    hintStyle: const TextStyle(
                      color: Colors.white54,
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: primaryColor.withOpacity(0.2),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 14.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide(color: secondaryColor, width: 1.5),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 16.0),
                  cursorColor: secondaryColor,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  minLines: 1,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8.0),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [secondaryColor, primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: _isSendingMessage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: _isSendingMessage ? null : _sendMessage,
                  iconSize: 26,
                  splashRadius: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const MessageBubble({super.key, required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(
                  colors: [primaryColor.withOpacity(0.9), primaryColor],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                )
              : LinearGradient(
                  colors: [
                    const Color.fromARGB(255, 6, 53, 182).withOpacity(0.9),
                    secondaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20.0),
            topRight: const Radius.circular(20.0),
            bottomLeft: isUser ? const Radius.circular(20.0) : const Radius.circular(5.0),
            bottomRight: isUser ? const Radius.circular(5.0) : const Radius.circular(20.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: isUser
            ? Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16.0),
              )
            : MarkdownBody(
                data: message,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: primaryFgColor, fontSize: 16.0),
                  h1: const TextStyle(color: Colors.orange, fontSize: 24.0, fontWeight: FontWeight.bold),
                  h2: const TextStyle(color: Colors.orange, fontSize: 22.0, fontWeight: FontWeight.bold),
                  h3: const TextStyle(color: Colors.orange, fontSize: 20.0, fontWeight: FontWeight.bold),
                  h4: const TextStyle(color: Colors.orange, fontSize: 18.0, fontWeight: FontWeight.bold),
                  h5: const TextStyle(color: Colors.orange, fontSize: 17.0, fontWeight: FontWeight.bold),
                  h6: const TextStyle(color: Colors.orange, fontSize: 16.0, fontWeight: FontWeight.bold),
                  code: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    backgroundColor: Colors.black38,
                    fontSize: 14.0,
                    fontFamily: 'monospace',
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  blockquote: const TextStyle(color: Colors.orange, fontSize: 16.0, fontStyle: FontStyle.italic),
                  em: const TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
                  strong: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  a: const TextStyle(color: Colors.orange),
                  listBullet: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
                selectable: true,
                onTapLink: (text, url, title) {
                  if (url != null) {
                    log('Link tapped: $url');
                    // You can implement URL opening functionality here
                  }
                },
              ),
      ),
    );
  }
}