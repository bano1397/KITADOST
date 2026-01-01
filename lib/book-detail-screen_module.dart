import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'message_module.dart' show ChatScreen;
import 'edit-book-postings_module.dart' show EditBookPostingForm;
import 'notification_system_module.dart';
import 'profile_others_module.dart';
import 'widgets/success_animation_dialog.dart';

class BookDetailScreen extends StatefulWidget {
  final Map<String, dynamic> book;
  final String bookId;

  const BookDetailScreen({
    Key? key,
    required this.book,
    required this.bookId,
  }) : super(key: key);

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _isFavorite = false;
  String? _ownerName;
  File? _ownerAvatar;
  bool _isLoadingOwner = true;
  String? _borrowStatus; // 'none', 'pending', 'approved', 'rejected'
  bool _hasUnreturnedBooks = false;

  @override
  void initState() {
    super.initState();
    // Debug: Check imageUrl value
    final imageUrl = widget.book['imageUrl'];
    print('DEBUG BookDetailScreen: imageUrl type: ${imageUrl.runtimeType}');
    final imageUrlStr = imageUrl?.toString() ?? '';
    final previewLength = imageUrlStr.length > 100 ? 100 : imageUrlStr.length;
    print('DEBUG BookDetailScreen: imageUrl value: ${imageUrlStr.substring(0, previewLength)}...');
    print('DEBUG BookDetailScreen: imageUrl is null: ${imageUrl == null}');
    print('DEBUG BookDetailScreen: imageUrl is empty: ${imageUrl?.toString().isEmpty ?? true}');
    print('DEBUG BookDetailScreen: Full book data keys: ${widget.book.keys.toList()}');
    
    _checkIfFavorite();
    _loadOwnerProfile();
    _checkBorrowStatus();
    _checkUnreturnedBooks();
  }
  
