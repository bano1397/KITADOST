import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'homepage_module' show HomeScreen;
import 'chat_module.dart' show ChatsScreen;
import 'profile_module.dart' show ProfileScreen;
import 'book-detail-screen_module.dart' show BookDetailScreen;
import 'error_handler_module.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Favorites',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        primarySwatch: Colors.blue,
      ),
      home: const FavoritesScreen(),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with TickerProviderStateMixin {
  String selectedCategory = 'All';
  final List<String> categories = ['All', 'Education', 'Fiction', 'Non - Fiction', 'Mystery'];
  int selectedNavIndex = 1; // Bookmarks tab selected by default
  late List<AnimationController> _iconAnimationControllers;
  
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;
  int _unreadCount = 0;
  
  // Store book IDs to listen for book changes
  Set<String> _favoriteBookIds = {};

  List<Map<String, dynamic>> get filteredFavorites {
    if (selectedCategory == 'All') {
      return _favorites;
    }
    return _favorites.where((book) => book['genre'] == selectedCategory).toList();
  }

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
    _iconAnimationControllers[1].forward(); // Bookmarks icon selected by default
    _loadFavorites();
    _loadUnreadCount();
    _listenToBookChanges();
  }

  Future<void> _refreshFavorites() async {
    try {
      _loadFavorites();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context: context,
          message: 'Failed to refresh favorites',
          onRetry: _refreshFavorites,
        );
      }
    }
  }

  void _loadFavorites() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Listen to real-time changes in favorites
    FirebaseDatabase.instance
        .ref('favorites/${user.uid}')
        .onValue
        .listen((event) async {
      try {
        final snapshot = event.snapshot;

        if (snapshot.exists) {
          final data = snapshot.value as Map?;
          if (data != null) {
            final List<Map<String, dynamic>> loadedFavorites = [];
            
            // Get bookIds from favorites
            final List<String> bookIds = [];
            final Map<String, dynamic> favoriteTimestamps = {};
            
            data.forEach((key, value) {
              bookIds.add(key);
              if (value is Map && value.containsKey('addedAt')) {
                favoriteTimestamps[key] = value['addedAt'];
              }
            });

            // Fetch actual book data from books database
            for (String bookId in bookIds) {
              try {
                final bookSnapshot = await FirebaseDatabase.instance
                    .ref('books/$bookId')
                    .get();
                
                if (bookSnapshot.exists && bookSnapshot.value != null) {
                  final bookData = Map<String, dynamic>.from(bookSnapshot.value as Map);
                  bookData['id'] = bookId;
                  bookData['addedAt'] = favoriteTimestamps[bookId] ?? 0;
                  loadedFavorites.add(bookData);
                } else {
                  // Book no longer exists, remove from favorites
                  print('DEBUG: Book $bookId no longer exists, removing from favorites');
                  await FirebaseDatabase.instance
                      .ref('favorites/${user.uid}/$bookId')
                      .remove();
                }
              } catch (e) {
                print('Error loading book $bookId: $e');
              }
            }

            // Sort by addedAt timestamp (newest first)
            loadedFavorites.sort((a, b) {
              final aTime = a['addedAt'] ?? 0;
              final bTime = b['addedAt'] ?? 0;
              return bTime.compareTo(aTime);
            });

            if (mounted) {
              setState(() {
                _favorites = loadedFavorites;
                _favoriteBookIds = bookIds.toSet();
                _isLoading = false;
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _favorites = [];
              _favoriteBookIds = {};
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        print('Error loading favorites: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  void _listenToBookChanges() {
    // Listen to changes in the books database to refresh favorites when books are edited
    FirebaseDatabase.instance
        .ref('books')
        .onValue
        .listen((event) {
      // When any book changes, reload favorites to get updated data
      if (_favoriteBookIds.isNotEmpty && mounted) {
        _loadFavorites();
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
    
    // Responsive breakpoints
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isSmallMobile, isMobile, isTablet),
            _buildCategoryTabs(isSmallMobile, isMobile),
            Expanded(
              child: _buildContent(isSmallMobile, isMobile, isTablet),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build image widget that handles both Firebase Storage URLs and base64
  Widget _buildBookImage(String? imageUrl, {required double iconSize}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        child: Icon(Icons.book, size: iconSize, color: Colors.grey),
      );
    }

    final isUrl = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    
    if (isUrl) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade300,
            child: Icon(Icons.book, size: iconSize, color: Colors.grey),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    } else {
      try {
        return Image.memory(
          base64Decode(imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade300,
              child: Icon(Icons.book, size: iconSize, color: Colors.grey),
            );
          },
        );
      } catch (e) {
        return Container(
          color: Colors.grey.shade300,
          child: Icon(Icons.book, size: iconSize, color: Colors.grey),
        );
      }
    }
  }

  Widget _buildHeader(bool isSmallMobile, bool isMobile, bool isTablet) {
    // Responsive sizing
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : (isTablet ? 32.0 : 40.0));
    final verticalPadding = isSmallMobile ? 12.0 : (isMobile ? 16.0 : 20.0);
    final titleFontSize = isSmallMobile ? 28.0 : (isMobile ? 32.0 : (isTablet ? 36.0 : 40.0));
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Text(
        'Favorites',
        style: GoogleFonts.poppins(
          fontSize: titleFontSize,
          fontWeight: FontWeight.bold,
          color: AppColors.secondary,
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(bool isSmallMobile, bool isMobile) {
    // Responsive sizing
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : 24.0);
    final tabHeight = isSmallMobile ? 45.0 : (isMobile ? 50.0 : 55.0);
    final tabPaddingH = isSmallMobile ? 20.0 : (isMobile ? 24.0 : 28.0);
    final tabPaddingV = isSmallMobile ? 8.0 : (isMobile ? 10.0 : 12.0);
    final tabSpacing = isSmallMobile ? 10.0 : (isMobile ? 12.0 : 14.0);
    final tabFontSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : 15.0);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        height: tabHeight,
        margin: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
        color: Colors.white,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = category == selectedCategory;
            
            return Padding(
              padding: EdgeInsets.only(right: tabSpacing),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = category;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: tabPaddingH, vertical: tabPaddingV),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.secondary,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.secondary,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      category,
                      style: GoogleFonts.poppins(
                        fontSize: tabFontSize,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(bool isSmallMobile, bool isMobile, bool isTablet) {
    // Responsive grid settings
    final gridPadding = isSmallMobile ? 12.0 : (isMobile ? 16.0 : 20.0);
    final gridCrossAxisCount = isSmallMobile ? 2 : (isMobile ? 2 : (isTablet ? 3 : 4));
    final gridChildAspectRatio = isSmallMobile ? 0.60 : (isMobile ? 0.65 : (isTablet ? 0.70 : 0.75));
    final gridSpacing = isSmallMobile ? 12.0 : (isMobile ? 16.0 : 20.0);
    
    if (_isLoading) {
      return RefreshIndicator(
        onRefresh: _refreshFavorites,
        color: AppColors.primary,
        child: GridView.builder(
          padding: EdgeInsets.all(gridPadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridCrossAxisCount,
            childAspectRatio: gridChildAspectRatio,
            crossAxisSpacing: gridSpacing,
            mainAxisSpacing: gridSpacing,
          ),
          itemCount: 6,
          itemBuilder: (context, index) => _buildBookCardSkeleton(isSmallMobile, isMobile),
        ),
      );
    }
    
    if (filteredFavorites.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshFavorites,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: _buildEmptyState(isSmallMobile, isMobile),
          ),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _refreshFavorites,
      color: AppColors.primary,
      child: GridView.builder(
        padding: EdgeInsets.all(gridPadding),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridCrossAxisCount,
          childAspectRatio: gridChildAspectRatio,
          crossAxisSpacing: gridSpacing,
          mainAxisSpacing: gridSpacing,
        ),
        itemCount: filteredFavorites.length,
        itemBuilder: (context, index) {
          return _buildBookCard(filteredFavorites[index], isSmallMobile, isMobile);
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isSmallMobile, bool isMobile) {
    // Responsive sizing
    final iconSize = isSmallMobile ? 64.0 : (isMobile ? 80.0 : 96.0);
    final titleFontSize = isSmallMobile ? 18.0 : (isMobile ? 20.0 : 24.0);
    final bodyFontSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : 16.0);
    final spacing = isSmallMobile ? 12.0 : (isMobile ? 16.0 : 20.0);
    final bodySpacing = isSmallMobile ? 6.0 : (isMobile ? 8.0 : 10.0);
    final horizontalPadding = isSmallMobile ? 40.0 : (isMobile ? 48.0 : 60.0);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: iconSize,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: spacing),
          Text(
            'No Favorites Yet',
            style: GoogleFonts.poppins(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: bodySpacing),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Text(
              'Start adding books to your favorites to see them here',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: bodyFontSize,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book, bool isSmallMobile, bool isMobile) {
    // Responsive sizing
    final cardPadding = isSmallMobile ? 6.0 : (isMobile ? 8.0 : 10.0);
    final titleFontSize = isSmallMobile ? 11.0 : (isMobile ? 12.0 : 14.0);
    final authorFontSize = isSmallMobile ? 9.0 : (isMobile ? 10.0 : 12.0);
    final iconSize = isSmallMobile ? 40.0 : (isMobile ? 50.0 : 60.0);
    final textSpacing = isSmallMobile ? 1.0 : (isMobile ? 2.0 : 3.0);
    
    return GestureDetector(
      onTap: () {
        // Navigate to book detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailScreen(
              book: book,
              bookId: book['bookId'] ?? book['id'] ?? '',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildBookImage(book['imageUrl'], iconSize: iconSize),
              ),
              Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book['title'] ?? 'Untitled',
                      style: GoogleFonts.poppins(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: textSpacing),
                    Text(
                      book['author'] ?? 'Unknown Author',
                      style: GoogleFonts.poppins(
                        fontSize: authorFontSize,
                        color: Colors.grey.shade600,
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

  Widget _buildAnimatedIcon(IconData outlinedIcon, IconData filledIcon, int index) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
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
  
  Widget _buildBookCardSkeleton(bool isSmallMobile, bool isMobile) {
    final coverHeight = isSmallMobile ? 120.0 : (isMobile ? 130.0 : 140.0);
    final cardPadding = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: coverHeight,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.image_outlined,
                size: isSmallMobile ? 48.0 : 60.0,
                color: Colors.grey[400],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: isSmallMobile ? 14.0 : 16.0,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: isSmallMobile ? 10.0 : 12.0,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: isSmallMobile ? 18.0 : 20.0,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedIconWithBadge(IconData outlinedIcon, IconData filledIcon, int index, int badgeCount) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
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