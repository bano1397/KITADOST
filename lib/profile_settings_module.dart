import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'error_handler_module.dart';
import 'rating_history_module.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // User data
  String _userBio = '';
  double _userRating = 0.0;
  int _totalRatings = 0;
  bool _isLoading = true;
  
  // Privacy settings
  bool _showEmail = true;
  bool _showPhone = false;
  bool _allowMessages = true;
  bool _showBorrowHistory = true;
  
  // Transaction history
  List<Map<String, dynamic>> _transactions = [];
  
  final TextEditingController _bioController = TextEditingController();
  bool _isEditingBio = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserData();
    _loadTransactionHistory();
    _ensureEmailInDatabase();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      print('DEBUG: Fetching user data for UID: ${user.uid}');
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}')
          .once();

      print('DEBUG: Snapshot exists: ${snapshot.snapshot.exists}');
      if (snapshot.snapshot.value != null) {
        print('DEBUG: Snapshot value type: ${snapshot.snapshot.value.runtimeType}');
      }

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map?;
        if (data != null) {
          print('DEBUG: User data exists, checking fields...');

          // Check if essential fields are missing and initialize them
          bool needsUpdate = false;
          if (!data.containsKey('bio') || !data.containsKey('rating') || !data.containsKey('privacy')) {
            print('DEBUG: User data exists but missing essential fields, updating...');
            needsUpdate = true;
          }

          if (needsUpdate) {
            // Update existing user data with missing fields
            await _updateUserDataFields(user);

            // Reload data after update to get the updated values
            print('DEBUG: Reloading data after update...');
            final updatedSnapshot = await FirebaseDatabase.instance
                .ref('users/${user.uid}')
                .once();

            if (updatedSnapshot.snapshot.exists) {
              final updatedData = updatedSnapshot.snapshot.value as Map?;
              if (updatedData != null && mounted) {
                // Get actual rating data from database
                final ratingData = await _getActualRatingData(user.uid);
                
                setState(() {
                  _userBio = updatedData['bio']?.toString() ?? '';
                  _userRating = ratingData['average'];
                  _totalRatings = ratingData['count'];
                  _showEmail = updatedData['privacy']?['showEmail'] ?? true;
                  _showPhone = updatedData['privacy']?['showPhone'] ?? false;
                  _allowMessages = updatedData['privacy']?['allowMessages'] ?? true;
                  _showBorrowHistory = updatedData['privacy']?['showBorrowHistory'] ?? true;
                  _bioController.text = _userBio;
                  _isLoading = false;
                });
              }
            }
          } else if (mounted) {
            // Data is complete, just load it
            // Get actual rating data from database
            final ratingData = await _getActualRatingData(user.uid);
            
            setState(() {
              _userBio = data['bio']?.toString() ?? '';
              _userRating = ratingData['average'];
              _totalRatings = ratingData['count'];
              _showEmail = data['privacy']?['showEmail'] ?? true;
              _showPhone = data['privacy']?['showPhone'] ?? false;
              _allowMessages = data['privacy']?['allowMessages'] ?? true;
              _showBorrowHistory = data['privacy']?['showBorrowHistory'] ?? true;
              _bioController.text = _userBio;
              _isLoading = false;
            });
          }
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      } else {
        // User data doesn't exist yet - initialize it
        print('DEBUG: User data does not exist, creating new entry...');
        await _initializeUserData(user);
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e, stackTrace) {
      print('DEBUG: Error loading user data: $e');
      print('DEBUG: Stack trace: $stackTrace');
      print('DEBUG: Error type: ${e.runtimeType}');
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showFirebaseError(
          context: context,
          operation: 'load user data',
          error: e,
          onRetry: _loadUserData,
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getActualRatingData(String userId) async {
    try {
      final ratingsSnapshot = await FirebaseDatabase.instance
          .ref('ratings')
          .get();
      
      if (!ratingsSnapshot.exists) return {'average': 0.0, 'count': 0};
      
      final data = ratingsSnapshot.value as Map<dynamic, dynamic>;
      double totalRating = 0.0;
      int count = 0;
      
      for (var entry in data.entries) {
        final ratingData = entry.value as Map;
        if (ratingData['ratedUserId'] == userId) {
          final rating = ratingData['rating'];
          if (rating != null) {
            totalRating += (rating is int ? rating.toDouble() : rating.toDouble());
            count++;
          }
        }
      }
      
      final average = count > 0 ? totalRating / count : 0.0;
      
      return {
        'average': double.parse(average.toStringAsFixed(2)),
        'count': count,
      };
    } catch (e) {
      print('DEBUG: Error getting rating data: $e');
      return {'average': 0.0, 'count': 0};
    }
  }

  Future<void> _updateUserDataFields(User user) async {
    try {
      print('DEBUG: Updating missing user data fields for ${user.uid}');

      // Update only the missing fields, preserving existing data
      await FirebaseDatabase.instance.ref('users/${user.uid}').update({
        'bio': '',
        'rating': 0.0,
        'totalRatings': 0,
        'privacy': {
          'showEmail': true,
          'showPhone': false,
          'allowMessages': true,
          'showBorrowHistory': true,
        },
      });
      print('DEBUG: User data fields updated successfully');
    } catch (e, stackTrace) {
      print('DEBUG: Error updating user data fields: $e');
      print('DEBUG: Stack trace: $stackTrace');
      // Don't rethrow - this is not critical
    }
  }

  Future<void> _initializeUserData(User user) async {
    try {
      print('DEBUG: Initializing user data for ${user.uid}');
      print('DEBUG: User email: ${user.email}');

      // Initialize user node with default values
      await FirebaseDatabase.instance.ref('users/${user.uid}').set({
        'email': user.email ?? '',
        'username': user.displayName ?? '',
        'uid': user.uid,
        'bio': '',
        'rating': 0.0,
        'totalRatings': 0,
        'privacy': {
          'showEmail': true,
          'showPhone': false,
          'allowMessages': true,
          'showBorrowHistory': true,
        },
        'createdAt': ServerValue.timestamp,
      });
      print('DEBUG: User data initialized successfully for ${user.uid}');

      // Update local state with initialized data
      if (mounted) {
        setState(() {
          _userBio = '';
          _userRating = 0.0;
          _totalRatings = 0;
          _showEmail = true;
          _showPhone = false;
          _allowMessages = true;
          _showBorrowHistory = true;
          _bioController.text = '';
        });
      }
    } catch (e, stackTrace) {
      print('DEBUG: Error initializing user data: $e');
      print('DEBUG: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _ensureEmailInDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    try {
      // Check if email exists in database
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/email')
          .once();

      if (!snapshot.snapshot.exists) {
        // Email not in database, save it
        await FirebaseDatabase.instance
            .ref('users/${user.uid}')
            .update({'email': user.email});
        print('DEBUG: Email saved to database: ${user.email}');
      }
    } catch (e) {
      print('DEBUG: Error ensuring email in database: $e');
    }
  }

  Future<void> _saveBio() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseDatabase.instance
          .ref('users/${user.uid}')
          .update({'bio': _bioController.text});

      if (mounted) {
        ErrorHandler.showSuccessSnackBar(
          context: context,
          message: 'Bio updated successfully',
        );
        setState(() {
          _userBio = _bioController.text;
          _isEditingBio = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showFirebaseError(
          context: context,
          operation: 'save bio',
          error: e,
          onRetry: _saveBio,
        );
      }
    }
  }

  Future<void> _savePrivacySettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/privacy')
          .set({
        'showEmail': _showEmail,
        'showPhone': _showPhone,
        'allowMessages': _allowMessages,
        'showBorrowHistory': _showBorrowHistory,
      });

      if (mounted) {
        ErrorHandler.showSuccessSnackBar(
          context: context,
          message: 'Privacy settings updated',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showFirebaseError(
          context: context,
          operation: 'save privacy settings',
          error: e,
          onRetry: _savePrivacySettings,
        );
      }
    }
  }

  Future<void> _loadTransactionHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Load borrow history as borrower
      final borrowSnapshot = await FirebaseDatabase.instance
          .ref('borrows')
          .orderByChild('userId')
          .equalTo(user.uid)
          .once();

      // Load borrow history as lender
      final lendSnapshot = await FirebaseDatabase.instance
          .ref('borrows')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .once();

      List<Map<String, dynamic>> transactions = [];

      if (borrowSnapshot.snapshot.exists) {
        final data = borrowSnapshot.snapshot.value as Map?;
        if (data != null) {
          data.forEach((key, value) {
            if (value is Map) {
              final transaction = Map<String, dynamic>.from(value);
              transaction['id'] = key;
              transaction['type'] = 'borrowed';
              transactions.add(transaction);
            }
          });
        }
      }

      if (lendSnapshot.snapshot.exists) {
        final data = lendSnapshot.snapshot.value as Map?;
        if (data != null) {
          data.forEach((key, value) {
            if (value is Map) {
              final transaction = Map<String, dynamic>.from(value);
              transaction['id'] = key;
              transaction['type'] = 'lent';
              transactions.add(transaction);
            }
          });
        }
      }

      // Sort by timestamp
      transactions.sort((a, b) {
        final aTime = a['timestamp'] ?? 0;
        final bTime = b['timestamp'] ?? 0;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _transactions = transactions;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showFirebaseError(
          context: context,
          operation: 'load transaction history',
          error: e,
          onRetry: _loadTransactionHistory,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : 28.0);
    final titleFontSize = isSmallMobile ? 24.0 : (isMobile ? 26.0 : 28.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: EdgeInsets.all(isSmallMobile ? 8 : 10),
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: isSmallMobile ? 20 : 24,
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallMobile ? 16 : 20),
                  Text(
                    'Profile & Settings',
                    style: GoogleFonts.poppins(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              height: 48,
              margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
              decoration: BoxDecoration(
                color: const Color(0xFFD4DCE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.secondary,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: GoogleFonts.poppins(
                  fontSize: isSmallMobile ? 11 : 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: isSmallMobile ? 11 : 13,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Bio'),
                  Tab(text: 'Rating'),
                  Tab(text: 'History'),
                  Tab(text: 'Privacy'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildBioTab(),
                          _buildRatingTab(),
                          _buildHistoryTab(),
                          _buildPrivacyTab(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBioTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(
            'About You',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            readOnly: !_isEditingBio,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Tell others about yourself, your reading interests, favorite genres...',
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              filled: true,
              fillColor: _isEditingBio ? Colors.grey[50] : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditingBio = !_isEditingBio;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: _isEditingBio ? Colors.grey : AppColors.secondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isEditingBio ? 'Cancel' : 'Edit Bio',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isEditingBio ? Colors.grey : AppColors.secondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isEditingBio ? _saveBio : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditingBio ? AppColors.secondary : Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Bio',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
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
        );
      },
    );
  }

  Widget _buildRatingTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 40,
            ),
            child: Column(
              children: [
          // Rating Display
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.secondary, Color(0xFF4A90E2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Your Rating',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _userRating.toStringAsFixed(1),
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star, color: Colors.amber, size: 36),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on $_totalRatings rating${_totalRatings != 1 ? 's' : ''}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RatingHistoryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history, size: 20),
                  label: Text(
                    'View Rating History',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Rating Breakdown
          _buildRatingInfo(
            icon: Icons.book,
            title: 'Book Condition Accuracy',
            description: 'How accurately you describe your books',
          ),
          const SizedBox(height: 16),
          _buildRatingInfo(
            icon: Icons.access_time,
            title: 'Punctuality',
            description: 'On-time returns and pickups',
          ),
          const SizedBox(height: 16),
          _buildRatingInfo(
            icon: Icons.chat,
            title: 'Communication',
            description: 'Response time and clarity',
          ),
          const SizedBox(height: 16),
          _buildRatingInfo(
            icon: Icons.verified_user,
            title: 'Trustworthiness',
            description: 'Overall reliability and honesty',
          ),
        ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRatingInfo({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.secondary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_transactions.isEmpty) {
          return SizedBox(
            height: constraints.maxHeight,
            child: ErrorHandler.buildEmptyWidget(
              message: 'No transaction history yet',
              icon: Icons.history,
            ),
          );
        }

        return RefreshIndicator(
      onRefresh: _loadTransactionHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          final isBorrowed = transaction['type'] == 'borrowed';
          final status = transaction['status'] ?? 'pending';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isBorrowed 
                            ? Colors.blue.withOpacity(0.1) 
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isBorrowed ? Icons.download : Icons.upload,
                        color: isBorrowed ? Colors.blue : Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction['bookTitle'] ?? 'Unknown Book',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isBorrowed 
                                ? 'Borrowed from ${transaction['ownerName'] ?? 'Unknown'}' 
                                : 'Lent to ${transaction['borrowerName'] ?? 'Unknown'}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(transaction),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'approved':
        bgColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        label = 'Approved';
        break;
      case 'rejected':
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        label = 'Rejected';
        break;
      case 'returned':
        bgColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        label = 'Returned';
        break;
      default:
        bgColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildPrivacyTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(
            'Privacy Settings',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Control what information others can see',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          _buildPrivacySwitch(
            title: 'Show Email Address',
            subtitle: 'Let others see your email',
            value: _showEmail,
            onChanged: (value) {
              setState(() => _showEmail = value);
              _savePrivacySettings();
            },
          ),
          
          _buildPrivacySwitch(
            title: 'Show Phone Number',
            subtitle: 'Display your phone number on profile',
            value: _showPhone,
            onChanged: (value) {
              setState(() => _showPhone = value);
              _savePrivacySettings();
            },
          ),
          
          _buildPrivacySwitch(
            title: 'Allow Direct Messages',
            subtitle: 'Let other users send you messages',
            value: _allowMessages,
            onChanged: (value) {
              setState(() => _allowMessages = value);
              _savePrivacySettings();
            },
          ),
          
          _buildPrivacySwitch(
            title: 'Show Borrow History',
            subtitle: 'Display your borrowing activity',
            value: _showBorrowHistory,
            onChanged: (value) {
              setState(() => _showBorrowHistory = value);
              _savePrivacySettings();
            },
          ),
          
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your privacy is important. These settings help you control your visibility.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacySwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic transactionData) {
    // Try different timestamp fields
    dynamic timestamp;
    
    if (transactionData is Map) {
      timestamp = transactionData['returnedAt'] ?? 
                  transactionData['approvedAt'] ?? 
                  transactionData['requestedAt'] ?? 
                  transactionData['timestamp'];
    } else {
      timestamp = transactionData;
    }
    
    if (timestamp == null) return 'Unknown date';
    
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(
        timestamp is int ? timestamp : int.parse(timestamp.toString()),
      );
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown date';
    }
  }
}