  // Generate a consistent chat ID for two users
  String _generateChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _loadOwnerProfile() async {
    try {
      final ownerId = widget.book['ownerId'];
      if (ownerId == null || ownerId.toString().isEmpty) {
        setState(() {
          _ownerName = widget.book['ownerName'] ?? 'Unknown Owner';
          _isLoadingOwner = false;
        });
        return;
      }

      // Fetch owner's current name and avatar from Firebase
      final userSnapshot = await FirebaseDatabase.instance
          .ref('users/$ownerId')
          .once();
      
      if (userSnapshot.snapshot.value != null) {
        final userData = userSnapshot.snapshot.value as Map<dynamic, dynamic>;
        _ownerName = userData['username'] ?? widget.book['ownerName'] ?? 'Unknown Owner';
        
        // Load owner's avatar from Firebase Database (base64)
        if (userData['avatar'] != null) {
          final avatarBase64 = userData['avatar'] as String;
          if (avatarBase64.isNotEmpty) {
            try {
              final bytes = base64Decode(avatarBase64);
              final tempDir = Directory.systemTemp;
              final file = File('${tempDir.path}/owner_avatar_$ownerId.png');
              await file.writeAsBytes(bytes);
              _ownerAvatar = file;
              
              // Also save to SharedPreferences for offline access
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('avatar_base64_$ownerId', avatarBase64);
            } catch (e) {
              print('Error loading owner avatar from database: $e');
            }
          }
        }
      } else {
        _ownerName = widget.book['ownerName'] ?? 'Unknown Owner';
      }

      // Fallback: Load owner's avatar from SharedPreferences if not in database
      if (_ownerAvatar == null) {
        final prefs = await SharedPreferences.getInstance();
        final avatarBase64 = prefs.getString('avatar_base64_$ownerId');
        if (avatarBase64 != null && avatarBase64.isNotEmpty) {
          try {
            final bytes = base64Decode(avatarBase64);
            final tempDir = Directory.systemTemp;
            final file = File('${tempDir.path}/owner_avatar_$ownerId.png');
            await file.writeAsBytes(bytes);
            _ownerAvatar = file;
          } catch (e) {
            print('Error loading owner avatar from cache: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingOwner = false;
        });
      }
    } catch (e) {
      print('Error loading owner profile: $e');
      if (mounted) {
        setState(() {
          _ownerName = widget.book['ownerName'] ?? 'Unknown Owner';
          _isLoadingOwner = false;
        });
      }
    }
  }

  Future<void> _checkBorrowStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if user has a borrow request for this book
      final snapshot = await FirebaseDatabase.instance
          .ref('borrows')
          .orderByChild('borrowerId')
          .equalTo(user.uid)
          .once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        // Find request for this specific book
        for (var entry in data.entries) {
          final borrowData = entry.value as Map<dynamic, dynamic>;
          if (borrowData['bookId'] == widget.bookId) {
            // Check if book has been returned - if so, treat as no active request
            if (borrowData['returned'] == true) {
              if (mounted) {
                setState(() {
                  _borrowStatus = 'none';
                });
              }
              return;
            }
            
            if (mounted) {
              setState(() {
                _borrowStatus = borrowData['status']; // 'pending', 'approved', 'rejected'
              });
            }
            return;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _borrowStatus = 'none';
        });
      }
    } catch (e) {
      print('Error checking borrow status: $e');
      if (mounted) {
        setState(() {
          _borrowStatus = 'none';
        });
      }
    }
  }

  Future<void> _checkUnreturnedBooks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if user has any unreturned books
      final snapshot = await FirebaseDatabase.instance
          .ref('borrows')
          .orderByChild('borrowerId')
          .equalTo(user.uid)
          .once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        // Check if any approved borrow hasn't been returned
        for (var entry in data.values) {
          final borrowData = entry as Map<dynamic, dynamic>;
          if (borrowData['status'] == 'approved' && borrowData['returned'] != true) {
            if (mounted) {
              setState(() {
                _hasUnreturnedBooks = true;
              });
            }
            return;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _hasUnreturnedBooks = false;
        });
      }
    } catch (e) {
      print('Error checking unreturned books: $e');
    }
  }

  Future<void> _sendBorrowRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please log in to request books',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }

    // Check if user has unreturned books
    if (_hasUnreturnedBooks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You cannot borrow books until you return your current borrowed book',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // Get requester name
      String requesterName = user.displayName ?? 'Unknown User';
      final userSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/username')
          .once();
      if (userSnapshot.snapshot.exists) {
        requesterName = userSnapshot.snapshot.value.toString();
      }
      
      // Create borrow request
      final borrowRef = FirebaseDatabase.instance.ref('borrows').push();
      await borrowRef.set({
        'bookId': widget.bookId,
        'bookTitle': widget.book['title'],
        'borrowerId': user.uid,
        'borrowerName': requesterName,
        'userId': user.uid,
        'requesterName': requesterName,
        'ownerId': widget.book['ownerId'],
        'ownerName': _ownerName ?? 'Unknown Owner',
        'status': 'pending',
        'requestedAt': ServerValue.timestamp,
        'returned': false,
      });

      // Send notification to book owner
      final notificationSystem = NotificationSystemModule();
      await notificationSystem.notifyBorrowRequest(
        ownerId: widget.book['ownerId'],
        requesterName: requesterName,
        bookTitle: widget.book['title'],
        requestId: borrowRef.key ?? '',
      );

      setState(() {
        _borrowStatus = 'pending';
      });

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const SuccessAnimationDialog(
            animationPath: 'assets/animations/BorrowBook.json',
            message: 'Request Sent!',
            subMessage: 'Waiting for owner approval.',
          ),
        );
      }
    } catch (e) {
      print('Error sending borrow request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send request: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('favorites/${user.uid}/${widget.bookId}')
          .once();
      
      if (mounted) {
        setState(() {
          _isFavorite = snapshot.snapshot.exists;
        });
      }
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add favorites')),
      );
      return;
    }

    try {
      final favRef = FirebaseDatabase.instance.ref('favorites/${user.uid}/${widget.bookId}');
      
      if (_isFavorite) {
        // Remove from favorites
        await favRef.remove();
        setState(() {
          _isFavorite = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Removed from favorites',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppColors.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } else {
        // Add to favorites - store only timestamp, book data will be fetched from /books/
        await favRef.set({
          'addedAt': ServerValue.timestamp,
        });
        
        setState(() {
          _isFavorite = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added to favorites!',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _openMapLink(String mapLink) async {
    try {
      final Uri url = Uri.parse(mapLink);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not open map link',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error opening map link: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error opening map: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == widget.book['ownerId'];
    
    // Get screen dimensions
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    // Responsive breakpoints
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    
    // Responsive sizing
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : (isTablet ? 40.0 : 60.0));
    final bookCoverHeight = isSmallMobile ? 350.0 : (isMobile ? 400.0 : (isTablet ? 450.0 : 500.0));
    final bookCoverWidth = isSmallMobile ? 200.0 : (isMobile ? 250.0 : (isTablet ? 280.0 : 320.0));
    final bookCoverImageHeight = isSmallMobile ? 280.0 : (isMobile ? 350.0 : (isTablet ? 380.0 : 420.0));
    final titleFontSize = isSmallMobile ? 20.0 : (isMobile ? 24.0 : (isTablet ? 28.0 : 32.0));
    final sectionTitleSize = isSmallMobile ? 16.0 : (isMobile ? 18.0 : (isTablet ? 20.0 : 22.0));
    final bodyTextSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : (isTablet ? 15.0 : 16.0));
    final smallTextSize = isSmallMobile ? 11.0 : (isMobile ? 12.0 : (isTablet ? 13.0 : 14.0));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Book Cover Section with Back Button
              Stack(
                children: [
                  // Book Cover with gradient background and logo
                  Container(
                    height: bookCoverHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _getGenreColor(widget.book['genre']),
                          _getGenreColor(widget.book['genre']).withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Background logo with whitish transparency
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.3,
                            child: Center(
                              child: Image.asset(
                                'assets/background logo.png',
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error loading background logo: $error');
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                        ),
                        // Book cover
                        Center(
                          child: Container(
                            width: bookCoverWidth,
                            height: bookCoverImageHeight,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildBookImage(widget.book['imageUrl']?.toString()),
                                  // Status watermark overlay
                                  if (widget.book['status'] == 'borrowed' || widget.book['status'] == 'reserved')
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Center(
                                          child: Transform.rotate(
                                            angle: -0.3,
                                            child: Text(
                                              widget.book['status'] == 'borrowed' ? 'BORROWED' : 'RESERVED',
                                              style: GoogleFonts.poppins(
                                                fontSize: isSmallMobile ? 24.0 : (isMobile ? 28.0 : 32.0),
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white.withOpacity(0.9),
                                                letterSpacing: 2.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Back Button
                  Positioned(
                    top: 16,
                    left: 16,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 12 : 14),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: isMobile ? 24 : 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: isMobile ? 24 : 32),

              // Book Title, Genre, and Favorite Icon
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Genre
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book['title'] ?? 'Untitled',
                            style: GoogleFonts.poppins(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                          SizedBox(height: isMobile ? 4 : 6),
                          Text(
                            widget.book['genre'] ?? 'Unknown Genre',
                            style: GoogleFonts.poppins(
                              fontSize: bodyTextSize,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Edit Icon (only for owner)
                    if (isOwner)
                      InkWell(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditBookPostingForm(
                                book: widget.book,
                                bookId: widget.bookId,
                              ),
                            ),
                          );
                          // Refresh the screen if book was updated
                          if (result == true && mounted) {
                            setState(() {
                              // Trigger rebuild to show updated data
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 12 : 14),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: isMobile ? 24 : 28,
                          ),
                        ),
                      ),
                    if (!isOwner)
                      // Favorite Icon (only for non-owners)
                      InkWell(
                        onTap: _toggleFavorite,
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 12 : 14),
                          decoration: BoxDecoration(
                            color: _isFavorite 
                              ? AppColors.primary 
                              : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: _isFavorite ? Colors.white : Colors.grey[600],
                            size: isMobile ? 24 : 28,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 24 : 32),

              // Info Grid (Author, Condition, Genre, Language)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.person,
                        label: 'Author',
                        value: widget.book['author'] ?? 'Unknown',
                        isMobile: isMobile,
                        smallTextSize: smallTextSize,
                        bodyTextSize: bodyTextSize,
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.verified,
                        label: 'Condition',
                        value: widget.book['condition'] ?? 'Used',
                        isMobile: isMobile,
                        smallTextSize: smallTextSize,
                        bodyTextSize: bodyTextSize,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 12 : 16),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.category,
                        label: 'Genre',
                        value: widget.book['genre'] ?? 'Unknown',
                        isMobile: isMobile,
                        smallTextSize: smallTextSize,
                        bodyTextSize: bodyTextSize,
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.translate,
                        label: 'Language',
                        value: widget.book['language'] ?? 'Unknown',
                        isMobile: isMobile,
                        smallTextSize: smallTextSize,
                        bodyTextSize: bodyTextSize,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 24 : 32),

              // About this Book
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About this Book',
                      style: GoogleFonts.poppins(
                        fontSize: sectionTitleSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    Text(
                      widget.book['about'] ?? 'No description available.',
                      style: GoogleFonts.poppins(
                        fontSize: bodyTextSize,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 24 : 32),

              // Penalties Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Penalties',
                      style: GoogleFonts.poppins(
                        fontSize: sectionTitleSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                      _buildPenaltyItem(
                        'Late Return:',
                        'Php ${widget.book['penalties']?['lateReturn'] ?? 0}',
                      ),
                      _buildPenaltyItem(
                        'Book Damage:',
                        'Php ${widget.book['penalties']?['damage'] ?? 0}',
                      ),
                      _buildPenaltyItem(
                        'Lost or Unreturned:',
                        'Php ${widget.book['penalties']?['lost'] ?? 0}',
                      ),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 24 : 32),

              // Pickup Location Section
              if (widget.book['pickupLocation'] != null && widget.book['pickupLocation'].toString().isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup Location',
                        style: GoogleFonts.poppins(
                          fontSize: sectionTitleSize,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      SizedBox(height: isMobile ? 12 : 16),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isMobile ? 16 : 20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: isMobile ? 24 : 28,
                            ),
                            SizedBox(width: isMobile ? 12 : 16),
                            Expanded(
                              child: Text(
                                widget.book['pickupLocation'],
                                style: GoogleFonts.poppins(
                                  fontSize: bodyTextSize,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Map Link Button
                      if (widget.book['mapLink'] != null && widget.book['mapLink'].toString().isNotEmpty) ...[
                        SizedBox(height: isMobile ? 12 : 16),
                        InkWell(
                          onTap: () => _openMapLink(widget.book['mapLink']),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 16 : 20,
                              vertical: isMobile ? 14 : 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.map,
                                  color: Colors.white,
                                  size: isMobile ? 20 : 24,
                                ),
                                SizedBox(width: isMobile ? 8 : 12),
                                Text(
                                  'View on Map',
                                  style: GoogleFonts.poppins(
                                    fontSize: bodyTextSize,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: isMobile ? 8 : 12),
                                Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: isMobile ? 18 : 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              if (widget.book['pickupLocation'] != null && widget.book['pickupLocation'].toString().isNotEmpty)
                SizedBox(height: isMobile ? 24 : 32),

              // Owner Info Card
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: GestureDetector(
                  onTap: () {
                    if (widget.book['ownerId'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OtherUserProfileScreen(
                            userId: widget.book['ownerId'],
                            userName: _ownerName,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                      _isLoadingOwner
                          ? CircleAvatar(
                              radius: isMobile ? 28 : 32,
                              backgroundColor: const Color(0xFF4A90E2),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : CircleAvatar(
                              radius: isMobile ? 28 : 32,
                              backgroundColor: const Color(0xFF4A90E2),
                              backgroundImage: _ownerAvatar != null ? FileImage(_ownerAvatar!) : null,
                              child: _ownerAvatar == null
                                  ? Text(
                                      (_ownerName ?? 'U')[0].toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 24 : 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                      SizedBox(width: isMobile ? 16 : 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _isLoadingOwner
                                ? Container(
                                    height: 20,
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  )
                                : Text(
                                    _ownerName ?? 'Unknown Owner',
                                    style: GoogleFonts.poppins(
                                      fontSize: bodyTextSize + 2,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                            const SizedBox(height: 2),
                            Text(
                              'Owner',
                              style: GoogleFonts.poppins(
                                fontSize: smallTextSize,
                                color: Colors.grey,
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

              // Request and Message Buttons (only show if not owner)
              if (!isOwner)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    children: [
                      SizedBox(height: isMobile ? 16 : 20),
                      Row(
                        children: [
                          // Request Button
                          Expanded(
                            child: _buildRequestButton(isMobile, bodyTextSize),
                          ),
                          SizedBox(width: isMobile ? 12 : 16),
                          // Message Button
                          Expanded(
                            child: _buildMessageButton(isMobile, bodyTextSize),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              SizedBox(height: isMobile ? 32 : 40),
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestButton(bool isMobile, double bodyTextSize) {
    String buttonText = 'Request';
    Color buttonColor = AppColors.secondary;
    IconData buttonIcon = Icons.book_outlined;
    VoidCallback? onTap = _sendBorrowRequest;

    if (_borrowStatus == 'pending') {
      buttonText = 'Pending';
      buttonColor = Colors.orange;
      buttonIcon = Icons.schedule;
      onTap = null; // Disable button
    } else if (_borrowStatus == 'approved') {
      buttonText = 'Approved';
      buttonColor = Colors.green;
      buttonIcon = Icons.check_circle_outline;
      onTap = null; // Disable button
    } else if (_borrowStatus == 'rejected') {
      buttonText = 'Rejected';
      buttonColor = Colors.red;
      buttonIcon = Icons.cancel_outlined;
      onTap = null; // Disable button
    } else if (_hasUnreturnedBooks) {
      buttonText = 'Cannot Borrow';
      buttonColor = Colors.grey;
      buttonIcon = Icons.block;
      onTap = _sendBorrowRequest; // Show error message when tapped
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20, 
          vertical: isMobile ? 14 : 16
        ),
        decoration: BoxDecoration(
          color: onTap == null ? buttonColor.withOpacity(0.6) : buttonColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: onTap != null ? [
            BoxShadow(
              color: buttonColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              buttonIcon,
              color: Colors.white,
              size: isMobile ? 20 : 22,
            ),
            SizedBox(width: isMobile ? 8 : 10),
            Text(
              buttonText,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: bodyTextSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageButton(bool isMobile, double bodyTextSize) {
    return InkWell(
      onTap: () async {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Please log in to send messages',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: AppColors.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          return;
        }
        
        // Get owner's UID
        final ownerUid = widget.book['ownerId'] ?? widget.book['uid'] ?? widget.book['userId'];
        if (ownerUid == null || ownerUid.toString().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Owner information not available',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppColors.secondary,
            ),
          );
          return;
        }
        
        // Create or get chat ID
        final chatId = _generateChatId(currentUser.uid, ownerUid);
        
        // Fetch current user's name
        String currentUserName = currentUser.displayName ?? 'User';
        try {
          final currentUserSnapshot = await FirebaseDatabase.instance
              .ref('users/${currentUser.uid}')
              .once();
          
          if (currentUserSnapshot.snapshot.value != null) {
            final currentUserData = currentUserSnapshot.snapshot.value as Map<dynamic, dynamic>;
            currentUserName = currentUserData['username'] ?? currentUser.displayName ?? 'User';
          }
        } catch (e) {
          print('Error fetching current user name: $e');
        }
        
        // Fetch owner's name
        String ownerName = _ownerName ?? 'Book Owner';
        try {
          final ownerSnapshot = await FirebaseDatabase.instance
              .ref('users/$ownerUid')
              .once();
          
          if (ownerSnapshot.snapshot.value != null) {
            final ownerData = ownerSnapshot.snapshot.value as Map<dynamic, dynamic>;
            ownerName = ownerData['username'] ?? _ownerName ?? 'Book Owner';
          }
        } catch (e) {
          print('Error fetching owner name: $e');
        }
        
        // Create/update chat metadata
        final chatRef = FirebaseDatabase.instance.ref('chats/$chatId');
        final existingChat = await chatRef.once();
        
        if (existingChat.snapshot.exists) {
          await chatRef.update({
            'participantNames': {
              currentUser.uid: currentUserName,
              ownerUid: ownerName,
            },
            'lastMessage': 'Chat about ${widget.book['title']}',
            'lastMessageTime': ServerValue.timestamp,
          });
        } else {
          await chatRef.set({
            'participants': {
              currentUser.uid: true,
              ownerUid: true,
            },
            'participantNames': {
              currentUser.uid: currentUserName,
              ownerUid: ownerName,
            },
            'lastMessage': 'Chat about ${widget.book['title']}',
            'lastMessageTime': ServerValue.timestamp,
            'bookId': widget.bookId,
            'bookTitle': widget.book['title'],
          });
        }
        
        // Navigate to chat screen
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              chatName: ownerName,
              isSystemChat: false,
              otherUserId: ownerUid,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20, 
          vertical: isMobile ? 14 : 16
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message,
              color: Colors.white,
              size: isMobile ? 20 : 22,
            ),
            SizedBox(width: isMobile ? 8 : 10),
            Text(
              'Message',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: bodyTextSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isMobile,
    required double smallTextSize,
    required double bodyTextSize,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isMobile ? 20 : 24,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: smallTextSize,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: bodyTextSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltyItem(String label, String amount) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final bodyTextSize = size.width < 360 ? 13.0 : (isMobile ? 14.0 : (size.width < 900 ? 15.0 : 16.0));
    
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: bodyTextSize,
              color: Colors.grey[700],
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.poppins(
              fontSize: bodyTextSize,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ],
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
  Widget _buildBookImage(String? imageUrl) {
    // Convert to string and trim
    final urlString = imageUrl?.toString().trim() ?? '';
    
    print('DEBUG: Building book image. URL: ${urlString.isEmpty ? "EMPTY" : urlString.substring(0, urlString.length > 50 ? 50 : urlString.length)}...');
    
    if (urlString.isEmpty) {
      print('DEBUG: Image URL is empty, showing default cover');
      return _buildDefaultBookCover();
    }

    // Check if it's a URL (starts with http:// or https://)
    final isUrl = urlString.startsWith('http://') || urlString.startsWith('https://');
    print('DEBUG: Is URL: $isUrl');
    
    if (isUrl) {
      // It's a Firebase Storage URL
      print('DEBUG: Loading network image from: $urlString');
      return Image.network(
        urlString,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print('DEBUG: Error loading network image: $error');
          return _buildDefaultBookCover();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('DEBUG: Image loaded successfully');
            return child;
          }
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    } else {
      // It's base64 encoded
      print('DEBUG: Attempting to decode base64 image');
      try {
        return Image.memory(
          base64Decode(urlString),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            print('DEBUG: Error decoding base64 image: $error');
            return _buildDefaultBookCover();
          },
        );
      } catch (e) {
        print('DEBUG: Exception decoding base64: $e');
        return _buildDefaultBookCover();
      }
    }
  }

  Widget _buildDefaultBookCover() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isSmallMobile = size.width < 360;
    
    final iconSize = isSmallMobile ? 35.0 : (isMobile ? 40.0 : 50.0);
    final titleSize = isSmallMobile ? 20.0 : (isMobile ? 24.0 : 28.0);
    final authorLabelSize = isSmallMobile ? 9.0 : (isMobile ? 10.0 : 11.0);
    final authorSize = isSmallMobile ? 8.0 : (isMobile ? 9.0 : 10.0);
    
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0033A0),
                const Color(0xFF0066FF),
                Colors.white,
                const Color(0xFFFF0000),
                const Color(0xFFCC0000),
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on,
                color: Colors.yellow[700],
                size: iconSize,
              ),
              SizedBox(height: isMobile ? 20 : 24),
              Text(
                widget.book['title'] ?? 'READINGS IN\nPHILIPPINE\nHISTORY',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Author/s:',
                      style: GoogleFonts.poppins(
                        fontSize: authorLabelSize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      widget.book['author'] ?? 'Unknown',
                      style: GoogleFonts.poppins(
                        fontSize: authorSize,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
