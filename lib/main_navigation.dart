import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'homepage_module' show HomeScreen;
import 'favorite_module.dart' show FavoritesScreen;
import 'chat_module.dart' show ChatsScreen;
import 'profile_module.dart' show ProfileScreen;
import 'theme/app_colors.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  
  const MainNavigation({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with TickerProviderStateMixin {
  late int _currentIndex;
  late List<AnimationController> _iconAnimationControllers;
  int _unreadCount = 0;
  
  List<Widget> get _screens => [
    HomeScreen(
      onNavigationChange: (index) {
        setState(() {
          _iconAnimationControllers[_currentIndex].reverse();
          _currentIndex = index;
          _iconAnimationControllers[index].forward();
        });
      },
    ),
    const FavoritesScreen(),
    const ChatsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _iconAnimationControllers = List.generate(
      4,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );
    _iconAnimationControllers[_currentIndex].forward();
    _loadUnreadCount();
  }
  
  void _loadUnreadCount() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    FirebaseDatabase.instance.ref('chats').onValue.listen((event) {
      final data = event.snapshot.value;
      int count = 0;
      
      if (data != null && data is Map) {
        data.forEach((chatId, chatData) {
          if (chatData is Map && chatData['participants'] != null) {
            final participants = chatData['participants'] as Map;
            if (participants[currentUser.uid] == true) {
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
    
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final navIconSize = isSmallMobile ? 28.0 : (isMobile ? 30.0 : 32.0);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _iconAnimationControllers[_currentIndex].reverse();
              _currentIndex = index;
              _iconAnimationControllers[index].forward();
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.secondary,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(
                Icons.home_rounded,
                Icons.home_rounded,
                0,
                navIconSize,
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(
                Icons.menu_book_rounded,
                Icons.menu_book_rounded,
                1,
                navIconSize,
              ),
              label: 'Bookmarks',
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedIconWithBadge(
                Icons.chat_bubble_rounded,
                Icons.chat_bubble_rounded,
                2,
                navIconSize,
                _unreadCount,
              ),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(
                Icons.person_rounded,
                Icons.person_rounded,
                3,
                navIconSize,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon(IconData outlinedIcon, IconData filledIcon, int index, double iconSize) {
    return AnimatedBuilder(
      animation: _iconAnimationControllers[index],
      builder: (context, child) {
        final animation = _iconAnimationControllers[index];
        final isSelected = _currentIndex == index;
        
        final scaleValue = isSelected 
            ? 1.0 + (Curves.elasticOut.transform(animation.value) * 0.25)
            : 1.0 - (animation.value * 0.1);
        
        final rotationValue = isSelected
            ? (Curves.easeOutBack.transform(animation.value) * 0.1) - 0.05
            : 0.0;
        
        return Transform.rotate(
          angle: rotationValue,
          child: Transform.scale(
            scale: scaleValue,
            child: Icon(
              _currentIndex == index ? filledIcon : outlinedIcon,
              size: iconSize,
              color: _currentIndex == index
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
            final isSelected = _currentIndex == index;
            
            final scaleValue = isSelected 
                ? 1.0 + (Curves.elasticOut.transform(animation.value) * 0.25)
                : 1.0 - (animation.value * 0.1);
            
            final rotationValue = isSelected
                ? (Curves.easeOutBack.transform(animation.value) * 0.1) - 0.05
                : 0.0;
            
            return Transform.rotate(
              angle: rotationValue,
              child: Transform.scale(
                scale: scaleValue,
                child: Icon(
                  _currentIndex == index ? filledIcon : outlinedIcon,
                  size: iconSize,
                  color: _currentIndex == index
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: badgeFontSize,
                    fontWeight: FontWeight.bold,
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
