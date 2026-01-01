import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
// Import the login / register module so we can navigate to the Register screen
import 'sign-up_and_log-in_module.dart';
import 'main_navigation.dart';

// Helper function to create Poppins-style text
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

// Note: main() is in main.dart, not here
// This module provides the BookNestScreen UI

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KITAB DOST',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Authentication wrapper to check login status
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // If user is logged in, go to main navigation (home page)
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavigation(initialIndex: 0);
        }
        
        // If not logged in, show get started screen
        return const BookNestScreen();
      },
    );
  }
}


class BookNestScreen extends StatelessWidget {
  const BookNestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    
    // Responsive breakpoints
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    
    // Responsive sizing
    final logoTopPadding = isSmallMobile ? height * 0.04 : (isMobile ? height * 0.06 : (isTablet ? height * 0.08 : height * 0.1));
    final logoWidth = isSmallMobile ? width * 0.85 : (isMobile ? width * 0.9 : (isTablet ? width * 0.7 : width * 0.5));
    final logoHeight = isSmallMobile ? height * 0.5 : (isMobile ? height * 0.55 : height * 0.6);
    
    final contentHorizontalPadding = isSmallMobile ? width * 0.06 : (isMobile ? width * 0.08 : (isTablet ? width * 0.12 : width * 0.15));
    final contentVerticalPadding = isSmallMobile ? height * 0.03 : (isMobile ? height * 0.04 : height * 0.05);
    
    final titleFontSize = isSmallMobile ? 18.0 : (isMobile ? 20.0 : (isTablet ? 24.0 : 28.0));
    final subtitleFontSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : (isTablet ? 16.0 : 18.0));
    final subtitleHorizontalPadding = isSmallMobile ? width * 0.03 : (isMobile ? width * 0.05 : (isTablet ? width * 0.1 : width * 0.15));
    
    final titleBottomSpacing = isSmallMobile ? height * 0.02 : (isMobile ? height * 0.025 : height * 0.03);
    final subtitleBottomSpacing = isSmallMobile ? height * 0.03 : (isMobile ? height * 0.035 : height * 0.04);
    
    final buttonWidth = isSmallMobile ? width * 0.85 : (isMobile ? width * 0.8 : (isTablet ? width * 0.6 : width * 0.4));
    final buttonHeight = isSmallMobile ? 48.0 : (isMobile ? 52.0 : (isTablet ? 56.0 : 60.0));
    final buttonFontSize = isSmallMobile ? 16.0 : (isMobile ? 18.0 : (isTablet ? 20.0 : 22.0));
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top half background image and logo
            Expanded(
              flex: 1,
              child: Stack(
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Image.asset(
                          "assets/background logo.png",
                          fit: BoxFit.cover,
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: logoTopPadding),
                          child: SizedBox(
                            width: logoWidth,
                            height: logoHeight,
                            child: Image.asset(
                              "assets/logo1.png",
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bottom half with white background and text
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: contentHorizontalPadding,
                  vertical: contentVerticalPadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Main Title
                    Text(
                      "Where Every Borrowed Book\nTells a New Story.",
                      textAlign: TextAlign.center,
                      style: poppinsStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E3A8A),
                        height: 1.3,
                      ),
                    ),
                    
                    SizedBox(height: titleBottomSpacing),
                    
                    // Subtitle
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: subtitleHorizontalPadding,
                      ),
                      child: Text(
                        "A book is more than just words on a page. It's a shared experience that can connect people.",
                        textAlign: TextAlign.center,
                        style: poppinsStyle(
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: subtitleBottomSpacing),
                    
                    // Get Started Button
                    SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to the Register screen from the sign-up module
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 3,
                        ),
                        child: Text(
                          "Get Started",
                          style: poppinsStyle(
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}