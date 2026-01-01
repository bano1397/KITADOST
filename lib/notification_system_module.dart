import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'message_module.dart' show ChatScreen;
import 'my-postings_module.dart' show PostingsScreen;

class NotificationSystemModule {
  static final NotificationSystemModule _instance = NotificationSystemModule._internal();
  factory NotificationSystemModule() => _instance;
  NotificationSystemModule._internal();

  final DatabaseReference _notificationsRef = FirebaseDatabase.instance.ref('notifications');

  // Notification types
  static const String typeBorrowRequest = 'borrow_request';
  static const String typeRequestApproved = 'request_approved';
  static const String typeRequestRejected = 'request_rejected';
  static const String typeMessageReceived = 'message_received';
  static const String typeReturnReminder = 'return_reminder';

  // Create a new notification
  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notificationRef = _notificationsRef.child(userId).push();
      await notificationRef.set({
        'id': notificationRef.key,
        'type': type,
        'title': title,
        'message': message,
        'data': data ?? {},
        'read': false,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _notificationsRef.child(userId).child(notificationId).update({
        'read': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _notificationsRef.child(userId).once();
      if (snapshot.snapshot.exists) {
        final notifications = snapshot.snapshot.value as Map?;
        if (notifications != null) {
          final updates = <String, dynamic>{};
          notifications.forEach((key, value) {
            updates['$key/read'] = true;
          });
          await _notificationsRef.child(userId).update(updates);
        }
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Delete a notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _notificationsRef.child(userId).child(notificationId).remove();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Delete all notifications
  Future<void> deleteAllNotifications(String userId) async {
    try {
      await _notificationsRef.child(userId).remove();
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }

  // Get unread notification count stream
  Stream<int> getUnreadCountStream(String userId) {
    return _notificationsRef
        .child(userId)
        .orderByChild('read')
        .equalTo(false)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return 0;
      final notifications = event.snapshot.value as Map?;
      return notifications?.length ?? 0;
    });
  }

  // Helper methods for specific notification types

  Future<void> notifyBorrowRequest({
    required String ownerId,
    required String requesterName,
    required String bookTitle,
    required String requestId,
  }) async {
    await createNotification(
      userId: ownerId,
      type: typeBorrowRequest,
      title: 'New Borrow Request',
      message: '$requesterName wants to borrow "$bookTitle"',
      data: {
        'requestId': requestId,
        'requesterName': requesterName,
        'bookTitle': bookTitle,
      },
    );
  }

  Future<void> notifyRequestApproved({
    required String requesterId,
    required String bookTitle,
    required String ownerName,
    required String requestId,
  }) async {
    await createNotification(
      userId: requesterId,
      type: typeRequestApproved,
      title: 'Request Approved! 🎉',
      message: 'Your request to borrow "$bookTitle" from $ownerName was approved',
      data: {
        'requestId': requestId,
        'bookTitle': bookTitle,
        'ownerName': ownerName,
      },
    );
  }

  Future<void> notifyRequestRejected({
    required String requesterId,
    required String bookTitle,
    required String ownerName,
    required String requestId,
  }) async {
    await createNotification(
      userId: requesterId,
      type: typeRequestRejected,
      title: 'Request Declined',
      message: 'Your request to borrow "$bookTitle" from $ownerName was declined',
      data: {
        'requestId': requestId,
        'bookTitle': bookTitle,
        'ownerName': ownerName,
      },
    );
  }

  Future<void> notifyMessageReceived({
    required String recipientId,
    required String senderName,
    required String messagePreview,
    required String chatId,
  }) async {
    await createNotification(
      userId: recipientId,
      type: typeMessageReceived,
      title: 'New Message from $senderName',
      message: messagePreview,
      data: {
        'chatId': chatId,
        'senderName': senderName,
      },
    );
  }

  Future<void> notifyReturnReminder({
    required String borrowerId,
    required String bookTitle,
    required String ownerName,
    required int daysOverdue,
  }) async {
    await createNotification(
      userId: borrowerId,
      type: typeReturnReminder,
      title: 'Book Return Reminder',
      message: daysOverdue > 0
          ? 'Your borrowed book "$bookTitle" is $daysOverdue days overdue'
          : 'Please remember to return "$bookTitle" to $ownerName',
      data: {
        'bookTitle': bookTitle,
        'ownerName': ownerName,
        'daysOverdue': daysOverdue,
      },
    );
  }
}

// Notifications Screen Widget
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationSystemModule _notificationSystem = NotificationSystemModule();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _filter = 'All';
  final List<String> _filters = ['All', 'Unread', 'Requests', 'Messages'];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    FirebaseDatabase.instance
        .ref('notifications/${user.uid}')
        .orderByChild('timestamp')
        .onValue
        .listen((event) {
      if (!mounted) return;

      final List<Map<String, dynamic>> loadedNotifications = [];
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map?;
        if (data != null) {
          data.forEach((key, value) {
            if (value is Map) {
              final notification = Map<String, dynamic>.from(value);
              notification['id'] = key;
              loadedNotifications.add(notification);
            }
          });
        }
      }

      // Sort by timestamp (newest first)
      loadedNotifications.sort((a, b) {
        final aTime = a['timestamp'] ?? 0;
        final bTime = b['timestamp'] ?? 0;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _notifications = loadedNotifications;
          _isLoading = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_filter == 'All') return _notifications;
    if (_filter == 'Unread') {
      return _notifications.where((n) => n['read'] == false).toList();
    }
    if (_filter == 'Requests') {
      return _notifications.where((n) {
        final type = n['type'] ?? '';
        return type.contains('request') || type.contains('borrow');
      }).toList();
    }
    if (_filter == 'Messages') {
      return _notifications.where((n) => n['type'] == NotificationSystemModule.typeMessageReceived).toList();
    }
    return _notifications;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : 32.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isMobile, horizontalPadding),

            // Filters
            _buildFilters(isMobile, horizontalPadding),

            // Notifications List
            Expanded(
              child: _isLoading
                  ? _buildLoadingSkeleton(isSmallMobile, isMobile, horizontalPadding)
                  : _filteredNotifications.isEmpty
                      ? _buildEmptyState(isSmallMobile, isMobile)
                      : RefreshIndicator(
                          onRefresh: _refreshNotifications,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: isMobile ? 12 : 16,
                            ),
                            itemCount: _filteredNotifications.length,
                            itemBuilder: (context, index) {
                              return _buildNotificationCard(
                                _filteredNotifications[index],
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
    );
  }

  Future<void> _refreshNotifications() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Widget _buildHeader(bool isMobile, double horizontalPadding) {
    final unreadCount = _notifications.where((n) => n['read'] == false).length;

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
              'Notifications',
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$unreadCount',
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          SizedBox(width: isMobile ? 8 : 12),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.secondary),
            onSelected: (value) async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              if (value == 'mark_all_read') {
                await _notificationSystem.markAllAsRead(user.uid);
              } else if (value == 'delete_all') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Delete All Notifications',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    content: Text(
                      'Are you sure you want to delete all notifications?',
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
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _notificationSystem.deleteAllNotifications(user.uid);
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    const Icon(Icons.done_all, size: 20, color: AppColors.secondary),
                    const SizedBox(width: 12),
                    Text('Mark all as read', style: GoogleFonts.poppins(fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    const SizedBox(width: 12),
                    Text('Delete all', style: GoogleFonts.poppins(fontSize: 14, color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isMobile, double horizontalPadding) {
    return Container(
      height: isMobile ? 50 : 56,
      margin: EdgeInsets.only(top: isMobile ? 12 : 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _filter == filter;
          return Padding(
            padding: EdgeInsets.only(right: isMobile ? 8 : 12),
            child: GestureDetector(
              onTap: () => setState(() => _filter = filter),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20,
                  vertical: isMobile ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.grey[200],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['type'] ?? '';
    final data = notification['data'] as Map<dynamic, dynamic>?;

    if (!mounted) return;

    switch (type) {
      case NotificationSystemModule.typeMessageReceived:
        // Navigate to chat screen
        if (data != null && data['chatId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: data['chatId'],
                chatName: data['senderName'] ?? 'Chat',
                isSystemChat: false,
              ),
            ),
          );
        }
        break;

      case NotificationSystemModule.typeBorrowRequest:
      case NotificationSystemModule.typeRequestApproved:
      case NotificationSystemModule.typeRequestRejected:
        // Navigate to My Postings screen (Requests tab)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PostingsScreen(),
          ),
        );
        break;

      case NotificationSystemModule.typeReturnReminder:
        // Could navigate to borrowed books or transaction history
        // For now, just mark as read (already done in onTap)
        break;

      default:
        // Unknown notification type, just mark as read
        break;
    }
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, bool isSmallMobile, bool isMobile) {
    final isRead = notification['read'] == true;
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? '';
    final message = notification['message'] ?? '';
    final timestamp = notification['timestamp'] ?? 0;
    final notificationId = notification['id'] ?? '';

    IconData icon;
    Color iconColor;

    switch (type) {
      case NotificationSystemModule.typeBorrowRequest:
        icon = Icons.library_books;
        iconColor = const Color(0xFF4A90E2);
        break;
      case NotificationSystemModule.typeRequestApproved:
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case NotificationSystemModule.typeRequestRejected:
        icon = Icons.cancel;
        iconColor = Colors.red;
        break;
      case NotificationSystemModule.typeMessageReceived:
        icon = Icons.message;
        iconColor = AppColors.primary;
        break;
      case NotificationSystemModule.typeReturnReminder:
        icon = Icons.alarm;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.notifications;
        iconColor = AppColors.secondary;
    }

    return Dismissible(
      key: Key(notificationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: isMobile ? 20 : 24),
        margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _notificationSystem.deleteNotification(user.uid, notificationId);
        }
      },
      child: GestureDetector(
        onTap: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && !isRead) {
            await _notificationSystem.markAsRead(user.uid, notificationId);
          }
          
          // Navigate based on notification type
          _handleNotificationTap(notification);
        },
        child: Container(
          margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead ? Colors.grey[300]! : AppColors.primary.withOpacity(0.3),
              width: 1,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: isMobile ? 20 : 24),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: isSmallMobile ? 13 : (isMobile ? 14 : 15),
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: GoogleFonts.poppins(
                        fontSize: isSmallMobile ? 12 : (isMobile ? 13 : 14),
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTimestamp(timestamp),
                      style: GoogleFonts.poppins(
                        fontSize: isSmallMobile ? 10 : (isMobile ? 11 : 12),
                        color: Colors.grey[500],
                      ),
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

  Widget _buildLoadingSkeleton(bool isSmallMobile, bool isMobile, double horizontalPadding) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isMobile ? 12 : 16,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Container(
                width: isMobile ? 40 : 44,
                height: isMobile ? 40 : 44,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
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
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: isMobile ? 10 : 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: isSmallMobile ? 64 : (isMobile ? 80 : 96),
            color: Colors.grey[400],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Text(
            _filter == 'All' ? 'No notifications yet' : 'No $_filter notifications',
            style: GoogleFonts.poppins(
              fontSize: isSmallMobile ? 18 : (isMobile ? 20 : 22),
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 40 : 60),
            child: Text(
              'You\'ll see notifications about borrow requests, messages, and more here',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: isSmallMobile ? 13 : (isMobile ? 14 : 15),
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null || timestamp == 0) return 'Just now';

    final now = DateTime.now();
    final notificationTime = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    final difference = now.difference(notificationTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${notificationTime.day}/${notificationTime.month}/${notificationTime.year}';
    }
  }
}
