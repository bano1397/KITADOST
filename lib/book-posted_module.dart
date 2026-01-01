import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'error_handler_module.dart';

class BookPostedScreen extends StatefulWidget {
  const BookPostedScreen({Key? key}) : super(key: key);

  @override
  State<BookPostedScreen> createState() => _BookPostedScreenState();
}

class _BookPostedScreenState extends State<BookPostedScreen> {
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  String selectedCategory = 'All';
  
  // Advanced filters
  String selectedCondition = 'All';
  String selectedLanguage = 'All';
  String selectedSort = 'Newest';
  bool showFilters = false;

  final List<String> categories = [
    'All',
    'Education',
    'Fiction',
    'Non - Fiction',
    'Mystery',
  ];
  
  final List<String> conditions = ['All', 'Brand New', 'Good as New', 'Old (Used)'];
  final List<String> languages = ['All', 'English', 'Filipino', 'Spanish', 'Chinese', 'Japanese', 'Korean', 'Other'];
  final List<String> sortOptions = ['Newest', 'Oldest', 'Title A-Z', 'Title Z-A'];

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

  // Helper function to build image widget that handles both Firebase Storage URLs and base64 (for card)
  Widget _buildBookImage(String? imageUrl, {required double height, required double iconSize}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.menu_book,
          size: iconSize,
          color: Colors.white.withOpacity(0.8),
        ),
      );
    }

    // Check if it's a URL (starts with http:// or https://)
    final isUrl = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    
    if (isUrl) {
      // It's a Firebase Storage URL
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.menu_book,
                size: iconSize,
                color: Colors.white.withOpacity(0.8),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white.withOpacity(0.8),
              ),
            );
          },
        ),
      );
    } else {
      // It's base64 encoded
      try {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          child: Image.memory(
            base64Decode(imageUrl),
            fit: BoxFit.cover,
            width: double.infinity,
            height: height,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(
                  Icons.menu_book,
                  size: iconSize,
                  color: Colors.white.withOpacity(0.8),
                ),
              );
            },
          ),
        );
      } catch (e) {
        return Center(
          child: Icon(
            Icons.menu_book,
            size: iconSize,
            color: Colors.white.withOpacity(0.8),
          ),
        );
      }
    }
  }

  // Helper function for detail view (without ClipRRect)
  Widget _buildBookImageFromUrl(String? imageUrl, {required double height, required double iconSize}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: height,
        color: Colors.grey[300],
        child: Icon(Icons.book, size: iconSize, color: Colors.grey[600]),
      );
    }

    final isUrl = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    
    if (isUrl) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            color: Colors.grey[300],
            child: Icon(Icons.book, size: iconSize, color: Colors.grey[600]),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            color: Colors.grey[200],
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
          width: double.infinity,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: height,
              color: Colors.grey[300],
              child: Icon(Icons.book, size: iconSize, color: Colors.grey[600]),
            );
          },
        );
      } catch (e) {
        return Container(
          height: height,
          color: Colors.grey[300],
          child: Icon(Icons.book, size: iconSize, color: Colors.grey[600]),
        );
      }
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshBooks() async {
    try {
      if (mounted) {
        setState(() {});
      }
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context: context,
          message: 'Failed to refresh books',
          onRetry: _refreshBooks,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    // Responsive breakpoints
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    
    // Responsive sizing
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : (isTablet ? 32.0 : 40.0));
    final gridCrossAxisCount = isSmallMobile ? 2 : (isMobile ? 2 : (isTablet ? 3 : 4));
    final gridChildAspectRatio = isSmallMobile ? 0.60 : (isMobile ? 0.65 : (isTablet ? 0.70 : 0.75));
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(isMobile, horizontalPadding),

            SizedBox(height: isMobile ? 20 : 24),
            
            // Search Bar with Filter Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: isMobile ? 48 : 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4DCE5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by title or author',
                          hintStyle: poppinsStyle(
                            color: Colors.grey,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[600],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  InkWell(
                    onTap: () {
                      setState(() {
                        showFilters = !showFilters;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: isMobile ? 48 : 52,
                      width: isMobile ? 48 : 52,
                      decoration: BoxDecoration(
                        color: showFilters ? AppColors.primary : AppColors.secondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.tune,
                        color: Colors.white,
                        size: isMobile ? 24 : 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Advanced Filters Panel
            if (showFilters) ...[
              SizedBox(height: isMobile ? 16 : 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sort By
                      Text(
                        'Sort By',
                        style: poppinsStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      SizedBox(height: isMobile ? 8 : 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sortOptions.map((sort) {
                          final isSelected = selectedSort == sort;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedSort = sort;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: isMobile ? 6 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.grey[300]!,
                                ),
                              ),
                              child: Text(
                                sort,
                                style: poppinsStyle(
                                  fontSize: isMobile ? 13 : 14,
                                  color: isSelected ? Colors.white : AppColors.secondary,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: isMobile ? 16 : 20),
                      // Condition Filter
                      Text(
                        'Condition',
                        style: poppinsStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      SizedBox(height: isMobile ? 8 : 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: conditions.map((condition) {
                          final isSelected = selectedCondition == condition;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCondition = condition;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: isMobile ? 6 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.secondary : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppColors.secondary : Colors.grey[300]!,
                                ),
                              ),
                              child: Text(
                                condition,
                                style: poppinsStyle(
                                  fontSize: isMobile ? 13 : 14,
                                  color: isSelected ? Colors.white : AppColors.secondary,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: isMobile ? 16 : 20),
                      // Language Filter
                      Text(
                        'Language',
                        style: poppinsStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      SizedBox(height: isMobile ? 8 : 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: languages.map((language) {
                          final isSelected = selectedLanguage == language;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedLanguage = language;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: isMobile ? 6 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.secondary : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppColors.secondary : Colors.grey[300]!,
                                ),
                              ),
                              child: Text(
                                language,
                                style: poppinsStyle(
                                  fontSize: isMobile ? 13 : 14,
                                  color: isSelected ? Colors.white : AppColors.secondary,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: isMobile ? 16 : 20),
                      // Reset Filters Button
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              selectedCondition = 'All';
                              selectedLanguage = 'All';
                              selectedSort = 'Newest';
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Reset Filters',
                            style: poppinsStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            SizedBox(height: isMobile ? 20 : 24),

            // Category Filters
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Container(
                height: isMobile ? 45 : 50,
                color: Colors.white,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = selectedCategory == category;
                    return Padding(
                      padding: EdgeInsets.only(right: isMobile ? 12 : 16),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 24 : 28,
                            vertical: isMobile ? 10 : 12,
                          ),
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
                          child: Text(
                            category,
                            style: poppinsStyle(
                              color: Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: isMobile ? 14 : 15,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            SizedBox(height: isMobile ? 24 : 28),

            // Books Grid
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshBooks,
                color: AppColors.primary,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance
                        .ref('books')
                        .orderByChild('createdAt')
                        .onValue,
                    builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading books',
                          style: poppinsStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridCrossAxisCount,
                          childAspectRatio: gridChildAspectRatio,
                          crossAxisSpacing: isMobile ? 16 : 20,
                          mainAxisSpacing: isMobile ? 16 : 20,
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) => _buildBookCardSkeleton(isSmallMobile, isMobile),
                      );
                    }

                    final event = snapshot.data;
                    final dataSnapshot = event?.snapshot;
                    final books = <Map<String, dynamic>>[];

                    if (dataSnapshot != null && dataSnapshot.value != null) {
                      final value = dataSnapshot.value;
                      if (value is Map) {
                        value.forEach((key, dynamic rawBook) {
                          if (rawBook is Map) {
                            final bookMap = Map<String, dynamic>.from(rawBook);
                            bookMap['id'] = key.toString();
                            if (bookMap['penalties'] is Map) {
                              bookMap['penalties'] = Map<String, dynamic>.from(
                                bookMap['penalties'] as Map,
                              );
                            }
                            books.add(bookMap);
                          }
                        });
                      }
                    }

                    books.sort((a, b) {
                      final aCreated = (a['createdAt'] ?? 0);
                      final bCreated = (b['createdAt'] ?? 0);
                      final aValue = aCreated is num ? aCreated.toInt() : 0;
                      final bValue = bCreated is num ? bCreated.toInt() : 0;
                      return bValue.compareTo(aValue);
                    });

                    // Filter by category and search
                    final filteredBooks = books.where((book) {
                      final title = (book['title'] ?? '').toString().toLowerCase();
                      final author = (book['author'] ?? '').toString().toLowerCase();
                      final genre = (book['genre'] ?? '').toString();
                      final condition = (book['condition'] ?? '').toString();
                      final language = (book['language'] ?? '').toString();

                      // Debug: Print book data when searching
                      if (searchQuery.isNotEmpty && books.indexOf(book) == 0) {
                        print('DEBUG Search - Query: "$searchQuery"');
                        print('DEBUG Search - Sample Book Title: "${book['title']}"');
                        print('DEBUG Search - Sample Book Author: "${book['author']}"');
                        print('DEBUG Search - Author field exists: ${book.containsKey('author')}');
                      }

                      // Search by title or author
                      if (searchQuery.isNotEmpty) {
                        final query = searchQuery.toLowerCase();
                        final titleMatch = title.contains(query);
                        final authorMatch = author.contains(query);
                        
                        if (!titleMatch && !authorMatch) {
                          return false;
                        }
                      }
                      
                      // Filter by category
                      if (selectedCategory != 'All' && genre != selectedCategory) {
                        return false;
                      }
                      
                      // Filter by condition
                      if (selectedCondition != 'All' && condition != selectedCondition) {
                        return false;
                      }
                      
                      // Filter by language
                      if (selectedLanguage != 'All' && language != selectedLanguage) {
                        return false;
                      }
                      
                      return true;
                    }).toList();
                    
                    // Apply sorting
                    if (selectedSort == 'Newest') {
                      filteredBooks.sort((a, b) {
                        final aTime = a['createdAt'] ?? 0;
                        final bTime = b['createdAt'] ?? 0;
                        return bTime.compareTo(aTime);
                      });
                    } else if (selectedSort == 'Oldest') {
                      filteredBooks.sort((a, b) {
                        final aTime = a['createdAt'] ?? 0;
                        final bTime = b['createdAt'] ?? 0;
                        return aTime.compareTo(bTime);
                      });
                    } else if (selectedSort == 'Title A-Z') {
                      filteredBooks.sort((a, b) {
                        final aTitle = (a['title'] ?? '').toString().toLowerCase();
                        final bTitle = (b['title'] ?? '').toString().toLowerCase();
                        return aTitle.compareTo(bTitle);
                      });
                    } else if (selectedSort == 'Title Z-A') {
                      filteredBooks.sort((a, b) {
                        final aTitle = (a['title'] ?? '').toString().toLowerCase();
                        final bTitle = (b['title'] ?? '').toString().toLowerCase();
                        return bTitle.compareTo(aTitle);
                      });
                    }

                    if (filteredBooks.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.book_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No books found',
                              style: poppinsStyle(
                                fontSize: 20,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              searchQuery.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'No books available in this category',
                              style: poppinsStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCrossAxisCount,
                        crossAxisSpacing: isMobile ? 16 : 20,
                        mainAxisSpacing: isMobile ? 16 : 20,
                        childAspectRatio: gridChildAspectRatio,
                      ),
                      itemCount: filteredBooks.length,
                      itemBuilder: (context, index) {
                        final book = filteredBooks[index];
                        final bookId = (book['id'] ?? '').toString();
                        return _buildBookCard(book, bookId, isMobile, isSmallMobile);
                      },
                    );
                  },
                ),
              ),
            ),
            ),
          ],
        ),
      ),
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

  Widget _buildHeader(bool isMobile, double horizontalPadding) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding, 
        vertical: isMobile ? 16 : 20
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).pop();
            },
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 12 : 14),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: isMobile ? 20 : 24,
              ),
            ),
          ),
          SizedBox(width: isMobile ? 16 : 20),
          Text(
            'Posted Books',
            style: poppinsStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book, String bookId, bool isMobile, bool isSmallMobile) {
    final condition = book['condition'] ?? 'Used';
    final isNew = condition.toLowerCase().contains('new');
    final imageUrl = book['imageUrl'] as String?;
    final cardImageHeight = isSmallMobile ? 120.0 : (isMobile ? 140.0 : 160.0);
    
    return GestureDetector(
      onTap: () {
        _showBookDetails(book, bookId);
      },
      child: Container(
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
            // Book Cover (uploaded image or placeholder with genre color)
            Container(
              height: cardImageHeight,
              decoration: BoxDecoration(
                color: _getGenreColor(book['genre']),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: _buildBookImage(imageUrl, height: cardImageHeight, iconSize: 60),
            ),
            
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12.0 : 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      book['title'] ?? 'Untitled',
                      style: poppinsStyle(
                        fontSize: isSmallMobile ? 13 : (isMobile ? 14 : 15),
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    SizedBox(height: isMobile ? 4 : 6),
                    
                    // Genre
                    Text(
                      book['genre'] ?? '',
                      style: poppinsStyle(
                        fontSize: isSmallMobile ? 10 : (isMobile ? 11 : 12),
                        color: Colors.grey,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Condition Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 10,
                        vertical: isMobile ? 4 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: isNew 
                            ? AppColors.primary 
                            : AppColors.secondary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        condition,
                        style: poppinsStyle(
                          fontSize: isSmallMobile ? 9 : (isMobile ? 10 : 11),
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGenreColor(String? genre) {
    switch (genre?.toLowerCase()) {
      case 'education':
        return const Color(0xFF4A90E2);
      case 'fiction':
        return const Color(0xFF9B59B6);
      case 'non - fiction':
        return const Color(0xFF27AE60);
      case 'mystery':
        return const Color(0xFFE67E22);
      default:
        return const Color(0xFF95A5A6);
    }
  }

  void _showBookDetails(Map<String, dynamic> book, String bookId) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isSmallMobile = size.width < 360;
    final modalPadding = isSmallMobile ? 20.0 : (isMobile ? 24.0 : 32.0);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: EdgeInsets.all(modalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: isMobile ? 40 : 50,
                      height: isMobile ? 4 : 5,
                      margin: EdgeInsets.only(bottom: isMobile ? 20 : 24),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  // Book Cover Image
                  if (book['imageUrl'] != null && (book['imageUrl'] as String).isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildBookImageFromUrl(
                        book['imageUrl'],
                        height: isSmallMobile ? 220 : (isMobile ? 250 : 300),
                        iconSize: 60,
                      ),
                    ),
                    SizedBox(height: isMobile ? 20 : 24),
                  ],
                  
                  // Book Title
                  Text(
                    book['title'] ?? 'Untitled',
                    style: poppinsStyle(
                      fontSize: isSmallMobile ? 20 : (isMobile ? 24 : 28),
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  
                  SizedBox(height: isMobile ? 8 : 12),
                  
                  // Author
                  Text(
                    'by ${book['author'] ?? 'Unknown Author'}',
                    style: poppinsStyle(
                      fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 18),
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  SizedBox(height: isMobile ? 24 : 28),
                  
                  // Details Grid
                  _buildDetailRow('Genre', book['genre'] ?? 'N/A', isSmallMobile, isMobile),
                  _buildDetailRow('Condition', book['condition'] ?? 'N/A', isSmallMobile, isMobile),
                  _buildDetailRow('Language', book['language'] ?? 'N/A', isSmallMobile, isMobile),
                  _buildDetailRow('Publisher', book['publisher'] ?? 'N/A', isSmallMobile, isMobile),
                  _buildDetailRow('Publication', book['publication'] ?? 'N/A', isSmallMobile, isMobile),
                  _buildDetailRow('Year', book['year'] ?? 'N/A', isSmallMobile, isMobile),
                  
                  SizedBox(height: isMobile ? 24 : 28),
                  
                  // About
                  if (book['about'] != null && book['about'].toString().isNotEmpty) ...[
                    Text(
                      'About',
                      style: poppinsStyle(
                        fontSize: isSmallMobile ? 16 : (isMobile ? 18 : 20),
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    Text(
                      book['about'],
                      style: poppinsStyle(
                        fontSize: isSmallMobile ? 13 : (isMobile ? 14 : 16),
                        color: Colors.grey[700] ?? Colors.grey,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: isMobile ? 24 : 28),
                  ],
                  
                  // Penalties
                  if (book['penalties'] != null) ...[
                    Text(
                      'Penalties',
                      style: poppinsStyle(
                        fontSize: isSmallMobile ? 16 : (isMobile ? 18 : 20),
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    _buildPenaltyRow('Late Return', book['penalties']['lateReturn'], isSmallMobile, isMobile),
                    _buildPenaltyRow('Damage', book['penalties']['damage'], isSmallMobile, isMobile),
                    _buildPenaltyRow('Lost/Unreturned', book['penalties']['lost'], isSmallMobile, isMobile),
                    SizedBox(height: isMobile ? 24 : 28),
                  ],
                  
                  // Status Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 20,
                      vertical: isMobile ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: book['status'] == 'available'
                          ? Colors.green[50]
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: book['status'] == 'available'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          book['status'] == 'available'
                              ? Icons.check_circle
                              : Icons.access_time,
                          color: book['status'] == 'available'
                              ? Colors.green
                              : Colors.orange,
                          size: isMobile ? 20 : 24,
                        ),
                        SizedBox(width: isMobile ? 8 : 10),
                        Text(
                          book['status'] == 'available'
                              ? 'Available'
                              : 'Not Available',
                          style: poppinsStyle(
                            fontSize: isSmallMobile ? 13 : (isMobile ? 14 : 16),
                            color: book['status'] == 'available'
                                ? Colors.green[700]!
                                : Colors.orange[700]!,
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _buildDetailRow(String label, String value, bool isSmallMobile, bool isMobile) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12.0 : 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 120 : 140,
            child: Text(
              label,
              style: poppinsStyle(
                fontSize: isSmallMobile ? 13 : (isMobile ? 14 : 16),
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: poppinsStyle(
                fontSize: isSmallMobile ? 13 : (isMobile ? 14 : 16),
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltyRow(String label, dynamic amount, bool isSmallMobile, bool isMobile) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 8.0 : 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: poppinsStyle(
              fontSize: isSmallMobile ? 13 : (isMobile ? 14 : 16),
              color: Colors.grey[700] ?? Colors.grey,
            ),
          ),
          Text(
            '₱${amount ?? 0}',
            style: poppinsStyle(
              fontSize: isSmallMobile ? 13 : (isMobile ? 14 : 16),
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
