import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RatingDialog extends StatefulWidget {
  final String ratedUserId; // The user being rated
  final String ratedUserName; // Name of user being rated
  final String bookTitle; // Book involved in transaction
  final String transactionId; // ID of the borrow transaction
  final bool isRatingOwner; // true if rating owner, false if rating borrower

  const RatingDialog({
    Key? key,
    required this.ratedUserId,
    required this.ratedUserName,
    required this.bookTitle,
    required this.transactionId,
    required this.isRatingOwner,
  }) : super(key: key);

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a rating',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final database = FirebaseDatabase.instance;
      
      // Save the rating
      final ratingRef = database.ref('ratings').push();
      final comment = _commentController.text.trim();
      await ratingRef.set({
        'ratedUserId': widget.ratedUserId,
        'raterUserId': currentUser.uid,
        'rating': _rating,
        'comment': comment.isEmpty ? '' : comment,
        'bookTitle': widget.bookTitle,
        'transactionId': widget.transactionId,
        'timestamp': ServerValue.timestamp,
        'type': widget.isRatingOwner ? 'owner' : 'borrower',
      });

      // Update the user's average rating (pass the new rating directly)
      await _updateUserRating(_rating);

      // Mark transaction as rated
      await database.ref('borrows/${widget.transactionId}').update({
        widget.isRatingOwner ? 'ownerRated' : 'borrowerRated': true,
      });

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rating submitted successfully!',
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
              'Error submitting rating: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _updateUserRating(int newRating) async {
    try {
      // Get all ratings for this user from the database
      final ratingsSnapshot = await FirebaseDatabase.instance
          .ref('ratings')
          .get();
      
      double totalRating = 0.0;
      int count = 0;
      
      if (ratingsSnapshot.exists) {
        final data = ratingsSnapshot.value as Map<dynamic, dynamic>;
        
        for (var entry in data.entries) {
          final ratingData = entry.value as Map;
          if (ratingData['ratedUserId'] == widget.ratedUserId) {
            final rating = ratingData['rating'];
            if (rating != null) {
              totalRating += (rating is int ? rating.toDouble() : rating.toDouble());
              count++;
            }
          }
        }
      }
      
      // Calculate average from actual database records
      final newAverage = count > 0 ? totalRating / count : 0.0;
      
      print('DEBUG: Rating calculation - total: $totalRating, count: $count, average: $newAverage');
      
      // Update user's rating with the calculated average
      final userRatingRef = FirebaseDatabase.instance
          .ref('users/${widget.ratedUserId}/rating');
          
      await userRatingRef.set({
        'average': double.parse(newAverage.toStringAsFixed(2)),
        'count': count,
      });
    } catch (e) {
      print('DEBUG: Error updating user rating: $e');
      rethrow; // Re-throw to show error to user
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Text(
                'Rate ${widget.ratedUserName}',
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Book title
              Text(
                'for "${widget.bookTitle}"',
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 13 : 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 24),

              // Star Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
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

              // Comment TextField
              TextField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Add a comment (optional)',
                  labelStyle: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                  hintText: 'Share your experience...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[400],
                  ),
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
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: AppColors.secondary),
                      ),
                      child: Text(
                        'Skip',
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
                      onPressed: _isSubmitting ? null : _submitRating,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Submit',
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

// Helper function to show rating dialog
Future<bool?> showRatingDialog({
  required BuildContext context,
  required String ratedUserId,
  required String ratedUserName,
  required String bookTitle,
  required String transactionId,
  required bool isRatingOwner,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => RatingDialog(
      ratedUserId: ratedUserId,
      ratedUserName: ratedUserName,
      bookTitle: bookTitle,
      transactionId: transactionId,
      isRatingOwner: isRatingOwner,
    ),
  );
}
