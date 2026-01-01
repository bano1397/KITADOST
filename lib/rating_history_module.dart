import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RatingHistoryScreen extends StatefulWidget {
  const RatingHistoryScreen({Key? key}) : super(key: key);

  @override
  State<RatingHistoryScreen> createState() => _RatingHistoryScreenState();
}

class _RatingHistoryScreenState extends State<RatingHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _givenRatings = [];
  List<Map<String, dynamic>> _receivedRatings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRatings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRatings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final ratingsRef = FirebaseDatabase.instance.ref('ratings');
      final snapshot = await ratingsRef.get();

      List<Map<String, dynamic>> given = [];
      List<Map<String, dynamic>> received = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var entry in data.entries) {
          final ratingId = entry.key;
          final ratingData = Map<String, dynamic>.from(entry.value as Map);
          ratingData['id'] = ratingId;

          // Load user names
          if (ratingData['raterUserId'] != null) {
            final raterSnapshot = await FirebaseDatabase.instance
                .ref('users/${ratingData['raterUserId']}/username')
                .get();
            if (raterSnapshot.exists) {
              ratingData['raterName'] = raterSnapshot.value;
            }
          }

          if (ratingData['ratedUserId'] != null) {
            final ratedSnapshot = await FirebaseDatabase.instance
                .ref('users/${ratingData['ratedUserId']}/username')
                .get();
            if (ratedSnapshot.exists) {
              ratingData['ratedName'] = ratedSnapshot.value;
            }
          }

          // Categorize ratings
          if (ratingData['raterUserId'] == user.uid) {
            given.add(ratingData);
          }
          if (ratingData['ratedUserId'] == user.uid) {
            received.add(ratingData);
          }
        }
      }

      // Sort by timestamp (newest first)
      given.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      received.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

      if (mounted) {
        setState(() {
          _givenRatings = given;
          _receivedRatings = received;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading ratings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editRating(Map<String, dynamic> rating) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditRatingDialog(
        currentRating: rating['rating'] ?? 5,
        currentComment: rating['comment'] ?? '',
        ratedUserName: rating['ratedName'] ?? 'User',
        bookTitle: rating['bookTitle'] ?? '',
      ),
    );

    if (result != null) {
      try {
        // Update rating in Firebase
        await FirebaseDatabase.instance
            .ref('ratings/${rating['id']}')
            .update({
          'rating': result['rating'],
          'comment': result['comment'],
          'updatedAt': ServerValue.timestamp,
        });

        // Recalculate average for rated user
        await _updateUserAverageRating(rating['ratedUserId']);

        // Reload ratings
        await _loadRatings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Rating updated successfully!',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error updating rating: $e',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteRating(Map<String, dynamic> rating) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Rating',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this rating? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete rating from Firebase
        await FirebaseDatabase.instance
            .ref('ratings/${rating['id']}')
            .remove();

        // Recalculate average for rated user
        await _updateUserAverageRating(rating['ratedUserId']);

        // Reload ratings
        await _loadRatings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Rating deleted successfully!',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error deleting rating: $e',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _updateUserAverageRating(String userId) async {
    try {
      final ratingsRef = FirebaseDatabase.instance.ref('ratings');
      final snapshot = await ratingsRef
          .orderByChild('ratedUserId')
          .equalTo(userId)
          .get();

      double totalRating = 0;
      int count = 0;

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final rating = value['rating'];
          if (rating != null) {
            totalRating += rating.toDouble();
            count++;
          }
        });
      }

      final average = count > 0 ? totalRating / count : 0.0;

      await FirebaseDatabase.instance
          .ref('users/$userId/rating')
          .set({
        'average': double.parse(average.toStringAsFixed(2)),
        'count': count,
      });
    } catch (e) {
      print('Error updating user average: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

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
          'Rating History',
          style: GoogleFonts.poppins(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.w600,
            color: AppColors.secondary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.poppins(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            Tab(text: 'Given (${_givenRatings.length})'),
            Tab(text: 'Received (${_receivedRatings.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRatingsList(_givenRatings, isGiven: true, isMobile: isMobile),
                _buildRatingsList(_receivedRatings, isGiven: false, isMobile: isMobile),
              ],
            ),
    );
  }

  Widget _buildRatingsList(List<Map<String, dynamic>> ratings, {required bool isGiven, required bool isMobile}) {
    if (ratings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_border,
              size: isMobile ? 64 : 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isGiven ? 'No ratings given yet' : 'No ratings received yet',
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 16 : 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRatings,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        itemCount: ratings.length,
        itemBuilder: (context, index) {
          return _buildRatingCard(ratings[index], isGiven: isGiven, isMobile: isMobile);
        },
      ),
    );
  }

  Widget _buildRatingCard(Map<String, dynamic> rating, {required bool isGiven, required bool isMobile}) {
    final stars = rating['rating'] ?? 0;
    final comment = rating['comment'] ?? '';
    final bookTitle = rating['bookTitle'] ?? 'Unknown Book';
    final userName = isGiven ? (rating['ratedName'] ?? 'User') : (rating['raterName'] ?? 'User');
    final timestamp = rating['timestamp'] ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final dateStr = '${date.day}/${date.month}/${date.year}';

    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
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
                        isGiven ? 'Rated $userName' : 'From $userName',
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'for "$bookTitle"',
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 13 : 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isGiven)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editRating(rating);
                      } else if (value == 'delete') {
                        _deleteRating(rating);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 20, color: AppColors.secondary),
                            const SizedBox(width: 12),
                            Text('Edit', style: GoogleFonts.poppins(fontSize: 14)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete, size: 20, color: Colors.red),
                            const SizedBox(width: 12),
                            Text('Delete', style: GoogleFonts.poppins(fontSize: 14, color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Stars
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < stars ? Icons.star : Icons.star_border,
                  size: isMobile ? 20 : 24,
                  color: AppColors.primary,
                );
              }),
            ),
            
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  comment,
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 13 : 14,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Date
            Row(
              children: [
                Icon(Icons.calendar_today, size: isMobile ? 14 : 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.grey[600],
                  ),
                ),
                if (rating['updatedAt'] != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(edited)',
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Edit Rating Dialog
class EditRatingDialog extends StatefulWidget {
  final int currentRating;
  final String currentComment;
  final String ratedUserName;
  final String bookTitle;

  const EditRatingDialog({
    Key? key,
    required this.currentRating,
    required this.currentComment,
    required this.ratedUserName,
    required this.bookTitle,
  }) : super(key: key);

  @override
  State<EditRatingDialog> createState() => _EditRatingDialogState();
}

class _EditRatingDialogState extends State<EditRatingDialog> {
  late int _rating;
  late TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _rating = widget.currentRating;
    _commentController = TextEditingController(text: widget.currentComment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Edit Rating',
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'for ${widget.ratedUserName}',
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.grey[600],
                ),
              ),
              if (widget.bookTitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '"${widget.bookTitle}"',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 13 : 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 24),
              
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = index + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        index < _rating ? Icons.star : Icons.star_border,
                        size: isMobile ? 40 : 48,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }),
              ),
              
              if (_rating > 0) ...[
                const SizedBox(height: 8),
                Text(
                  _getRatingText(_rating),
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondary,
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Comment
              TextField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Comment (optional)',
                  labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                  hintText: 'Share your experience...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.secondary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: GoogleFonts.poppins(fontSize: isMobile ? 14 : 15),
              ),
              
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: AppColors.secondary),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 15 : 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'rating': _rating,
                          'comment': _commentController.text.trim(),
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 15 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}
