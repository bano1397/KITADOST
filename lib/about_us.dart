import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutBookNestScreen extends StatelessWidget {
  const AboutBookNestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    // Responsive breakpoints
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    final isDesktop = width >= 900;
    
    // Responsive sizing
    final logoSize = isSmallMobile ? 180.0 : (isMobile ? 220.0 : (isTablet ? 280.0 : 320.0));
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : (isTablet ? 40.0 : 60.0));
    final containerMaxWidth = isTablet ? 600.0 : (isDesktop ? 700.0 : double.infinity);
    final titleFontSize = isSmallMobile ? 18.0 : (isMobile ? 20.0 : (isTablet ? 24.0 : 28.0));
    final bodyFontSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : (isTablet ? 16.0 : 18.0));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Logo (watermark style)
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.asset(
                'assets/background logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container();
                },
              ),
            ),
          ),
          
          // Main Content
          SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isMobile ? 20 : 30,
            ),
            child: Column(
              children: [
                // Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 14),
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: isMobile ? 24 : 28,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 5),
                
                // Logo
                Container(
                  width: logoSize,
                  height: logoSize,
                  child: Image.asset(
                    'assets/app_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.menu_book,
                        size: logoSize * 0.6,
                        color: AppColors.secondary,
                      );
                    },
                  ),
                ),
                
                SizedBox(height: size.height * 0.02),
                
                // About Container
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: containerMaxWidth),
                  padding: EdgeInsets.all(isMobile ? 20 : (isTablet ? 30 : 40)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Us!',
                        style: GoogleFonts.poppins(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      SizedBox(height: isMobile ? 16 : 20),
                      Text(
                        'KITAB DOST is a peer-to-peer book sharing platform created for students who want an easier and more affordable way to access learning materials. It allows users to lend and borrow textbooks, reference materials, and leisure reads within their academic community.',
                        style: GoogleFonts.poppins(
                          fontSize: bodyFontSize,
                          height: 1.6,
                          color: AppColors.secondary,
                        ),
                        textAlign: isTablet || isDesktop ? TextAlign.justify : TextAlign.left,
                      ),
                      SizedBox(height: isMobile ? 16 : 20),
                      Text(
                        'Each member is verified through their school credentials to ensure a safe and trustworthy environment. With organized book categories, direct messaging, tracking features, and a fair penalty system for damaged or unreturned books, KITAB DOST promotes collaboration, sustainability, and a stronger reading culture among students.',
                        style: GoogleFonts.poppins(
                          fontSize: bodyFontSize,
                          height: 1.6,
                          color: AppColors.secondary,
                        ),
                        textAlign: isTablet || isDesktop ? TextAlign.justify : TextAlign.left,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: isMobile ? 20 : 30),
                
                // Developers Section
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: containerMaxWidth),
                  padding: EdgeInsets.all(isMobile ? 20 : (isTablet ? 30 : 40)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Developers',
                        style: GoogleFonts.poppins(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      SizedBox(height: isMobile ? 16 : 20),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: AppColors.primary,
                            size: isMobile ? 20 : 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Sibgha Amir',
                            style: GoogleFonts.poppins(
                              fontSize: bodyFontSize,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 12 : 16),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: AppColors.primary,
                            size: isMobile ? 20 : 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Shehar Bano',
                            style: GoogleFonts.poppins(
                              fontSize: bodyFontSize,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 12 : 16),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: AppColors.primary,
                            size: isMobile ? 20 : 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Sadia Saeed',
                            style: GoogleFonts.poppins(
                              fontSize: bodyFontSize,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: isMobile ? 20 : 30),
              ],
            ),
          ),
        ),
          ),
        ],
      ),
    );
  }
}
