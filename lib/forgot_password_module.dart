import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordModule {
  static Future<void> showForgotPasswordDialog(BuildContext context) async {
    final TextEditingController emailController = TextEditingController();
    bool isLoading = false;

    // Get screen size and define responsive breakpoints
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    
    // Responsive sizing variables
    final dialogBorderRadius = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    final titleFontSize = isSmallMobile ? 20.0 : (isMobile ? 22.0 : (isTablet ? 24.0 : 26.0));
    final contentFontSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : (isTablet ? 15.0 : 16.0));
    final labelFontSize = isSmallMobile ? 11.0 : 12.0;
    final buttonFontSize = isSmallMobile ? 14.0 : (isMobile ? 15.0 : (isTablet ? 16.0 : 17.0));
    final buttonPaddingH = isSmallMobile ? 20.0 : (isMobile ? 22.0 : (isTablet ? 24.0 : 28.0));
    final buttonPaddingV = isSmallMobile ? 10.0 : (isMobile ? 11.0 : (isTablet ? 12.0 : 13.0));
    final buttonBorderRadius = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    final iconSize = isSmallMobile ? 20.0 : 24.0;
    
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> sendResetEmail() async {
              final email = emailController.text.trim();
              
              if (email.isEmpty) {
                _showSnackBar(
                  context,
                  'Please enter your email address',
                  isError: true,
                );
                return;
              }
              
              final bool isValidEmail = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
).hasMatch(email);

if (!isValidEmail) {
  _showSnackBar(
    context,
    'Please enter a valid email address',
    isError: true,
  );
  return;
}


              setState(() {
                isLoading = true;
              });

              try {
                print('DEBUG: Attempting to send password reset email to: $email');
                
                // Note: Firebase will send the email even if the user doesn't exist
                // (for security reasons, to prevent email enumeration)
                // So we can't check if the email exists first
                
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: email,
                );

                print('DEBUG: Password reset email sent successfully to: $email');
                print('DEBUG: Email should come from: noreply@notebook-fbaf9.firebaseapp.com');
                print('DEBUG: Check spam/junk folder if not received within 5 minutes');

                if (!context.mounted) return;

                setState(() {
                  isLoading = false;
                });

                Navigator.of(dialogContext).pop();

                // Show a more detailed success dialog with instructions
                _showSuccessDialog(context, email);
              } on FirebaseAuthException catch (e) {
                print('DEBUG: FirebaseAuthException: ${e.code} - ${e.message}');
                
                if (!context.mounted) return;

                setState(() {
                  isLoading = false;
                });

                String errorMessage = 'Failed to send reset email';
                
                if (e.code == 'user-not-found') {
                  errorMessage = 'No account found with this email address. Please check if you entered the correct email.';
                } else if (e.code == 'invalid-email') {
                  errorMessage = 'Invalid email address. Please enter a valid email.';
                } else if (e.code == 'too-many-requests') {
                  errorMessage = 'Too many requests. Please wait a few minutes before trying again.';
                } else {
                  errorMessage = 'Error: ${e.message ?? e.code}';
                }

                print('DEBUG: Showing error message: $errorMessage');
                _showSnackBar(context, errorMessage, isError: true);
              } catch (e, stackTrace) {
                print('DEBUG: Unexpected error sending password reset email: $e');
                print('DEBUG: Stack trace: $stackTrace');
                
                if (!context.mounted) return;

                setState(() {
                  isLoading = false;
                });

                _showSnackBar(
                  context,
                  'An error occurred: ${e.toString()}',
                  isError: true,
                );
              }
            }

            final contentPadding = isMobile ? 20.0 : 24.0;
            
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dialogBorderRadius),
              ),
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(dialogBorderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient background
                    Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.secondary, Color(0xFF004080)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(dialogBorderRadius),
                          topRight: Radius.circular(dialogBorderRadius),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lock_reset,
                              color: Colors.white,
                              size: titleFontSize,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Reset Password',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: titleFontSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Padding(
                      padding: EdgeInsets.all(contentPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info box
                          Container(
                            padding: EdgeInsets.all(contentPadding * 0.75),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.05),
                              border: Border.all(
                                color: AppColors.secondary.withOpacity(0.2),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppColors.secondary,
                                  size: iconSize,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Enter your email address and we\'ll send you a link to reset your password.',
                                    style: GoogleFonts.poppins(
                                      fontSize: contentFontSize,
                                      color: AppColors.secondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: contentPadding),
                          // Email input
                          TextFormField(
                            controller: emailController,
                            enabled: !isLoading,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              labelStyle: GoogleFonts.poppins(
                                fontSize: labelFontSize,
                                color: Colors.grey.shade600,
                              ),
                              hintText: 'example@gmail.com',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: contentFontSize,
                                color: Colors.grey.shade400,
                              ),
                              prefixIcon: Icon(
                                Icons.email,
                                color: const Color(0xFFFF6B35),
                                size: iconSize,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF6B35),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.poppins(fontSize: contentFontSize),
                          ),
                        ],
                      ),
                    ),
                    // Buttons
                    Padding(
                      padding: EdgeInsets.fromLTRB(contentPadding, 0, contentPadding, contentPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    Navigator.of(dialogContext).pop();
                                  },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: buttonPaddingH,
                                vertical: buttonPaddingV,
                              ),
                              side: BorderSide(
                                color: isLoading ? Colors.grey.shade300 : AppColors.secondary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(buttonBorderRadius),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                color: isLoading ? Colors.grey.shade400 : AppColors.secondary,
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: isLoading ? null : sendResetEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B35),
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
                            child: isLoading
                                ? SizedBox(
                                    width: iconSize,
                                    height: iconSize,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Send Link',
                                    style: GoogleFonts.poppins(
                                      fontSize: buttonFontSize,
                                      fontWeight: FontWeight.w600,
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
      },
    );
  }

  static void _showSuccessDialog(BuildContext context, String email) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    
    final dialogBorderRadius = isMobile ? 18.0 : 20.0;
    final titleFontSize = isMobile ? 22.0 : (isTablet ? 24.0 : 26.0);
    final contentFontSize = isMobile ? 14.0 : (isTablet ? 15.0 : 16.0);
    final buttonFontSize = isMobile ? 15.0 : (isTablet ? 16.0 : 17.0);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dialogBorderRadius),
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(dialogBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(isMobile ? 20 : 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(dialogBorderRadius),
                      topRight: Radius.circular(dialogBorderRadius),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Email Sent!',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: titleFontSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.all(isMobile ? 20 : 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'We\'ve sent a password reset link to:',
                        style: GoogleFonts.poppins(
                          fontSize: contentFontSize,
                          color: const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          email,
                          style: GoogleFonts.poppins(
                            fontSize: contentFontSize,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E6),
                          border: Border.all(
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: const Color(0xFFFF6B35),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Important:',
                                  style: GoogleFonts.poppins(
                                    fontSize: contentFontSize,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFF6B35),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInstructionItem(
                              'Look for email from: noreply@notebook-fbaf9.firebaseapp.com',
                              contentFontSize,
                            ),
                            const SizedBox(height: 8),
                            _buildInstructionItem(
                              'Check your inbox AND spam/junk folder',
                              contentFontSize,
                            ),
                            const SizedBox(height: 8),
                            _buildInstructionItem(
                              'Click the reset link in the email',
                              contentFontSize,
                            ),
                            const SizedBox(height: 8),
                            _buildInstructionItem(
                              'The link expires in 1 hour',
                              contentFontSize,
                            ),
                            const SizedBox(height: 8),
                            _buildInstructionItem(
                              'If not received within 5 minutes, check spam again',
                              contentFontSize,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 20 : 24,
                    0,
                    isMobile ? 20 : 24,
                    isMobile ? 20 : 24,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Got it',
                        style: GoogleFonts.poppins(
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildInstructionItem(String text, double fontSize) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, right: 8),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFFFF6B35),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: fontSize - 1,
              color: const Color(0xFF374151),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  static void _showSnackBar(BuildContext context, String message,
      {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: isError ? AppColors.secondary : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
