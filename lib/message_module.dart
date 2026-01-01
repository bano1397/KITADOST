import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_system_module.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Screen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        primarySwatch: Colors.blue,
      ),
      home: const ChatScreen(),
    );
  }
}

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? messageId;
  bool showDelivered;
  String? reaction;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.messageId,
    this.showDelivered = true,
    this.reaction,
  });
}

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String chatName;
  final bool isSystemChat;
  final String? otherUserId;

  const ChatScreen({
    Key? key,
    this.chatId,
    this.chatName = 'From System',
    this.isSystemChat = true,
    this.otherUserId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  late DatabaseReference _messagesRef;
  late DatabaseReference _chatRef;
  String _otherUserName = '';
  File? _otherUserAvatar;
  bool _isLoadingProfile = true;
  
  @override
  void initState() {
    super.initState();
    _initializeChat();
    final isSystem = widget.isSystemChat || widget.chatId == 'system';
    if (widget.otherUserId != null && !isSystem) {
      _loadOtherUserProfile();
    } else {
      _otherUserName = widget.chatName;
      _isLoadingProfile = false;
    }
  }
  
  Future<void> _loadOtherUserProfile() async {
    try {
      print('DEBUG: Loading other user profile. otherUserId: ${widget.otherUserId}, chatName: ${widget.chatName}');
      
      if (widget.otherUserId == null) {
        print('DEBUG: otherUserId is null, using chatName: ${widget.chatName}');
        setState(() {
          _otherUserName = widget.chatName;
          _isLoadingProfile = false;
        });
        return;
      }

      print('DEBUG: Fetching user data from Firebase for userId: ${widget.otherUserId}');
      // Fetch user's current name from Firebase
      final userSnapshot = await FirebaseDatabase.instance
          .ref('users/${widget.otherUserId}')
          .once();
      
      print('DEBUG: User snapshot exists: ${userSnapshot.snapshot.exists}');
      if (userSnapshot.snapshot.value != null) {
        final userData = userSnapshot.snapshot.value as Map<dynamic, dynamic>;
        _otherUserName = userData['username'] ?? widget.chatName;
        print('DEBUG: Found username in Firebase: $_otherUserName');
      } else {
        _otherUserName = widget.chatName;
        print('DEBUG: No user data found, using chatName: $_otherUserName');
      }

      // Load user's avatar from Firebase Database first
      try {
        final avatarSnapshot = await FirebaseDatabase.instance
            .ref('users/${widget.otherUserId}/avatar')
            .once();
        
        if (avatarSnapshot.snapshot.exists && avatarSnapshot.snapshot.value != null) {
          final avatarBase64 = avatarSnapshot.snapshot.value as String;
          if (avatarBase64.isNotEmpty) {
            final bytes = base64Decode(avatarBase64);
            final tempDir = Directory.systemTemp;
            final file = File('${tempDir.path}/chat_avatar_${widget.otherUserId}.png');
            await file.writeAsBytes(bytes);
            _otherUserAvatar = file;
            
            // Cache it
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('avatar_base64_${widget.otherUserId}', avatarBase64);
          }
        } else {
          // Fallback to cached avatar
          final prefs = await SharedPreferences.getInstance();
          final avatarBase64 = prefs.getString('avatar_base64_${widget.otherUserId}');
          if (avatarBase64 != null && avatarBase64.isNotEmpty) {
            final bytes = base64Decode(avatarBase64);
            final tempDir = Directory.systemTemp;
            final file = File('${tempDir.path}/chat_avatar_${widget.otherUserId}.png');
            await file.writeAsBytes(bytes);
            _otherUserAvatar = file;
          }
        }
      } catch (e) {
        print('Error loading chat user avatar: $e');
      }

      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('Error loading other user profile: $e');
      if (mounted) {
        setState(() {
          _otherUserName = widget.chatName;
          _isLoadingProfile = false;
        });
      }
    }
  }
  
  void _initializeChat() {
    // Check if this is a system chat (either explicitly set or chatId is 'system')
    final isSystem = widget.isSystemChat || widget.chatId == 'system';
    
    if (isSystem) {
      // System chat with helpful welcome messages
      _messages = [
        Message(
          text: '👋 Welcome to KITAB DOST!',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        Message(
          text: 'KITAB DOST is a mobile application designed to enhance book accessibility among students through a peer-to-peer lending system.',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
        ),
        Message(
          text: '📚 Here\'s what you can do:\n\n• Browse and search for books\n• Post your own books for lending\n• Request to borrow books from other students\n• Chat with book owners\n• Manage your borrowings and postings',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
        Message(
          text: '💡 Need help? Type your question below and I\'ll try to assist you!',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      ];
      // Scroll to bottom after initialization
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } else if (widget.chatId != null) {
      // Real chat with Firebase
      _messagesRef = FirebaseDatabase.instance.ref('chats/${widget.chatId}/messages');
      _chatRef = FirebaseDatabase.instance.ref('chats/${widget.chatId}');
      _loadMessages();
    }
  }
  
  void _loadMessages() {
    _messagesRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final List<Message> loadedMessages = [];
        data.forEach((key, value) {
          if (value is Map) {
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            loadedMessages.add(Message(
              text: value['text'] ?? '',
              isUser: value['senderId'] == currentUserId,
              timestamp: DateTime.fromMillisecondsSinceEpoch(value['timestamp'] ?? 0),
              messageId: key,
              reaction: value['reaction'],
            ));
          }
        });
        loadedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        if (mounted) {
          setState(() {
            _messages = loadedMessages;
          });
          _scrollToBottom();
        }
      }
    });
  }
  
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    // If this is a system chat, show auto-reply
    final isSystem = widget.isSystemChat || widget.chatId == 'system';
    if (isSystem) {
      setState(() {
        _messages.add(Message(
          text: messageText,
          isUser: true,
          timestamp: DateTime.now(),
        ));
      });
      
      // Add system auto-reply with contextual responses
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay for better UX
      
      String systemReply = _getSystemReply(messageText);
      
      if (mounted) {
        setState(() {
          _messages.add(Message(
            text: systemReply,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    } else if (widget.chatId != null) {
      // Send to Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      final messageData = {
        'text': messageText,
        'senderId': currentUser.uid,
        'timestamp': ServerValue.timestamp,
      };
      
      await _messagesRef.push().set(messageData);
      
      // Update last message in chat metadata and mark as unread for recipient
      await _chatRef.update({
        'lastMessage': messageText,
        'lastMessageTime': ServerValue.timestamp,
        'readBy/${currentUser.uid}': true, // Keep as read for sender
      });
      
      // Mark as unread for the other user
      if (widget.otherUserId != null) {
        await _chatRef.update({
          'readBy/${widget.otherUserId}': false,
        });
        
        // Get sender name and send notification
        String senderName = currentUser.displayName ?? 'Someone';
        final userSnapshot = await FirebaseDatabase.instance
            .ref('users/${currentUser.uid}/username')
            .once();
        if (userSnapshot.snapshot.exists) {
          senderName = userSnapshot.snapshot.value.toString();
        }
        
        // Send notification to recipient
        final notificationSystem = NotificationSystemModule();
        await notificationSystem.notifyMessageReceived(
          recipientId: widget.otherUserId!,
          senderName: senderName,
          messagePreview: messageText.length > 50 
              ? '${messageText.substring(0, 50)}...' 
              : messageText,
          chatId: widget.chatId!,
        );
      }
      
      _scrollToBottom();
    }
  }

  String _getSystemReply(String userMessage) {
    final lowerMessage = userMessage.toLowerCase().trim();
    
    // Check for specific keywords first (most specific to least specific)
    
    // Borrowing related - expanded keywords
    if (lowerMessage.contains('borrow') || lowerMessage.contains('lend') || 
        lowerMessage.contains('get book') || lowerMessage.contains('take book') ||
        lowerMessage.contains('request book') || lowerMessage.contains('how to borrow') ||
        lowerMessage.contains('want to borrow') || lowerMessage.contains('need book') ||
        lowerMessage.contains('get a book') || lowerMessage.contains('take a book') ||
        lowerMessage.contains('named borrow') || lowerMessage.contains('borrow books')) {
      return '📚 To borrow a book:\n\n1. Browse books on the Home screen\n2. Tap on a book you\'re interested in\n3. Tap "Message" to contact the owner\n4. Request to borrow the book\n5. Wait for the owner\'s approval\n\nHappy reading! 📖';
    }
    
    // Finding/Browsing books - NEW category
    if (lowerMessage.contains('available') || lowerMessage.contains('find book') ||
        lowerMessage.contains('search book') || lowerMessage.contains('browse book') ||
        lowerMessage.contains('look for') || lowerMessage.contains('where to find') ||
        lowerMessage.contains('show me') || lowerMessage.contains('see books') ||
        lowerMessage.contains('list of') || lowerMessage.contains('all books') ||
        lowerMessage.contains('what books') || lowerMessage.contains('which books') ||
        lowerMessage.contains('books available') || lowerMessage.contains('available books')) {
      return '🔍 To find and browse books:\n\n1. Go to the Home screen\n2. Browse through the available books\n3. Use the search bar to find specific books by title, author, or genre\n4. Tap on any book to see details\n5. Tap "Message" to contact the owner if you want to borrow it\n\nYou can filter books by genre, condition, and more!';
    }
    
    // Posting related - expanded keywords
    if (lowerMessage.contains('post') || lowerMessage.contains('add book') || 
        lowerMessage.contains('upload book') || lowerMessage.contains('sell book') ||
        lowerMessage.contains('share book') || lowerMessage.contains('how to post') ||
        lowerMessage.contains('want to post') || lowerMessage.contains('list my book') ||
        lowerMessage.contains('put my book') || lowerMessage.contains('give my book') ||
        lowerMessage.contains('offer book') || lowerMessage.contains('create listing')) {
      return '📖 To post a book:\n\n1. Go to the Home screen\n2. Tap the "+" button at the bottom\n3. Fill in the book details (title, author, genre, etc.)\n4. Add a cover image\n5. Submit your book\n\nYour book will be visible to all KITAB DOST users!';
    }
    
    // Chat/Messaging related - expanded keywords
    if (lowerMessage.contains('chat') || lowerMessage.contains('message') || 
        lowerMessage.contains('contact owner') || lowerMessage.contains('talk to') ||
        lowerMessage.contains('send message') || lowerMessage.contains('text owner') ||
        lowerMessage.contains('communicate') || lowerMessage.contains('reach out')) {
      return '💬 To chat with book owners:\n\n1. Go to a book\'s detail page\n2. Tap the "Message" button\n3. Start chatting with the owner\n\nYou can also access all your chats from the Messages tab!';
    }
    
    // Profile/Settings related - expanded keywords
    if (lowerMessage.contains('profile') || lowerMessage.contains('account') || 
        lowerMessage.contains('settings') || lowerMessage.contains('edit profile') ||
        lowerMessage.contains('my profile') || lowerMessage.contains('change profile') ||
        lowerMessage.contains('update profile') || lowerMessage.contains('manage account')) {
      return '⚙️ To manage your profile:\n\n1. Go to the Profile tab\n2. Tap on your profile picture\n3. Edit your information, bio, and privacy settings\n\nYou can also manage your posted books and borrowing history here!';
    }
    
    // Greetings - expanded
    if (lowerMessage.contains('hello') || lowerMessage.contains('hi') || 
        lowerMessage.contains('hey') || lowerMessage == 'hii' || lowerMessage == 'hiii' ||
        lowerMessage == 'hey there' || lowerMessage == 'hi there' || lowerMessage.contains('good morning') ||
        lowerMessage.contains('good afternoon') || lowerMessage.contains('good evening')) {
      return '👋 Hello! How can I help you today? You can ask me about:\n\n• Posting books\n• Borrowing books\n• Finding available books\n• Using the chat feature\n• Managing your profile';
    }
    
    // Thanks - expanded
    if (lowerMessage.contains('thank') || lowerMessage.contains('thanks') || 
        lowerMessage.contains('thx') || lowerMessage.contains('ty') ||
        lowerMessage.contains('appreciate') || lowerMessage.contains('grateful')) {
      return '😊 You\'re welcome! If you need any more help, just ask. Happy reading! 📚';
    }
    
    // Problems/Issues - expanded
    if (lowerMessage.contains('problem') || lowerMessage.contains('issue') || 
        lowerMessage.contains('error') || lowerMessage.contains('bug') ||
        lowerMessage.contains('not working') || lowerMessage.contains('broken') ||
        lowerMessage.contains('crash') || lowerMessage.contains('freeze') ||
        lowerMessage.contains('slow') || lowerMessage.contains('stuck')) {
      return '🔧 If you\'re experiencing issues:\n\n1. Try closing and reopening the app\n2. Check your internet connection\n3. Make sure you\'re logged in\n4. If the problem persists, please contact the KITAB DOST support team\n\nWe\'re here to help!';
    }
    
    // Contact/Support - expanded
    if (lowerMessage.contains('contact') || lowerMessage.contains('support') || 
        lowerMessage.contains('email') || lowerMessage.contains('help desk') ||
        lowerMessage.contains('customer service') || lowerMessage.contains('get help') ||
        lowerMessage.contains('reach support')) {
      return '📧 For support and inquiries:\n\n• Check the app settings for contact information\n• Reach out through the KITAB DOST support channels\n• Make sure you\'re using the latest version of the app\n\nWe\'ll get back to you as soon as possible!';
    }
    
    // Help/How/What questions - expanded
    if (lowerMessage.contains('help') || lowerMessage.contains('how') || 
        lowerMessage.contains('what') || lowerMessage.contains('can i') ||
        lowerMessage.contains('how do i') || lowerMessage.contains('how can') ||
        lowerMessage.contains('what can') || lowerMessage.contains('what is') ||
        lowerMessage.contains('explain') || lowerMessage.contains('tell me') ||
        lowerMessage.contains('guide') || lowerMessage.contains('instructions')) {
      return '💡 I\'m here to help! Here are some things you can ask about:\n\n• How to post a book\n• How to borrow a book\n• How to find available books\n• How to chat with owners\n• Profile settings\n• Account management\n\nWhat would you like to know more about?';
    }
    
    // Questions about app features
    if (lowerMessage.contains('what can') || lowerMessage.contains('features') ||
        lowerMessage.contains('what does') || lowerMessage.contains('capabilities') ||
        lowerMessage.contains('functionality')) {
      return '📱 KITAB DOST features:\n\n• Browse and search for books\n• Post your books for others to borrow\n• Request to borrow books from other users\n• Chat with book owners\n• Manage your borrowings and postings\n• Track your reading history\n\nWhat would you like to know more about?';
    }
    
    // Default response - more helpful
    return '🤔 I understand you said: "$userMessage"\n\nI\'m a system assistant for KITAB DOST. I can help you with:\n\n• Finding available books - Try: "available books" or "find books"\n• How to borrow a book - Try: "borrow book" or "how to borrow"\n• How to post a book - Try: "post book" or "how to post"\n• Chat with owners - Try: "how to message" or "chat"\n• Profile settings - Try: "profile" or "settings"\n\nWhat would you like to know?';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size and define responsive breakpoints
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isSmallMobile, isMobile, isTablet),
            
            // Chat Messages
            Expanded(
              child: _buildMessageList(isSmallMobile, isMobile, isTablet),
            ),
            
            // Input Field
            _buildInputField(isSmallMobile, isMobile, isTablet),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(Message message) {
    print('Long press detected! Message: ${message.text}');
    print('Is system chat: ${widget.isSystemChat}');
    print('Message ID: ${message.messageId}');
    
    final reactions = ['❤️', '👍', '😂', '😮', '😢', '😡'];
    
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => _ReactionPickerDialog(
        reactions: reactions,
        currentReaction: message.reaction,
        onReactionSelected: (emoji) async {
          Navigator.pop(context);
          await _addReaction(message, emoji);
        },
      ),
    );
  }

  Future<void> _addReaction(Message message, String emoji) async {
    if (!widget.isSystemChat && message.messageId != null) {
      try {
        // Remove reaction if same emoji is clicked
        final newReaction = message.reaction == emoji ? null : emoji;
        
        await _messagesRef.child(message.messageId!).update({
          'reaction': newReaction,
        });
        
        setState(() {
          message.reaction = newReaction;
        });
      } catch (e) {
        print('Error adding reaction: $e');
      }
    }
  }

  Widget _buildHeader(bool isSmallMobile, bool isMobile, bool isTablet) {
    final horizontalPadding = isSmallMobile ? 12.0 : (isMobile ? 14.0 : 16.0);
    final verticalPadding = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    final backIconSize = isSmallMobile ? 22.0 : (isMobile ? 23.0 : 24.0);
    final avatarRadius = isSmallMobile ? 18.0 : (isMobile ? 19.0 : 20.0);
    final avatarIconSize = isSmallMobile ? 18.0 : (isMobile ? 19.0 : 20.0);
    final nameFontSize = isSmallMobile ? 16.0 : (isMobile ? 17.0 : (isTablet ? 18.0 : 20.0));
    final spacing = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    final moreIconSize = isSmallMobile ? 22.0 : (isMobile ? 23.0 : 24.0);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.secondary, size: backIconSize),
            onPressed: () {
              Navigator.pop(context);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: spacing),
          _isLoadingProfile && !widget.isSystemChat
              ? CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: Colors.blue.shade700,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: Colors.blue.shade700,
                  backgroundImage: _otherUserAvatar != null ? FileImage(_otherUserAvatar!) : null,
                  child: widget.isSystemChat
                      ? Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Image.asset(
                            'assets/app_logo.png',
                            fit: BoxFit.contain,
                          ),
                        )
                      : (_otherUserAvatar == null
                          ? Icon(Icons.person, color: Colors.white, size: avatarIconSize)
                          : null),
                ),
          SizedBox(width: spacing),
          Expanded(
            child: _isLoadingProfile && !widget.isSystemChat
                ? Container(
                    height: 20,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : Text(
                    _otherUserName.isNotEmpty ? _otherUserName : widget.chatName,
                    style: GoogleFonts.poppins(
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: AppColors.secondary, size: moreIconSize),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isSmallMobile, bool isMobile, bool isTablet) {
    final horizontalPadding = isSmallMobile ? 12.0 : (isMobile ? 14.0 : 16.0);
    final verticalPadding = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index], isSmallMobile, isMobile);
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isSmallMobile, bool isMobile) {
    final bubbleSpacing = isSmallMobile ? 12.0 : (isMobile ? 14.0 : 16.0);
    final avatarRadius = isSmallMobile ? 14.0 : (isMobile ? 15.0 : 16.0);
    final avatarIconSize = isSmallMobile ? 14.0 : (isMobile ? 15.0 : 16.0);
    final avatarSpacing = isSmallMobile ? 6.0 : (isMobile ? 7.0 : 8.0);
    final bubblePaddingH = isSmallMobile ? 12.0 : (isMobile ? 14.0 : 16.0);
    final bubblePaddingV = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    final bubbleRadius = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    final textFontSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : 15.0);
    final deliveredFontSize = isSmallMobile ? 10.0 : (isMobile ? 10.5 : 11.0);
    
    return Padding(
      padding: EdgeInsets.only(bottom: bubbleSpacing),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: Colors.blue.shade700,
              child: widget.isSystemChat
                  ? Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Image.asset(
                        'assets/app_logo.png',
                        fit: BoxFit.contain,
                      ),
                    )
                  : (_otherUserAvatar != null
                      ? ClipOval(
                          child: Image.file(
                            _otherUserAvatar!,
                            fit: BoxFit.cover,
                            width: avatarRadius * 2,
                            height: avatarRadius * 2,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.person, color: Colors.white, size: avatarIconSize);
                            },
                          ),
                        )
                      : Icon(Icons.person, color: Colors.white, size: avatarIconSize)),
            ),
            SizedBox(width: avatarSpacing),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: message.isUser ? () {
                    setState(() {
                      message.showDelivered = !message.showDelivered;
                    });
                  } : null,
                  onDoubleTap: () {
                    print('Double tap detected! Message: ${message.text}');
                    _showReactionPicker(message);
                  },
                  onLongPress: () {
                    print('Long press detected! Message: ${message.text}');
                    _showReactionPicker(message);
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: bubblePaddingH, vertical: bubblePaddingV),
                        decoration: BoxDecoration(
                          color: message.isUser
                              ? AppColors.secondary
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(bubbleRadius),
                            topRight: Radius.circular(bubbleRadius),
                            bottomLeft: Radius.circular(message.isUser ? bubbleRadius : 4),
                            bottomRight: Radius.circular(message.isUser ? 4 : bubbleRadius),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _buildMessageContent(message, textFontSize),
                      ),
                      if (message.reaction != null)
                        Positioned(
                          bottom: -8,
                          right: message.isUser ? 0 : null,
                          left: message.isUser ? null : 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              message.reaction!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (message.isUser && message.showDelivered) ...[
                  SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text(
                      'Delivered',
                      style: GoogleFonts.poppins(
                        fontSize: deliveredFontSize,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (message.isUser) ...[
            SizedBox(width: avatarSpacing),
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: avatarIconSize),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputField(bool isSmallMobile, bool isMobile, bool isTablet) {
    final horizontalPadding = isSmallMobile ? 12.0 : (isMobile ? 14.0 : 16.0);
    final verticalPadding = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    final inputRadius = isSmallMobile ? 22.0 : (isMobile ? 23.0 : 25.0);
    final inputFontSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : 15.0);
    final inputPaddingH = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    final inputPaddingV = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    final buttonSpacing = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    final buttonPadding = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    final sendIconSize = isSmallMobile ? 18.0 : (isMobile ? 19.0 : 20.0);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(inputRadius),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: inputFontSize,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: inputPaddingH,
                    vertical: inputPaddingV,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: buttonSpacing),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: EdgeInsets.all(buttonPadding),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.send,
                color: Colors.white,
                size: sendIconSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Message message, double fontSize) {
    final text = message.text;
    final urlPattern = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    final matches = urlPattern.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          color: message.isUser ? Colors.white : Colors.black87,
          height: 1.4,
        ),
      );
    }

    final children = <InlineSpan>[];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            color: message.isUser ? Colors.white : Colors.black87,
            height: 1.4,
          ),
        ));
      }

      final url = text.substring(match.start, match.end);
      children.add(TextSpan(
        text: url,
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          color: message.isUser ? Colors.white : Colors.blueAccent,
          decoration: TextDecoration.underline,
          height: 1.4,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      children.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          color: message.isUser ? Colors.white : Colors.black87,
          height: 1.4,
        ),
      ));
    }

    return Text.rich(TextSpan(children: children));
  }
}

