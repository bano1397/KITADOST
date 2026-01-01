import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'message_module.dart' show ChatScreen;
import 'homepage_module' show HomeScreen;
import 'favorite_module.dart' show FavoritesScreen;
import 'profile_module.dart' show ProfileScreen;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const ChatsScreen(),
    );
  }
}

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<ChatItem> _filteredChats = [];
  List<ChatItem> _allChats = [];
  int selectedNavIndex = 2; // Messages tab selected by default
  late List<AnimationController> _iconAnimationControllers;
  int _unreadCount = 0;
  
  @override
  void initState() {
    super.initState();
    _iconAnimationControllers = List.generate(
      4,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );
    _iconAnimationControllers[2].forward(); // Messages icon selected by default
    _loadChats();
  }
  
  void _loadChats() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Show only system chat if not logged in
      setState(() {
        _allChats = [
          ChatItem(
            name: 'From System',
            message: 'Welcome to KITAB DOST…',
            avatarColor: Colors.blue.shade700,
            initials: 'SY',
            isSystemChat: true,
            chatId: 'system',
          ),
        ];
        _filteredChats = _allChats;
      });
      return;
    }
    
    // Load chats from Firebase
    FirebaseDatabase.instance.ref('chats').onValue.listen((event) async {
      final data = event.snapshot.value;
      List<ChatItem> loadedChats = [
        ChatItem(
          name: 'From System',
          message: 'Welcome to KITAB DOST…',
          avatarColor: Colors.blue.shade700,
          initials: 'SY',
          isSystemChat: true,
          chatId: 'system',
        ),
      ];
      
      if (data != null && data is Map) {
        final prefs = await SharedPreferences.getInstance();
        
        for (var entry in data.entries) {
          final chatId = entry.key;
          final chatData = entry.value;
          
          if (chatData is Map && chatData['participants'] != null) {
            final participants = chatData['participants'] as Map;
            // Only show chats where current user is a participant
            if (participants[currentUser.uid] == true) {
              // Get the other participant's ID and fetch their current profile
              String otherUserName = 'User';
              String? otherUserId;
              File? otherUserAvatar;
              
              participants.forEach((uid, _) {
                if (uid != currentUser.uid) {
                  otherUserId = uid;
                }
              });
              
              // Fetch current username from Firebase
              if (otherUserId != null) {
                try {
                  final userSnapshot = await FirebaseDatabase.instance
                      .ref('users/$otherUserId')
                      .once();
                  
                  if (userSnapshot.snapshot.value != null) {
                    final userData = userSnapshot.snapshot.value as Map<dynamic, dynamic>;
                    otherUserName = userData['username'] ?? 'User';
                  }
                  
                  // Load avatar from Firebase Database first
                  try {
                    final avatarSnapshot = await FirebaseDatabase.instance
                        .ref('users/$otherUserId/avatar')
                        .once();
                    
                    if (avatarSnapshot.snapshot.exists && avatarSnapshot.snapshot.value != null) {
                      final avatarBase64 = avatarSnapshot.snapshot.value as String;
                      if (avatarBase64.isNotEmpty) {
                        final bytes = base64Decode(avatarBase64);
                        final tempDir = Directory.systemTemp;
                        final file = File('${tempDir.path}/chat_list_avatar_$otherUserId.png');
                        await file.writeAsBytes(bytes);
                        otherUserAvatar = file;
                        
                        // Cache it
                        await prefs.setString('avatar_base64_$otherUserId', avatarBase64);
                      }
                    } else {
                      // Fallback to cached avatar
                      final avatarBase64 = prefs.getString('avatar_base64_$otherUserId');
                      if (avatarBase64 != null && avatarBase64.isNotEmpty) {
                        final bytes = base64Decode(avatarBase64);
                        final tempDir = Directory.systemTemp;
                        final file = File('${tempDir.path}/chat_list_avatar_$otherUserId.png');
                        await file.writeAsBytes(bytes);
                        otherUserAvatar = file;
                      }
                    }
                  } catch (e) {
                    print('Error loading avatar for chat list: $e');
                  }
                } catch (e) {
                  print('Error fetching user profile: $e');
                }
              }
              
              // Check if current user has unread messages
              final readStatus = chatData['readBy'] as Map?;
              final isUnread = readStatus == null || readStatus[currentUser.uid] != true;
              
              loadedChats.add(ChatItem(
                name: otherUserName,
                message: chatData['lastMessage'] ?? 'No messages yet',
                avatarColor: _generateColorFromString(otherUserName),
                initials: _getInitials(otherUserName),
                isSystemChat: false,
                isUnread: isUnread,
                chatId: chatId,
                otherUserId: otherUserId,
                avatarFile: otherUserAvatar,
              ));
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _allChats = loadedChats;
          _filteredChats = _allChats;
          // Count unread messages (excluding system chat)
          _unreadCount = _allChats.where((chat) => !chat.isSystemChat && chat.isUnread).length;
        });
      }
    });
  }
  
  Color _generateColorFromString(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor();
  }
  
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  void _filterChats(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredChats = _allChats;
      } else {
        _filteredChats = _allChats.where((chat) {
          return chat.name.toLowerCase().contains(query.toLowerCase()) ||
              chat.message.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var controller in _iconAnimationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    // Responsive breakpoints
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    
    // Responsive sizing
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : (isTablet ? 32.0 : 40.0));
    final titleFontSize = isSmallMobile ? 28.0 : (isMobile ? 32.0 : (isTablet ? 36.0 : 40.0));
    final searchFontSize = isSmallMobile ? 14.0 : (isMobile ? 16.0 : 18.0);
    final searchIconSize = isSmallMobile ? 20.0 : (isMobile ? 24.0 : 28.0);
    final verticalPadding = isSmallMobile ? 12.0 : (isMobile ? 16.0 : 20.0);
    final spacing = isSmallMobile ? 16.0 : (isMobile ? 20.0 : 24.0);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Text(
                'Chats',
                style: GoogleFonts.poppins(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
            ),
            
            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterChats,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey.shade400,
                      fontSize: searchFontSize,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey.shade400,
                      size: searchIconSize,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 24,
                      vertical: verticalPadding,
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: spacing),
            
            // Chat List
            Expanded(
              child: _filteredChats.isEmpty
                  ? Center(
                      child: Text(
                        'No chats found',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade500,
                          fontSize: searchFontSize,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredChats.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final chat = _filteredChats[index];
                        return ChatTile(
                          chat: chat,
                          isSmallMobile: isSmallMobile,
                          isMobile: isMobile,
                          horizontalPadding: horizontalPadding,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon(IconData outlinedIcon, IconData filledIcon, int index, bool isSmallMobile, bool isMobile) {
    // Responsive icon size
    final iconSize = isSmallMobile ? 28.0 : (isMobile ? 32.0 : 36.0);
    
    return AnimatedBuilder(
      animation: _iconAnimationControllers[index],
      builder: (context, child) {
        final animation = _iconAnimationControllers[index];
        final isSelected = selectedNavIndex == index;
        
        // Elastic bounce curve for scale
        final scaleValue = isSelected 
            ? 1.0 + (Curves.elasticOut.transform(animation.value) * 0.25)
            : 1.0 - (animation.value * 0.1);
        
        // Subtle rotation for dynamic effect
        final rotationValue = isSelected
            ? (Curves.easeOutBack.transform(animation.value) * 0.1) - 0.05
            : 0.0;
        
        return Transform.rotate(
          angle: rotationValue,
          child: Transform.scale(
            scale: scaleValue,
            child: Icon(
              selectedNavIndex == index ? filledIcon : outlinedIcon,
              size: iconSize,
              color: selectedNavIndex == index
                  ? AppColors.primary
                  : AppColors.secondary,
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildAnimatedIconWithBadge(IconData outlinedIcon, IconData filledIcon, int index, bool isSmallMobile, bool isMobile, int badgeCount) {
    // Responsive sizes
    final iconSize = isSmallMobile ? 28.0 : (isMobile ? 32.0 : 36.0);
    final badgeSize = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    final badgeFontSize = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _iconAnimationControllers[index],
          builder: (context, child) {
            final animation = _iconAnimationControllers[index];
            final isSelected = selectedNavIndex == index;
            
            // Elastic bounce curve for scale
            final scaleValue = isSelected 
                ? 1.0 + (Curves.elasticOut.transform(animation.value) * 0.25)
                : 1.0 - (animation.value * 0.1);
            
            // Subtle rotation for dynamic effect
            final rotationValue = isSelected
                ? (Curves.easeOutBack.transform(animation.value) * 0.1) - 0.05
                : 0.0;
            
            return Transform.rotate(
              angle: rotationValue,
              child: Transform.scale(
                scale: scaleValue,
                child: Icon(
                  selectedNavIndex == index ? filledIcon : outlinedIcon,
                  size: iconSize,
                  color: selectedNavIndex == index
                      ? AppColors.primary
                      : AppColors.secondary,
                ),
              ),
            );
          },
        ),
        if (badgeCount > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: EdgeInsets.all(badgeCount > 9 ? 2 : 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
              constraints: BoxConstraints(
                minWidth: badgeSize,
                minHeight: badgeSize,
              ),
              child: Center(
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: badgeFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ChatTile extends StatelessWidget {
  final ChatItem chat;
  final bool isSmallMobile;
  final bool isMobile;
  final double horizontalPadding;

  const ChatTile({
    Key? key,
    required this.chat,
    required this.isSmallMobile,
    required this.isMobile,
    required this.horizontalPadding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Responsive sizing for chat tile
    final avatarRadius = isSmallMobile ? 28.0 : (isMobile ? 32.0 : 36.0);
    final avatarSize = avatarRadius * 2;
    final avatarSpacing = isSmallMobile ? 12.0 : (isMobile ? 16.0 : 20.0);
    final verticalPadding = isSmallMobile ? 12.0 : (isMobile ? 16.0 : 20.0);
    final nameFontSize = isSmallMobile ? 15.0 : (isMobile ? 17.0 : 19.0);
    final messageFontSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : 16.0);
    final initialsFontSize = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    final unreadDotSize = isSmallMobile ? 10.0 : (isMobile ? 10.0 : 12.0);
    final dividerLeftPadding = avatarSize + avatarSpacing + horizontalPadding;
    
    return Column(
      children: [
        InkWell(
          onTap: () async {
            // Mark as read in Firebase before navigating
            if (!chat.isSystemChat && chat.chatId != 'system') {
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null) {
                await FirebaseDatabase.instance
                    .ref('chats/${chat.chatId}/readBy/${currentUser.uid}')
                    .set(true);
              }
            }
            
            // Navigate to message module
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: chat.chatId,
                  chatName: chat.name,
                  isSystemChat: chat.isSystemChat,
                  otherUserId: chat.otherUserId,
                ),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: chat.avatarColor,
                  backgroundImage: chat.avatarFile != null ? FileImage(chat.avatarFile!) : null,
                  child: chat.isSystemChat
                      ? Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Image.asset(
                            'assets/app_logo.png',
                            fit: BoxFit.contain,
                          ),
                        )
                      : (chat.avatarFile == null
                          ? Text(
                              chat.initials,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: initialsFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null),
                ),
                SizedBox(width: avatarSpacing),
                // Chat Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.name,
                              style: GoogleFonts.poppins(
                                fontSize: nameFontSize,
                                fontWeight: chat.isUnread ? FontWeight.w700 : FontWeight.w600,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chat.isUnread)
                            Container(
                              width: unreadDotSize,
                              height: unreadDotSize,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: isSmallMobile ? 3 : 4),
                      Text(
                        chat.message,
                        style: GoogleFonts.poppins(
                          fontSize: messageFontSize,
                          fontWeight: chat.isUnread ? FontWeight.w500 : FontWeight.w400,
                          color: chat.isUnread ? Colors.black87 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Divider
        Padding(
          padding: EdgeInsets.only(
            left: dividerLeftPadding,
            right: horizontalPadding,
          ),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ],
    );
  }
}

class ChatItem {
  final String name;
  final String message;
  final Color avatarColor;
  final String initials;
  final bool isSystemChat;
  final String chatId;
  final String? otherUserId;
  final File? avatarFile;
  bool isUnread;

  ChatItem({
    required this.name,
    required this.message,
    required this.avatarColor,
    required this.initials,
    required this.chatId,
    this.otherUserId,
    this.avatarFile,
    this.isSystemChat = false,
    this.isUnread = true,
  });
}
