import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:path_provider/path_provider.dart';
import 'book-detail-screen_module.dart';
import 'theme/app_colors.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId; // The user ID of the profile to view
  final String? userName; // Optional: pass username if already known

  const OtherUserProfileScreen({
    super.key,
    required this.userId,
    this.userName,
  });

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  String userName = 'User';
  String userBio = '';
  String userEmail = '';
  String userPhone = '';
  File? _avatarImage;
  double userRating = 0.0;
  int totalRatings = 0;
  List<Map<String, dynamic>> userPostings = [];
  List<Map<String, dynamic>> userRatingsWithComments = [];
  bool isLoading = true;
  
  // Privacy settings
  bool showEmail = false;
  bool showPhone = false;

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
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      isLoading = true;
    });

    await Future.wait([
      _loadUserName(),
      _loadUserBio(),
      _loadUserAvatar(),
      _loadUserRating(),
      _loadUserPostings(),
      _loadContactInfo(),
      _loadUserRatingsWithComments(),
    ]);

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadUserName() async {
    try {
      if (widget.userName != null && widget.userName!.isNotEmpty) {
        setState(() {
          userName = widget.userName!;
        });
        return;
      }

      final userRef = FirebaseDatabase.instance.ref('users/${widget.userId}/username');
      final snapshot = await userRef.get().timeout(const Duration(seconds: 5));

      if (snapshot.exists && snapshot.value != null) {
        if (mounted) {
          setState(() {
            userName = snapshot.value.toString();
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error loading username: $e');
    }
  }

  Future<void> _loadUserBio() async {
    try {
      final bioRef = FirebaseDatabase.instance.ref('users/${widget.userId}/bio');
      final snapshot = await bioRef.get().timeout(const Duration(seconds: 5));

      if (snapshot.exists && snapshot.value != null) {
        if (mounted) {
          setState(() {
            userBio = snapshot.value.toString();
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error loading bio: $e');
    }
  }

  Future<void> _loadContactInfo() async {
    try {
      final userRef = FirebaseDatabase.instance.ref('users/${widget.userId}');
      final snapshot = await userRef.get().timeout(const Duration(seconds: 5));

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        
        // Load privacy settings (default to true for email, false for phone)
        final privacy = data['privacy'] as Map<dynamic, dynamic>?;
        final showEmailSetting = privacy?['showEmail'] ?? true; // Default ON
        final showPhoneSetting = privacy?['showPhone'] ?? false;
        
        if (mounted) {
          setState(() {
            showEmail = showEmailSetting;
            showPhone = showPhoneSetting;
            userEmail = showEmailSetting ? (data['email']?.toString() ?? '') : '';
            userPhone = showPhoneSetting ? (data['phone']?.toString() ?? '') : '';
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error loading contact info: $e');
    }
  }

  Future<void> _loadUserAvatar() async {
    try {
      // Load avatar from Firebase Database (base64)
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${widget.userId}/avatar')
          .get()
          .timeout(const Duration(seconds: 5));
      
      if (snapshot.exists && snapshot.value != null) {
        final avatarBase64 = snapshot.value as String;
        if (avatarBase64.isNotEmpty) {
          print('DEBUG: Found avatar in Firebase Database for user ${widget.userId}');
          // Decode base64 and create temporary file
          final bytes = base64Decode(avatarBase64);
          final tempDir = await getApplicationDocumentsDirectory();
          final avatarFile = File('${tempDir.path}/avatar_${widget.userId}.png');
          await avatarFile.writeAsBytes(bytes);
          
          if (mounted) {
            setState(() {
              _avatarImage = avatarFile;
            });
          }
        }
      }
    } catch (e) {
      print('DEBUG: Error loading avatar: $e');
    }
  }

  Future<void> _loadUserRating() async {
    try {
      // Get actual ratings from database and calculate
      final ratingsSnapshot = await FirebaseDatabase.instance
          .ref('ratings')
          .get()
          .timeout(const Duration(seconds: 5));
      
      double totalRating = 0.0;
      int count = 0;
      
      if (ratingsSnapshot.exists) {
        final data = ratingsSnapshot.value as Map<dynamic, dynamic>;
        
        for (var entry in data.entries) {
          final ratingData = entry.value as Map;
          if (ratingData['ratedUserId'] == widget.userId) {
            final rating = ratingData['rating'];
            if (rating != null) {
              totalRating += (rating is int ? rating.toDouble() : rating.toDouble());
              count++;
            }
          }
        }
      }
      
      // Calculate average
      final average = count > 0 ? totalRating / count : 0.0;
      
      print('DEBUG: User ${widget.userId} rating - total: $totalRating, count: $count, average: $average');
      
      if (mounted) {
        setState(() {
          userRating = double.parse(average.toStringAsFixed(2));
          totalRatings = count;
        });
      }
    } catch (e) {
      print('DEBUG: Error loading rating: $e');
    }
  }

  Future<void> _loadUserPostings() async {
    try {
      final postingsRef = FirebaseDatabase.instance.ref('books');
      final snapshot = await postingsRef
          .orderByChild('ownerId')
          .equalTo(widget.userId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (snapshot.exists && snapshot.value != null) {
        final booksMap = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> loadedPostings = [];

        booksMap.forEach((key, value) {
          final book = Map<String, dynamic>.from(value as Map);
          book['id'] = key;
          loadedPostings.add(book);
        });

        // Sort by createdAt timestamp (newest first)
        loadedPostings.sort((a, b) {
          final aTime = a['createdAt'] ?? 0;
          final bTime = b['createdAt'] ?? 0;
          return bTime.compareTo(aTime);
        });

        if (mounted) {
          setState(() {
            userPostings = loadedPostings;
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error loading postings: $e');
    }
  }

  Future<void> _loadUserRatingsWithComments() async {
    try {
      final ratingsRef = FirebaseDatabase.instance.ref('ratings');
      final snapshot = await ratingsRef
          .orderByChild('ratedUserId')
          .equalTo(widget.userId)
          .get()
          .timeout(const Duration(seconds: 5));

      List<Map<String, dynamic>> loadedRatings = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var entry in data.entries) {
          final ratingData = Map<String, dynamic>.from(entry.value as Map);
          ratingData['id'] = entry.key;

          // Load rater name
          if (ratingData['raterUserId'] != null) {
            final raterSnapshot = await FirebaseDatabase.instance
                .ref('users/${ratingData['raterUserId']}/username')
                .get();
            if (raterSnapshot.exists) {
              ratingData['raterName'] = raterSnapshot.value;
            }
          }

          // Only include ratings with comments
          if (ratingData['comment'] != null && ratingData['comment'].toString().trim().isNotEmpty) {
            loadedRatings.add(ratingData);
          }
        }
      }

      // Sort by timestamp (newest first)
      loadedRatings.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

      if (mounted) {
        setState(() {
          userRatingsWithComments = loadedRatings;
        });
      }
    } catch (e) {
      print('DEBUG: Error loading ratings with comments: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : (isTablet ? 28.0 : 36.0));
    final verticalPadding = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    final avatarSize = isSmallMobile ? 100.0 : (isMobile ? 110.0 : (isTablet ? 120.0 : 140.0));
    final nameFontSize = isSmallMobile ? 22.0 : (isMobile ? 24.0 : (isTablet ? 26.0 : 30.0));

    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.secondary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.secondary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.secondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          userName,
          style: poppinsStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.secondary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            children: [
              // Profile Avatar
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.secondary,
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: _avatarImage != null
                      ? Image.file(
                          _avatarImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar(avatarSize);
                          },
                        )
                      : _buildDefaultAvatar(avatarSize),
                ),
              ),

              SizedBox(height: isSmallMobile ? 16 : 20),

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

              // Bio
              SizedBox(height: isSmallMobile ? 8 : 12),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 24 : 32),
                child: Text(
                  userBio.isNotEmpty ? userBio : 'No bio yet',
                  style: GoogleFonts.poppins(
                    fontSize: isSmallMobile ? 12 : 13,
                    color: userBio.isNotEmpty ? Colors.grey[600]! : Colors.grey[400]!,
                    height: 1.4,
                    fontStyle: userBio.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Contact Info
              if (showEmail || showPhone) ...[
                SizedBox(height: isSmallMobile ? 12 : 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 24 : 32),
                  child: Column(
                    children: [
                      if (showEmail && userEmail.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: isSmallMobile ? 16 : 18,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                userEmail,
                                style: poppinsStyle(
                                  fontSize: isSmallMobile ? 12 : 13,
                                  color: Colors.grey[700]!,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (showPhone && userPhone.isNotEmpty) ...[
                        if (showEmail && userEmail.isNotEmpty)
                          const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: isSmallMobile ? 16 : 18,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              userPhone,
                              style: poppinsStyle(
                                fontSize: isSmallMobile ? 12 : 13,
                                color: Colors.grey[700]!,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              SizedBox(height: isSmallMobile ? 16 : 20),

              // Rating Section
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallMobile ? 16 : 20,
                  vertical: isSmallMobile ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      userRating.toStringAsFixed(1),
                      style: poppinsStyle(
                        fontSize: isSmallMobile ? 20 : 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($totalRatings)',
                      style: poppinsStyle(
                        fontSize: isSmallMobile ? 13 : 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600]!,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isSmallMobile ? 28 : 32),

              // Posted Books Section
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 500),
                padding: EdgeInsets.all(isSmallMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.book_outlined,
                          color: AppColors.secondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Posted Books',
                          style: poppinsStyle(
                            fontSize: isSmallMobile ? 18 : 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Postings List
                    if (userPostings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No posts yet',
                            style: poppinsStyle(
                              fontSize: 14,
                              color: Colors.grey[600]!,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: userPostings.length,
                        itemBuilder: (context, index) {
                          final post = userPostings[index];
                          return _buildPostingCard(post, isSmallMobile, isMobile);
                        },
                      ),
                  ],
                ),
              ),

              // Ratings & Reviews Section
              if (userRatingsWithComments.isNotEmpty) ...[
                SizedBox(height: isSmallMobile ? 24 : 28),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: EdgeInsets.all(isSmallMobile ? 16 : 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.rate_review_outlined,
                            color: AppColors.secondary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Reviews',
                            style: poppinsStyle(
                              fontSize: isSmallMobile ? 18 : 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${userRatingsWithComments.length}',
                            style: poppinsStyle(
                              fontSize: isSmallMobile ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: userRatingsWithComments.length,
                        itemBuilder: (context, index) {
                          return _buildRatingCard(
                            userRatingsWithComments[index],
                            isSmallMobile,
                            isMobile,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCard(Map<String, dynamic> rating, bool isSmallMobile, bool isMobile) {
    final stars = rating['rating'] ?? 0;
    final comment = rating['comment'] ?? '';
    final raterName = rating['raterName'] ?? 'Anonymous';
    final bookTitle = rating['bookTitle'] ?? '';
    final timestamp = rating['timestamp'] ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final dateStr = '${date.day}/${date.month}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isSmallMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      raterName,
                      style: poppinsStyle(
                        fontSize: isSmallMobile ? 15 : 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                    if (bookTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'for "$bookTitle"',
                        style: poppinsStyle(
                          fontSize: isSmallMobile ? 12 : 13,
                          color: Colors.grey[600]!,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Stars
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < stars ? Icons.star : Icons.star_border,
                    size: isSmallMobile ? 16 : 18,
                    color: AppColors.primary,
                  );
                }),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Comment
          Text(
            comment,
            style: poppinsStyle(
              fontSize: isSmallMobile ? 13 : 14,
              color: Colors.grey[800]!,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Date
          Row(
            children: [
              Icon(Icons.calendar_today, size: isSmallMobile ? 12 : 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: poppinsStyle(
                  fontSize: isSmallMobile ? 11 : 12,
                  color: Colors.grey[600]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      color: AppColors.secondary,
      child: Center(
        child: Text(
          '😊',
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }

  Widget _buildPostingCard(Map<String, dynamic> post, bool isSmallMobile, bool isMobile) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailScreen(
              book: post,
              bookId: post['id'] ?? '',
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isSmallMobile ? 14 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book Title
          Text(
            post['title'] ?? 'Untitled',
            style: poppinsStyle(
              fontSize: isSmallMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Author
          if (post['author'] != null)
            Text(
              'by ${post['author']}',
              style: poppinsStyle(
                fontSize: isSmallMobile ? 13 : 14,
                color: Colors.grey[600]!,
              ),
            ),

          const SizedBox(height: 8),

          // Condition & Genre
          Row(
            children: [
              if (post['condition'] != null) ...[
                _buildTag(post['condition'], isSmallMobile),
                const SizedBox(width: 8),
              ],
              if (post['genre'] != null)
                _buildTag(post['genre'], isSmallMobile),
            ],
          ),

          const SizedBox(height: 8),

          // Description
          if (post['description'] != null && post['description'].toString().isNotEmpty)
            Text(
              post['description'],
              style: poppinsStyle(
                fontSize: isSmallMobile ? 12 : 13,
                color: Colors.grey[700]!,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, bool isSmallMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallMobile ? 8 : 10,
        vertical: isSmallMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: poppinsStyle(
          fontSize: isSmallMobile ? 11 : 12,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