// Animated Reaction Picker Dialog
class _ReactionPickerDialog extends StatefulWidget {
  final List<String> reactions;
  final String? currentReaction;
  final Function(String) onReactionSelected;

  const _ReactionPickerDialog({
    required this.reactions,
    required this.currentReaction,
    required this.onReactionSelected,
  });

  @override
  State<_ReactionPickerDialog> createState() => _ReactionPickerDialogState();
}

class _ReactionPickerDialogState extends State<_ReactionPickerDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late List<Animation<double>> _emojiAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Scale animation for the container
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    // Staggered bounce animations for each emoji
    _emojiAnimations = List.generate(
      widget.reactions.length,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.1,
            0.6 + (index * 0.1),
            curve: Curves.elasticOut,
          ),
        ),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    // Responsive breakpoints
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    
    // Responsive sizing - more aggressive for small screens
    final horizontalPadding = isSmallMobile ? 8.0 : (isMobile ? 10.0 : (isTablet ? 14.0 : 16.0));
    final verticalPadding = isSmallMobile ? 8.0 : (isMobile ? 9.0 : (isTablet ? 11.0 : 12.0));
    final borderRadius = isSmallMobile ? 25.0 : (isMobile ? 28.0 : (isTablet ? 32.0 : 35.0));
    
    // Calculate max width more conservatively
    final maxDialogWidth = isSmallMobile ? width * 0.92 : (isMobile ? width * 0.88 : width * 0.85);
    
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxDialogWidth,
            ),
            child: IntrinsicWidth(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.reactions.length,
                    (index) => _buildAnimatedEmoji(
                      widget.reactions[index],
                      _emojiAnimations[index],
                      index,
                      isSmallMobile,
                      isMobile,
                      isTablet,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedEmoji(
    String emoji,
    Animation<double> animation,
    int index,
    bool isSmallMobile,
    bool isMobile,
    bool isTablet,
  ) {
    final isSelected = widget.currentReaction == emoji;
    
    // Responsive sizing - reduced further for small screens
    final emojiSize = isSmallMobile ? 20.0 : (isMobile ? 24.0 : (isTablet ? 28.0 : 32.0));
    final emojiPadding = isSmallMobile ? 4.0 : (isMobile ? 6.0 : (isTablet ? 8.0 : 10.0));
    final emojiMargin = isSmallMobile ? 1.0 : (isMobile ? 2.0 : (isTablet ? 3.0 : 4.0));
    
    return ScaleTransition(
      scale: animation,
      child: GestureDetector(
        onTap: () {
          widget.onReactionSelected(emoji);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: emojiMargin),
          padding: EdgeInsets.all(emojiPadding),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.primary.withOpacity(0.15)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (value * 0.2),
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: emojiSize,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}