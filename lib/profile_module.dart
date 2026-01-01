import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'homepage_module' show HomeScreen;
import 'favorite_module.dart' show FavoritesScreen;
import 'chat_module.dart' show ChatsScreen;
import 'my-postings_module.dart' show PostingsScreen;
import 'about_us.dart' show AboutBookNestScreen;
import 'logout_module.dart';
import 'delete-account_module.dart';
import 'edit-profile_module.dart' show ProfileLoginScreen;
import 'profile_settings_module.dart' show ProfileSettingsScreen;

// Note: main() is in main.dart, not here
// This module provides the ProfileScreen UI

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;
  
  const ProfileScreen({Key? key, this.showBackButton = false}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  int selectedNavIndex = 3; // Profile is at index 3
  late List<AnimationController> _iconAnimationControllers;
  String userName = 'User'; // Default username
  String userBio = ''; // User bio
  File? _avatarImage; // Store selected avatar image
  final ImagePicker _imagePicker = ImagePicker();
  int _unreadCount = 0;
  String _userRole = 'user'; // Default role

  // Helper function for Poppins text style
  TextStyle poppinsStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.black,
    double? height,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserName(); // Load username from Firebase
    _loadUserBio(); // Load user bio from Firebase
    _loadSavedAvatar(); // Load saved avatar
    _loadUserRole(); // Load user role
    _loadUnreadCount(); // Load unread message count
    _iconAnimationControllers = List.generate(
      4,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );
    _iconAnimationControllers[3].forward(); // Profile icon is active
  }

  void _loadUserRole() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseDatabase.instance.ref('users/${user.uid}/role').get().then((snapshot) {
        if (snapshot.exists && snapshot.value != null) {
          if (mounted) {
            setState(() {
              _userRole = snapshot.value.toString();
            });
            print('DEBUG: Loaded user role: $_userRole');
          }
        }
      });
    }
  }

  void _loadUserName() {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        setState(() {
          userName = user.displayName!;
        });
        print('DEBUG: Loaded profile username from Firebase Auth: $userName');
      } else {
        print('DEBUG: No displayName in Auth (profile), will fetch from Realtime Database asynchronously');
        
        Future.microtask(() async {
          try {
            final userRef = FirebaseDatabase.instance.ref('users/${user.uid}/username');
            final snapshot = await userRef
                .get()
                .timeout(const Duration(seconds: 5), onTimeout: () {
              print('DEBUG: Realtime Database fetch timed out (profile)');
              throw TimeoutException('Realtime Database timeout', const Duration(seconds: 5));
            });

            if (snapshot.exists && snapshot.value != null) {
              if (mounted) {
                setState(() {
                  userName = snapshot.value.toString();
                });
                print('DEBUG: Loaded profile username from Realtime Database: $userName');
              }
            } else {
              print('DEBUG: No username in Realtime Database (profile), using default "User"');
            }
          } catch (error) {
            print('DEBUG: Error fetching from Realtime Database (profile): $error');
          }
        });
      }
    } else {
      print('DEBUG: No user logged in (profile), using default "User"');
    }
  }

  void _loadUserBio() {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      Future.microtask(() async {
        try {
          final bioRef = FirebaseDatabase.instance.ref('users/${user.uid}/bio');
          final snapshot = await bioRef
              .get()
              .timeout(const Duration(seconds: 5), onTimeout: () {
            print('DEBUG: Bio fetch timed out');
            throw TimeoutException('Bio fetch timeout', const Duration(seconds: 5));
          });

          if (snapshot.exists && snapshot.value != null) {
            if (mounted) {
              setState(() {
                userBio = snapshot.value.toString();
              });
              print('DEBUG: Loaded user bio from Firebase: $userBio');
            }
          } else {
            print('DEBUG: No bio found in database');
          }
        } catch (error) {
          print('DEBUG: Error fetching bio from database: $error');
        }
      });
    } else {
      print('DEBUG: No user logged in, cannot load bio');
    }
  }

  Future<void> _pickAvatar() async {
    try {
      print('DEBUG: Opening image picker...');
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Choose Avatar Source'),
            content: const Text('Select where to pick your avatar from:'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
                child: const Text('Gallery'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
                child: const Text('Camera'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('DEBUG: Error in _pickAvatar: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      print('DEBUG: Picking image from gallery...');
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      
      if (pickedFile != null) {
        _updateAvatarImage(pickedFile);
      } else {
        print('DEBUG: User cancelled gallery picker');
      }
    } catch (e) {
      print('DEBUG: Gallery picker error: $e');
      _showErrorMessage('Gallery Error: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      print('DEBUG: Picking image from camera...');
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      
      if (pickedFile != null) {
        _updateAvatarImage(pickedFile);
      } else {
        print('DEBUG: User cancelled camera picker');
      }
    } catch (e) {
      print('DEBUG: Camera picker error: $e');
      _showErrorMessage('Camera Error: $e');
    }
  }

  void _updateAvatarImage(XFile pickedFile) {
    print('DEBUG: Avatar image selected: ${pickedFile.path}');
    final File imageFile = File(pickedFile.path);
    
    setState(() {
      _avatarImage = imageFile;
    });
    
    // Save avatar path to local storage
    _saveAvatarPath(imageFile.path);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar updated successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveAvatarPath(String imagePath) async {
    try {
      print('DEBUG: Starting to save avatar from: $imagePath');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('DEBUG: No user logged in, cannot save avatar');
        return;
      }
      
      final sourceFile = File(imagePath);
      final sourceExists = await sourceFile.exists();
      print('DEBUG: Source file exists: $sourceExists');
      
      if (!sourceExists) {
        print('DEBUG: Source file does not exist, cannot save');
        return;
      }
      
      // Save avatar as base64 to Firebase Database
      try {
        print('DEBUG: Saving avatar to Firebase Database...');
        final bytes = await sourceFile.readAsBytes();
        print('DEBUG: Read ${bytes.length} bytes from source file');
        
        final base64String = base64Encode(bytes);
        print('DEBUG: Converted to base64, length: ${base64String.length}');
        
        // Save to Realtime Database
        await FirebaseDatabase.instance
            .ref('users/${user.uid}')
            .update({'avatar': base64String});
        print('DEBUG: Avatar saved to Firebase Database');
        
        // Also save to SharedPreferences for offline access
        final prefs = await SharedPreferences.getInstance();
        final avatarKey = 'avatar_base64_${user.uid}';
        await prefs.setString(avatarKey, base64String);
        
        final retrievedBase64 = prefs.getString(avatarKey);
        print('DEBUG: Avatar base64 saved for user ${user.uid}, retrieved length: ${retrievedBase64?.length ?? 0}');
      } catch (uploadError) {
        print('DEBUG: Error saving to Firebase Database: $uploadError');
      }
      
    } catch (e) {
      print('DEBUG: Error saving avatar path: $e');
      print('DEBUG: Stack trace: ${e.toString()}');
    }
  }

  Future<void> _loadSavedAvatar() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('DEBUG: No user logged in, cannot load avatar');
        return;
      }
      
      // Load avatar from Firebase Database (base64)
      try {
        final snapshot = await FirebaseDatabase.instance
            .ref('users/${user.uid}/avatar')
            .once();
        
        if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
          final avatarBase64 = snapshot.snapshot.value as String;
          if (avatarBase64.isNotEmpty) {
            print('DEBUG: Found avatar in Firebase Database');
            // Decode base64 and create temporary file
            final bytes = base64Decode(avatarBase64);
            final tempDir = await Directory.systemTemp.createTemp('flutter_avatar');
            final avatarFile = File('${tempDir.path}/avatar.png');
            await avatarFile.writeAsBytes(bytes);
            
            // Also save to SharedPreferences for offline access
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('avatar_base64_${user.uid}', avatarBase64);
            
            if (mounted) {
              setState(() {
                _avatarImage = avatarFile;
              });
              print('DEBUG: Loaded avatar from Firebase Database');
            }
            return;
          }
        }
      } catch (e) {
        print('DEBUG: Error loading from Firebase Database: $e');
      }
      
      // Fallback to local SharedPreferences (for backward compatibility)
      final prefs = await SharedPreferences.getInstance();
      final avatarKey = 'avatar_base64_${user.uid}';
      final base64String = prefs.getString(avatarKey);
      print('DEBUG: Loading avatar for user ${user.uid}, base64 from preferences, length: ${base64String?.length ?? 0}');
      
      if (base64String != null && base64String.isNotEmpty) {
        try {
          final bytes = base64Decode(base64String);
          print('DEBUG: Decoded base64 to ${bytes.length} bytes');
          
          final tempDir = await Directory.systemTemp.createTemp('flutter_avatar');
          final avatarFile = File('${tempDir.path}/avatar.png');
          await avatarFile.writeAsBytes(bytes);
          
          if (mounted) {
            setState(() {
              _avatarImage = avatarFile;
            });
            print('DEBUG: Loaded saved avatar from local storage');
          }
        } catch (decodeError) {
          print('DEBUG: Error decoding base64: $decodeError');
        }
      } else {
        print('DEBUG: No saved avatar found');
      }
    } catch (e) {
      print('DEBUG: Error loading saved avatar: $e');
      print('DEBUG: Stack trace: ${e.toString()}');
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
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
    
    // Responsive sizing variables
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : (isTablet ? 28.0 : 36.0));
    final verticalPadding = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    final avatarSize = isSmallMobile ? 100.0 : (isMobile ? 110.0 : (isTablet ? 120.0 : 140.0));
    final cameraIconSize = isSmallMobile ? 32.0 : (isMobile ? 34.0 : 36.0);
    final cameraIconInner = isSmallMobile ? 16.0 : (isMobile ? 17.0 : 18.0);
    final emojiSize = isSmallMobile ? 50.0 : (isMobile ? 55.0 : 60.0);
    final nameSpacing = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    final nameFontSize = isSmallMobile ? 22.0 : (isMobile ? 24.0 : (isTablet ? 26.0 : 30.0));
    final menuSpacing = isSmallMobile ? 28.0 : (isMobile ? 32.0 : 36.0);
    final containerPadding = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    final containerSpacing = isSmallMobile ? 24.0 : (isMobile ? 28.0 : 32.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Column(
              children: [
                // Back Button (only show when showBackButton is true)
                if (widget.showBackButton) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: EdgeInsets.all(isSmallMobile ? 8 : (isMobile ? 9 : 10)),
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: isSmallMobile ? 20 : (isMobile ? 22 : 24),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallMobile ? 16 : (isMobile ? 20 : 24)),
                ],

                // Profile Avatar
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5DA3FA),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Avatar image or emoji
                        if (_avatarImage != null)
                          ClipOval(
                            child: Image.file(
                              _avatarImage!,
                              fit: BoxFit.cover,
                              width: avatarSize,
                              height: avatarSize,
                            ),
                          )
                        else
                          Text(
                            '👤',
                            style: TextStyle(fontSize: emojiSize),
                          ),
                        // Camera icon overlay
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: cameraIconSize,
                            height: cameraIconSize,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: cameraIconInner,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: nameSpacing),
                
                // Name
                Text(
                  userName,
                  style: poppinsStyle(
                    fontSize: nameFontSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Bio (if exists)
                if (userBio.isNotEmpty) ...[
                  SizedBox(height: isSmallMobile ? 8 : 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 24 : 32),
                    child: Text(
                      userBio,
                      style: poppinsStyle(
                        fontSize: isSmallMobile ? 12 : 13,
                        color: Colors.grey[600]!,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                
                SizedBox(height: menuSpacing),
                
                // Menu Items Container
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: 500),
                  padding: EdgeInsets.all(containerPadding),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons.person_outline,
                        title: 'Edit Profile',
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileLoginScreen(),
                            ),
                          );
                          // Reload profile if changes were made
                          if (result == true) {
                            _loadUserName(); // Reload username
                            _loadSavedAvatar(); // Reload avatar
                          }
                        },
                        isSmallMobile: isSmallMobile,
                        isMobile: isMobile,
                      ),
                      const Divider(height: 30),
                      _buildMenuItem(
                        icon: Icons.settings_outlined,
                        title: 'Profile & Settings',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileSettingsScreen(),
                            ),
                          );
                          // Reload bio when returning from settings
                          _loadUserBio();
                        },
                        isSmallMobile: isSmallMobile,
                        isMobile: isMobile,
                      ),
                      const Divider(height: 30),
                      _buildMenuItem(
                        icon: Icons.access_time,
                        title: _userRole == 'admin' ? 'Posting & Requests' : 'My Borrowings',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PostingsScreen(),
                            ),
                          );
                        },
                        isSmallMobile: isSmallMobile,
                        isMobile: isMobile,
                      ),
                      const Divider(height: 30),
                      _buildMenuItem(
                        icon: Icons.info_outline,
                        title: 'About KITAB DOST',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AboutBookNestScreen(),
                            ),
                          );
                        },
                        isSmallMobile: isSmallMobile,
                        isMobile: isMobile,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: containerSpacing),
                
                // Logout and Delete Container
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: 500),
                  padding: EdgeInsets.all(containerPadding),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons.logout,
                        title: 'Log Out',
                        onTap: () {
                          LogoutModule.showLogoutDialog(context);
                        },
                        isSmallMobile: isSmallMobile,
                        isMobile: isMobile,
                      ),
                      const Divider(height: 30),
                      _buildMenuItem(
                        icon: Icons.delete_outline,
                        title: 'Delete Account',
                        onTap: () {
                          DeleteAccountModule.showDeleteAccountDialog(context);
                        },
                        isSmallMobile: isSmallMobile,
                        isMobile: isMobile,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _loadUnreadCount() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Listen to chats for unread count
    FirebaseDatabase.instance.ref('chats').onValue.listen((event) {
      final data = event.snapshot.value;
      int count = 0;
      
      if (data != null && data is Map) {
        data.forEach((chatId, chatData) {
          if (chatData is Map && chatData['participants'] != null) {
            final participants = chatData['participants'] as Map;
            // Only count chats where current user is a participant
            if (participants[currentUser.uid] == true) {
              // Check if current user has unread messages
              final readStatus = chatData['readBy'] as Map?;
              final isUnread = readStatus == null || readStatus[currentUser.uid] != true;
              if (isUnread) {
                count++;
              }
            }
          }
        });
      }
      
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    });
  }

  Widget _buildAnimatedIcon(IconData outlinedIcon, IconData filledIcon, int index, double iconSize) {
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
  
  Widget _buildAnimatedIconWithBadge(IconData outlinedIcon, IconData filledIcon, int index, double iconSize, int badgeCount) {
    final badgeSize = iconSize * 0.55;
    final badgeFontSize = iconSize * 0.35;
    
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isSmallMobile,
    required bool isMobile,
  }) {
    final iconContainerPadding = isSmallMobile ? 6.0 : (isMobile ? 7.0 : 8.0);
    final iconSize = isSmallMobile ? 24.0 : (isMobile ? 26.0 : 28.0);
    final iconTextSpacing = isSmallMobile ? 15.0 : (isMobile ? 17.0 : 20.0);
    final textFontSize = isSmallMobile ? 15.0 : (isMobile ? 16.0 : 17.0);
    final verticalPadding = isSmallMobile ? 6.0 : (isMobile ? 7.0 : 8.0);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(iconContainerPadding),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppColors.secondary,
                size: iconSize,
              ),
            ),
            SizedBox(width: iconTextSpacing),
            Expanded(
              child: Text(
                title,
                style: poppinsStyle(
                  fontSize: textFontSize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}