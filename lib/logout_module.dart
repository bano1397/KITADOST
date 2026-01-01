import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'get_started_module.dart';

class LogoutModule {
  static Future<void> showLogoutDialog(BuildContext context) async {
    // Get screen size and define responsive breakpoints
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    
    // Responsive sizing variables
    final dialogBorderRadius = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    final titleFontSize = isSmallMobile ? 20.0 : (isMobile ? 22.0 : (isTablet ? 24.0 : 26.0));
    final contentFontSize = isSmallMobile ? 14.0 : (isMobile ? 15.0 : (isTablet ? 16.0 : 17.0));
    final buttonFontSize = isSmallMobile ? 14.0 : (isMobile ? 15.0 : (isTablet ? 16.0 : 17.0));
    final buttonPaddingH = isSmallMobile ? 20.0 : (isMobile ? 22.0 : (isTablet ? 24.0 : 28.0));
    final buttonPaddingV = isSmallMobile ? 10.0 : (isMobile ? 11.0 : (isTablet ? 12.0 : 13.0));
    final buttonBorderRadius = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dialogBorderRadius),
          ),
          backgroundColor: Colors.white,
          title: Text(
            'Log Out',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
              fontSize: titleFontSize,
            ),
          ),
          content: Text(
            'Are you sure you want to log out?',
            style: GoogleFonts.poppins(
              fontSize: contentFontSize,
              color: Colors.grey,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: buttonPaddingH,
                  vertical: buttonPaddingV,
                ),
              ),
              child: Text(
                'No',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontSize: buttonFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  print('DEBUG: Logging out user...');
                  
                  // Sign out from Firebase
                  await FirebaseAuth.instance.signOut();
                  print('DEBUG: User signed out successfully');
                  
                  // Close the dialog
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                  
                  // Navigate to Get Started page and remove all previous routes
                  if (context.mounted) {
                    print('DEBUG: Navigating to Get Started page');
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const BookNestScreen(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  }
                } catch (e) {
                  print('DEBUG: Logout error: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: buttonPaddingH,
                  vertical: buttonPaddingV,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(buttonBorderRadius),
                ),
                elevation: 0,
              ),
              child: Text(
                'Yes',
                style: GoogleFonts.poppins(
                  fontSize: buttonFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}