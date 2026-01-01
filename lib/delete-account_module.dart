import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'get_started_module.dart';

class DeleteAccountModule {
  static Future<void> showDeleteAccountDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _DeleteAccountDialog();
      },
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  @override
  _DeleteAccountDialogState createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  int _countdown = 10;
  Timer? _timer;
  bool _canDelete = false;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        setState(() {
          _canDelete = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _confirmDeleteAccount() async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Delete user data from Realtime Database
      try {
        await FirebaseDatabase.instance
            .ref('users/${user.uid}')
            .remove();
        print('DEBUG: User data deleted from Realtime Database');
      } catch (e) {
        print('DEBUG: Error deleting Realtime Database data: $e');
        // Continue even if database deletion fails
      }

      // Delete the user account
      await user.delete();
      print('DEBUG: User account deleted successfully');

      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog
        
        // Navigate to Get Started page
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const BookNestScreen(),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException: ${e.code}');
      
      setState(() {
        _isDeleting = false;
        if (e.code == 'requires-recent-login') {
          _errorMessage = 'For security, please log out and log back in, then try again.';
        } else {
          _errorMessage = 'Error: ${e.message}';
        }
      });
    } catch (e) {
      print('DEBUG: Error deleting account: $e');
      
      setState(() {
        _isDeleting = false;
        _errorMessage = 'An error occurred. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildCountdownDialog(context);
  }

  Widget _buildCountdownDialog(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    // Responsive breakpoints
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    
    // Responsive sizing
    final titleFontSize = isSmallMobile ? 20.0 : (isMobile ? 24.0 : 28.0);
    final bodyFontSize = isSmallMobile ? 14.0 : (isMobile ? 16.0 : 18.0);
    final timerIconSize = isSmallMobile ? 20.0 : (isMobile ? 24.0 : 28.0);
    final timerFontSize = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    final warningIconSize = isSmallMobile ? 18.0 : (isMobile ? 20.0 : 22.0);
    final warningFontSize = isSmallMobile ? 11.0 : (isMobile ? 12.0 : 13.0);
    final buttonFontSize = isSmallMobile ? 14.0 : (isMobile ? 16.0 : 18.0);
    final buttonPaddingH = isSmallMobile ? 20.0 : (isMobile ? 24.0 : 28.0);
    final buttonPaddingV = isSmallMobile ? 10.0 : (isMobile ? 12.0 : 14.0);
    final spacing = isSmallMobile ? 16.0 : (isMobile ? 20.0 : 24.0);
    final containerPadding = isSmallMobile ? 12.0 : (isMobile ? 16.0 : 20.0);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      title: Text(
        'Delete Account',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: AppColors.secondary,
          fontSize: titleFontSize,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Are you sure you want to delete your account?',
            style: GoogleFonts.poppins(
              fontSize: bodyFontSize,
              color: Colors.grey[700],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing),
          if (!_canDelete)
            Container(
              padding: EdgeInsets.all(containerPadding),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: AppColors.primary,
                    size: timerIconSize,
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Text(
                    '$_countdown seconds',
                    style: GoogleFonts.poppins(
                      fontSize: timerFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          if (_canDelete)
            Container(
              padding: EdgeInsets.all(containerPadding),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: Colors.red.shade700,
                    size: warningIconSize,
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Flexible(
                    child: Text(
                      'This action cannot be undone',
                      style: GoogleFonts.poppins(
                        fontSize: warningFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_errorMessage != null)
             Padding(
               padding: EdgeInsets.only(top: spacing),
               child: Text(
                 _errorMessage!,
                 style: GoogleFonts.poppins(
                   fontSize: warningFontSize,
                   color: Colors.red,
                 ),
                 textAlign: TextAlign.center,
               ),
             ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting
              ? null
              : () {
            Navigator.of(context).pop(); // Close the dialog
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: buttonPaddingH, vertical: buttonPaddingV),
          ),
          child: Text(
            'No',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: buttonFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _canDelete
              ? () {
                  _confirmDeleteAccount();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _canDelete ? (_isDeleting ? Colors.grey[400] : Colors.red) : Colors.grey[400],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: buttonPaddingH, vertical: buttonPaddingV),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            disabledBackgroundColor: Colors.grey[400],
            disabledForegroundColor: Colors.white,
          ),
          child: _isDeleting
              ? SizedBox(
                  width: isSmallMobile ? 18 : 20,
                  height: isSmallMobile ? 18 : 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Yes',
                  style: GoogleFonts.poppins(
                    fontSize: buttonFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

}