import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'book-detail-screen_module.dart' show BookDetailScreen;
import 'error_handler_module.dart';

class BookManagementScreen extends StatefulWidget {
  const BookManagementScreen({Key? key}) : super(key: key);

  @override
  State<BookManagementScreen> createState() => _BookManagementScreenState();
}

class _BookManagementScreenState extends State<BookManagementScreen> {
  List<Map<String, dynamic>> _myBooks = [];
  Set<String> _selectedBooks = {};
  bool _isLoading = true;
  bool _isSelectionMode = false;
  String _selectedTab = 'all'; // all, borrowed, available, reserved

  @override
  void initState() {
    super.initState();
    _loadMyBooks();
  }

  Future<void> _loadMyBooks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('books')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map?;
        if (data != null) {
          final List<Map<String, dynamic>> loadedBooks = [];

          data.forEach((key, value) {
            if (value is Map) {
              final bookData = Map<String, dynamic>.from(value);
              bookData['id'] = key;
              loadedBooks.add(bookData);
            }
          });

          // Sort by createdAt timestamp (newest first)
          loadedBooks.sort((a, b) {
            final aTime = a['createdAt'] ?? 0;
            final bTime = b['createdAt'] ?? 0;
            return bTime.compareTo(aTime);
          });

          if (mounted) {
            setState(() {
              _myBooks = loadedBooks;
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _myBooks = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading books: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshBooks() async {
    try {
      setState(() => _isLoading = true);
      await _loadMyBooks();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorSnackBar(
          context: context,
          message: 'Failed to refresh books',
          onRetry: _refreshBooks,
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBooks {
    if (_selectedTab == 'all') return _myBooks;
    if (_selectedTab == 'borrowed') {
      return _myBooks.where((book) => book['status'] == 'borrowed').toList();
    }
    if (_selectedTab == 'available') {
      return _myBooks.where((book) => book['status'] == 'available' || book['status'] == null).toList();
    }
    if (_selectedTab == 'reserved') {
      return _myBooks.where((book) => book['status'] == 'reserved').toList();
    }
    return _myBooks;
  }

  void _toggleSelection(String bookId) {
    setState(() {
      if (_selectedBooks.contains(bookId)) {
        _selectedBooks.remove(bookId);
        if (_selectedBooks.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedBooks.add(bookId);
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedBooks.clear();
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedBooks = _filteredBooks.map((book) => book['id'] as String).toSet();
    });
  }

  Future<void> _deleteSelectedBooks() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.red,
          size: 48,
        ),
        title: Text(
          'Delete ${_selectedBooks.length} Books',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.secondary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedBooks.length} selected book(s)? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete All',
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
        // Delete all selected books
        for (final bookId in _selectedBooks) {
          await FirebaseDatabase.instance.ref('books/$bookId').remove();
        }

        // Capture count before clearing
        final deletedCount = _selectedBooks.length;

        setState(() {
          _selectedBooks.clear();
          _isSelectionMode = false;
        });

        await _loadMyBooks();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$deletedCount book(s) deleted successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showFirebaseError(
            context: context,
            operation: 'delete books',
            error: e,
            onRetry: _deleteSelectedBooks,
          );
        }
      }
    }
  }

  Future<void> _showBorrowingHistory(String bookId, String bookTitle) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('borrows')
          .orderByChild('bookId')
          .equalTo(bookId)
          .once();

      List<Map<String, dynamic>> history = [];
      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map?;
        if (data != null) {
          data.forEach((key, value) {
            if (value is Map) {
              final borrowData = Map<String, dynamic>.from(value);
              borrowData['id'] = key;
              history.add(borrowData);
            }
          });

          // Sort by timestamp (newest first)
          history.sort((a, b) {
            final aTime = a['requestedAt'] ?? 0;
            final bTime = b['requestedAt'] ?? 0;
            return bTime.compareTo(aTime);
          });
        }
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _BorrowingHistorySheet(
          bookTitle: bookTitle,
          history: history,
        ),
      );
    } catch (e) {
      print('Error loading borrowing history: $e');
    }
  }

  Future<void> _showCurrentBorrower(String bookId, String bookTitle) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('borrows')
          .orderByChild('bookId')
          .equalTo(bookId)
          .once();

      Map<String, dynamic>? currentBorrow;
      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map?;
        if (data != null) {
          data.forEach((key, value) {
            if (value is Map) {
              final borrowData = Map<String, dynamic>.from(value);
              if (borrowData['status'] == 'approved' && borrowData['returned'] != true) {
                borrowData['id'] = key;
                currentBorrow = borrowData;
              }
            }
          });
        }
      }

      if (!mounted) return;

      if (currentBorrow != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Current Borrower',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book: $bookTitle',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person, size: 20, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentBorrow!['borrowerName'] ?? 'Unknown',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Borrowed: ${_formatTimestamp(currentBorrow!['requestedAt'])}',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This book is not currently borrowed',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      print('Error loading current borrower: $e');
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null || timestamp == 0) return 'Unknown';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : 32.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isMobile, horizontalPadding),

            // Stats Cards
            _buildStatsCards(isMobile, horizontalPadding),

            // Filter Tabs
            _buildFilterTabs(isMobile, horizontalPadding),

            // Books List
            Expanded(
              child: _isLoading
                  ? _buildLoadingSkeleton(isSmallMobile, isMobile, horizontalPadding)
                  : _filteredBooks.isEmpty
                      ? _buildEmptyState(isSmallMobile, isMobile)
                      : RefreshIndicator(
                          onRefresh: _refreshBooks,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: isMobile ? 12 : 16,
                            ),
                            itemCount: _filteredBooks.length,
                            itemBuilder: (context, index) {
                              final book = _filteredBooks[index];
                              final bookId = book['id'] as String;
                              final isSelected = _selectedBooks.contains(bookId);
                              return _buildBookCard(
                                book,
                                bookId,
                                isSelected,
                                isSmallMobile,
                                isMobile,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode && _selectedBooks.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _deleteSelectedBooks,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.delete),
              label: Text(
                'Delete ${_selectedBooks.length}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  // Helper function to build image widget that handles both Firebase Storage URLs and base64
  Widget _buildBookImage(String? imageUrl, {required bool isMobile}) {
    final iconSize = isMobile ? 30.0 : 35.0;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return Icon(
        Icons.book,
        size: iconSize,
        color: Colors.grey[600],
      );
    }

    final isUrl = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    
    if (isUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.book,
              size: iconSize,
              color: Colors.grey[600],
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      );
    } else {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(imageUrl),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.book,
                size: iconSize,
                color: Colors.grey[600],
              );
            },
          ),
        );
      } catch (e) {
        return Icon(
          Icons.book,
          size: iconSize,
          color: Colors.grey[600],
        );
      }
    }
  }

  Widget _buildHeader(bool isMobile, double horizontalPadding) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isMobile ? 16 : 20,
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
            onTap: () => Navigator.of(context).pop(),
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
          Expanded(
            child: Text(
              'Book Management',
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ),
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.checklist, color: AppColors.secondary),
              onPressed: _toggleSelectionMode,
              tooltip: 'Select Multiple',
            ),
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: _selectAll,
              child: Text(
                'Select All',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _toggleSelectionMode,
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCards(bool isMobile, double horizontalPadding) {
    final totalBooks = _myBooks.length;
    final borrowedBooks = _myBooks.where((b) => b['status'] == 'borrowed').length;
    final availableBooks = _myBooks.where((b) => b['status'] == 'available' || b['status'] == null).length;
    final reservedBooks = _myBooks.where((b) => b['status'] == 'reserved').length;

    return Container(
      margin: EdgeInsets.all(horizontalPadding),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total',
              totalBooks.toString(),
              Icons.library_books,
              AppColors.secondary,
              isMobile,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: _buildStatCard(
              'Borrowed',
              borrowedBooks.toString(),
              Icons.person,
              Colors.orange,
              isMobile,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: _buildStatCard(
              'Available',
              availableBooks.toString(),
              Icons.check_circle,
              Colors.green,
              isMobile,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: _buildStatCard(
              'Reserved',
              reservedBooks.toString(),
              Icons.bookmark,
              AppColors.primary,
              isMobile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isMobile ? 20 : 24),
          SizedBox(height: isMobile ? 4 : 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 11 : 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(bool isMobile, double horizontalPadding) {
    final tabs = [
      {'key': 'all', 'label': 'All'},
      {'key': 'available', 'label': 'Available'},
      {'key': 'borrowed', 'label': 'Borrowed'},
      {'key': 'reserved', 'label': 'Reserved'},
    ];

    return Container(
      height: isMobile ? 48 : 52,
      margin: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = _selectedTab == tab['key'];
          return Padding(
            padding: EdgeInsets.only(right: isMobile ? 8 : 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = tab['key'] as String),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20,
                  vertical: isMobile ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.grey[200],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  tab['label'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book, String bookId, bool isSelected, bool isSmallMobile, bool isMobile) {
    final title = book['title'] ?? 'Unknown';
    final author = book['author'] ?? 'Unknown Author';
    final status = book['status'] ?? 'available';
    final imageUrl = book['imageUrl'] as String?;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'borrowed':
        statusColor = Colors.orange;
        statusLabel = 'Borrowed';
        statusIcon = Icons.person;
        break;
      case 'reserved':
        statusColor = AppColors.primary;
        statusLabel = 'Reserved';
        statusIcon = Icons.bookmark;
        break;
      default:
        statusColor = Colors.green;
        statusLabel = 'Available';
        statusIcon = Icons.check_circle;
    }

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(bookId);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookDetailScreen(
                book: book,
                bookId: bookId,
              ),
            ),
          );
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedBooks.add(bookId);
          });
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF8F0) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_isSelectionMode) ...[
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(bookId),
                activeColor: AppColors.primary,
              ),
              SizedBox(width: isMobile ? 8 : 12),
            ],
            // Book Cover
            Container(
              width: isMobile ? 60 : 70,
              height: isMobile ? 80 : 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[300],
              ),
              child: _buildBookImage(imageUrl, isMobile: isMobile),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            // Book Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: isSmallMobile ? 14 : (isMobile ? 15 : 16),
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by $author',
                    style: GoogleFonts.poppins(
                      fontSize: isSmallMobile ? 12 : 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Action Menu
            if (!_isSelectionMode)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.secondary),
                onSelected: (value) {
                  if (value == 'history') {
                    _showBorrowingHistory(bookId, title);
                  } else if (value == 'borrower' && status == 'borrowed') {
                    _showCurrentBorrower(bookId, title);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'history',
                    child: Row(
                      children: [
                        const Icon(Icons.history, size: 20, color: AppColors.secondary),
                        const SizedBox(width: 12),
                        Text('Borrowing History', style: GoogleFonts.poppins(fontSize: 14)),
                      ],
                    ),
                  ),
                  if (status == 'borrowed')
                    PopupMenuItem(
                      value: 'borrower',
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 20, color: AppColors.secondary),
                          const SizedBox(width: 12),
                          Text('Current Borrower', style: GoogleFonts.poppins(fontSize: 14)),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isSmallMobile, bool isMobile, double horizontalPadding) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isMobile ? 12 : 16,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Container(
                width: isMobile ? 60 : 70,
                height: isMobile ? 80 : 90,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: isMobile ? 14 : 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: isMobile ? 12 : 14,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: isMobile ? 20 : 24,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isSmallMobile, bool isMobile) {
    String message;
    switch (_selectedTab) {
      case 'borrowed':
        message = 'No borrowed books';
        break;
      case 'available':
        message = 'No available books';
        break;
      case 'reserved':
        message = 'No reserved books';
        break;
      default:
        message = 'No books yet';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: isSmallMobile ? 64 : (isMobile ? 80 : 96),
            color: Colors.grey[400],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: isSmallMobile ? 18 : (isMobile ? 20 : 22),
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

// Borrowing History Bottom Sheet
class _BorrowingHistorySheet extends StatelessWidget {
  final String bookTitle;
  final List<Map<String, dynamic>> history;

  const _BorrowingHistorySheet({
    required this.bookTitle,
    required this.history,
  });

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null || timestamp == 0) return 'Unknown';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getDaysSince(dynamic timestamp) {
    if (timestamp == null || timestamp == 0) return '';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return '1 day ago';
    return '$difference days ago';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Container(
      height: size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Row(
              children: [
                const Icon(Icons.history, color: AppColors.secondary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Borrowing History',
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      Text(
                        bookTitle,
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
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // History List
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: isMobile ? 64 : 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No borrowing history',
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This book hasn\'t been borrowed yet',
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 13 : 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final status = item['status'] ?? 'pending';
                      final returned = item['returned'] == true;
                      final borrowerName = item['borrowerName'] ?? 'Unknown';
                      final requestedAt = item['requestedAt'];

                      Color statusColor;
                      String statusLabel;
                      IconData statusIcon;

                      if (returned) {
                        statusColor = Colors.grey;
                        statusLabel = 'Returned';
                        statusIcon = Icons.check_circle;
                      } else if (status == 'approved') {
                        statusColor = Colors.green;
                        statusLabel = 'Currently Borrowed';
                        statusIcon = Icons.bookmark;
                      } else if (status == 'rejected') {
                        statusColor = Colors.red;
                        statusLabel = 'Rejected';
                        statusIcon = Icons.cancel;
                      } else {
                        statusColor = Colors.orange;
                        statusLabel = 'Pending';
                        statusIcon = Icons.schedule;
                      }

                      return Container(
                        margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(statusIcon, color: statusColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    borrowerName,
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 14 : 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimestamp(requestedAt),
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 12 : 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    _getDaysSince(requestedAt),
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 11 : 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 11 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
