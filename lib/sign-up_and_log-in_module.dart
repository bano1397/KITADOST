import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_navigation.dart';
import 'forgot_password_module.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KITAB DOST',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.secondary,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Poppins',
      ),
      home: const LoginScreen(),
    );
  }
}

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; 

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        final userId = userCredential.user!.uid;
        final userRef = FirebaseDatabase.instance.ref('users/$userId');
        
        final snapshot = await userRef.once();
        if (!snapshot.snapshot.exists) {
          // Auto-assign admin role for specific email
          final userEmail = userCredential.user!.email?.toLowerCase() ?? '';
          final userRole = (userEmail == 'banozahid1397@gmail.com') ? 'admin' : 'user';
          await userRef.set({
            'username': userCredential.user!.displayName ?? 'User',
            'email': userCredential.user!.email,
            'uid': userId,
            'role': userRole,
            'createdAt': ServerValue.timestamp,
          });
          print('DEBUG: Google Sign-In user saved with role: $userRole');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                'Google Sign-In successful!',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigation(initialIndex: 0)),
      );

    } catch (e) {
      if (!mounted) return;
      print('Error during Google Sign-In: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Sign-In failed: $e'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final isValid = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
).hasMatch(value);

if (!isValid) {
  return 'Please enter a valid email';
}

    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ensure email is saved in database for existing users
      if (userCredential.user != null && userCredential.user!.email != null) {
        try {
          final snapshot = await FirebaseDatabase.instance
              .ref('users/${userCredential.user!.uid}/email')
              .once();
          
          if (!snapshot.snapshot.exists) {
            await FirebaseDatabase.instance
                .ref('users/${userCredential.user!.uid}')
                .update({'email': userCredential.user!.email});
            print('DEBUG: Email saved to database on login: ${userCredential.user!.email}');
          }
        } catch (e) {
          print('DEBUG: Error saving email on login: $e');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Login successful!',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      
      // Navigate to homepage after successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigation(initialIndex: 0),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Login failed: ${e.message ?? e.code}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Login failed: ${e.toString()}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Responsive breakpoints
    final isSmallMobile = size.width < 360;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 900;
    
    // Responsive sizing
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : (isTablet ? 32.0 : 40.0));
    final logoSize = isSmallMobile ? 140.0 : (isMobile ? 160.0 : (isTablet ? 180.0 : 200.0));
    final logoSpacing = isSmallMobile ? 24.0 : (isMobile ? 32.0 : 40.0);
    final cardPadding = isSmallMobile ? 20.0 : (isMobile ? 24.0 : (isTablet ? 28.0 : 32.0));
    final cardMaxWidth = isSmallMobile ? 320.0 : (isMobile ? 380.0 : (isTablet ? 450.0 : 500.0));
    final titleFontSize = isSmallMobile ? 24.0 : (isMobile ? 28.0 : 32.0);
    final subtitleFontSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : 16.0);
    final labelFontSize = isSmallMobile ? 11.0 : 12.0;
    final iconSize = isSmallMobile ? 20.0 : 24.0;
    final fieldSpacing = isSmallMobile ? 18.0 : (isMobile ? 20.0 : 24.0);
    final buttonPadding = isSmallMobile ? 12.0 : (isMobile ? 14.0 : 16.0);
    final buttonFontSize = isSmallMobile ? 14.0 : 16.0;
    final linkFontSize = isSmallMobile ? 13.0 : 14.0;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background logo.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.85),
              BlendMode.lighten,
            ),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/app_logo.png',
                    height: logoSize,
                    width: logoSize,
                  ),
                  SizedBox(height: logoSpacing),
                  
                  // Login Form Card
                  Container(
                    constraints: BoxConstraints(maxWidth: cardMaxWidth),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(cardPadding),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Hello',
                            style: poppinsStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallMobile ? 6.0 : 8.0),
                          Text(
                            'Sign Into Your Account',
                            style: poppinsStyle(
                              fontSize: subtitleFontSize,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallMobile ? 24.0 : 32.0),
                          
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              labelStyle: poppinsStyle(
                                fontSize: labelFontSize,
                                color: Colors.grey.shade600,
                              ),
                              suffixIcon: Icon(
                                Icons.email,
                                color: AppColors.textPrimary,
                                size: iconSize,
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          SizedBox(height: fieldSpacing),
                          
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: poppinsStyle(
                                fontSize: labelFontSize,
                                color: Colors.grey.shade600,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.lock
                                      : Icons.lock_open,
                                  color: AppColors.textPrimary,
                                  size: iconSize,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: isSmallMobile ? 12.0 : 16.0),
                          
                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                ForgotPasswordModule.showForgotPasswordDialog(context);
                              },
                              child: Text(
                                'Forgot Your Password?',
                                style: poppinsStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: linkFontSize,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallMobile ? 18.0 : 24.0),
                          
                          // Login Button
                          ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.textPrimary,
                              padding: EdgeInsets.symmetric(vertical: buttonPadding),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              'Login',
                              style: poppinsStyle(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          
                          SizedBox(height: isSmallMobile ? 12.0 : 16.0),
                          
                          // Google Sign-In Button
                          OutlinedButton.icon(
                            onPressed: _signInWithGoogle,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: buttonPadding),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            icon: Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                              height: 24,
                              width: 24,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, color: Colors.blue),
                            ),
                            label: Text(
                              'Continue with Google',
                              style: poppinsStyle(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallMobile ? 18.0 : 24.0),
                  
                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: poppinsStyle(
                          color: Colors.grey.shade700,
                          fontSize: linkFontSize,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Register Now',
                          style: poppinsStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: linkFontSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final isValid = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
).hasMatch(value);

if (!isValid) {
  return 'Please enter a valid email';
}

    return null;
  }

  Future<void> _register() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Please agree to the Terms & Condition',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    try {
      print('DEBUG: Starting registration for email: $email');
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registering your account...'),
          duration: Duration(seconds: 2),
        ),
      );

      print('DEBUG: Calling createUserWithEmailAndPassword...');
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Save the username to Firebase Auth profile
      if (userCredential.user != null) {
        try {
          print('DEBUG: Updating display name...');
          await userCredential.user!.updateDisplayName(name);
          await userCredential.user!.reload();
          print('DEBUG: Display name updated to: $name');
          
          // Also save to Realtime Database as backup (non-blocking)
          try {
            final userRef = FirebaseDatabase.instance.ref('users/${userCredential.user!.uid}');
            // Auto-assign admin role for specific email
            final userRole = (email.toLowerCase() == 'banozahid1397@gmail.com') ? 'admin' : 'user';
            await userRef.set({
              'username': name,
              'email': email,
              'uid': userCredential.user!.uid,
              'role': userRole,
              'createdAt': ServerValue.timestamp,
            });
            print('DEBUG: User saved in Realtime Database with role: $userRole');
          } catch (databaseError) {
            print('DEBUG: Realtime Database save error (non-blocking): $databaseError');
          }
          
          // Verify the display name was saved
          final updatedUser = FirebaseAuth.instance.currentUser;
          print('DEBUG: Verified display name: ${updatedUser?.displayName}');
        } catch (authError) {
          print('DEBUG: Auth update error: $authError');
          // Continue anyway - user was created
        }
      }
      
      print('DEBUG: User created successfully: ${userCredential.user?.uid}');

      if (!mounted) {
        print('DEBUG: Widget not mounted after auth, stopping');
        return;
      }

      // Set loading to false to allow potential retry
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.celebration,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Registration successful! Welcome to KITAB DOST.',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      // Navigate immediately to homepage
      if (mounted) {
        print('DEBUG: About to navigate to homepage');
        try {
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const MainNavigation(initialIndex: 0),
            ),
          );
          print('DEBUG: Navigation completed successfully');
        } catch (navError) {
          print('DEBUG: Navigation error: $navError');
          setState(() {
            _isLoading = false;
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      print('DEBUG: FirebaseAuthException - Code: ${e.code}, Message: ${e.message}');
      
      String errorMessage = 'Registration failed';
      
      // Handle specific Firebase errors
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak. Use at least 6 characters';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      } else if (e.message?.contains('reCAPTCHA') ?? false) {
        errorMessage = 'reCAPTCHA verification failed. Please check your internet connection or try again.';
      } else {
        errorMessage = e.message ?? e.code;
      }
      
      print('DEBUG: Error message: $errorMessage');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMessage,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      print('DEBUG: General Exception - ${e.toString()}');
      print('DEBUG: Exception type: ${e.runtimeType}');
      
      String errorMessage = 'Registration failed: ${e.toString()}';
      if (e.toString().contains('reCAPTCHA') || e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMessage,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showTermsAndConditions(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallMobile = size.width < 360;
    final isMobile = size.width < 600;
    
    final dialogMaxWidth = isSmallMobile ? 320.0 : (isMobile ? 400.0 : 500.0);
    final dialogMaxHeight = isSmallMobile ? 500.0 : 600.0;
    final headerPadding = isSmallMobile ? 16.0 : 20.0;
    final headerFontSize = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    final contentPadding = isSmallMobile ? 16.0 : 24.0;
    final titleFontSize = isSmallMobile ? 15.0 : (isMobile ? 16.0 : 18.0);
    final bodyFontSize = isSmallMobile ? 13.0 : 14.0;
    final sectionTitleFontSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : 15.0);
    final noteFontSize = isSmallMobile ? 12.0 : 13.0;
    final buttonPadding = isSmallMobile ? 12.0 : 14.0;
    final buttonFontSize = isSmallMobile ? 14.0 : 16.0;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(maxWidth: dialogMaxWidth, maxHeight: dialogMaxHeight),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(headerPadding),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Terms and Conditions',
                          style: poppinsStyle(
                            fontSize: headerFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white, size: isSmallMobile ? 20.0 : 24.0),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(contentPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KITAB DOST App – Terms and Conditions',
                          style: poppinsStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: isSmallMobile ? 12.0 : 16.0),
                        Text(
                          'Welcome to KITAB DOST! By using this application, you agree to the following terms:',
                          style: poppinsStyle(
                            fontSize: bodyFontSize,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: isSmallMobile ? 16.0 : 20.0),
                        _buildTermSection(
                          '1. Account Usage',
                          'You are responsible for maintaining the confidentiality of your account information and activities.',
                          sectionTitleFontSize,
                          bodyFontSize,
                          isSmallMobile,
                        ),
                        _buildTermSection(
                          '2. Content',
                          'All books, articles, and materials available in this app are for personal and educational use only. Redistribution without permission is prohibited.',
                          sectionTitleFontSize,
                          bodyFontSize,
                          isSmallMobile,
                        ),
                        _buildTermSection(
                          '3. Privacy',
                          'We collect minimal user data necessary for app functionality. Your data will not be shared with third parties without consent.',
                          sectionTitleFontSize,
                          bodyFontSize,
                          isSmallMobile,
                        ),
                        _buildTermSection(
                          '4. Limitations',
                          'We are not responsible for any damages or data loss arising from the use of this app.',
                          sectionTitleFontSize,
                          bodyFontSize,
                          isSmallMobile,
                        ),
                        _buildTermSection(
                          '5. Changes',
                          'KITAB DOST reserves the right to update these terms at any time. Continued use of the app means you accept any revised terms.',
                          sectionTitleFontSize,
                          bodyFontSize,
                          isSmallMobile,
                        ),
                        SizedBox(height: isSmallMobile ? 16.0 : 20.0),
                        Container(
                          padding: EdgeInsets.all(isSmallMobile ? 12.0 : 16.0),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.textPrimary.withOpacity(0.2)),
                          ),
                          child: Text(
                            'By clicking "Agree" or continuing to use the app, you confirm that you have read and accepted these Terms and Conditions.',
                            style: poppinsStyle(
                              fontSize: noteFontSize,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer Button
                Container(
                  padding: EdgeInsets.all(headerPadding),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        padding: EdgeInsets.symmetric(vertical: buttonPadding),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: poppinsStyle(
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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

  Widget _buildTermSection(String title, String content, double titleFontSize, double contentFontSize, bool isSmallMobile) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallMobile ? 12.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: poppinsStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: isSmallMobile ? 4.0 : 6.0),
          Text(
            content,
            style: poppinsStyle(
              fontSize: contentFontSize,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Responsive breakpoints
    final isSmallMobile = size.width < 360;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 900;
    
    // Responsive sizing
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : (isTablet ? 32.0 : 40.0));
    final logoSize = isSmallMobile ? 140.0 : (isMobile ? 160.0 : (isTablet ? 180.0 : 200.0));
    final logoSpacing = isSmallMobile ? 24.0 : (isMobile ? 32.0 : 40.0);
    final cardPadding = isSmallMobile ? 20.0 : (isMobile ? 24.0 : (isTablet ? 28.0 : 32.0));
    final cardMaxWidth = isSmallMobile ? 320.0 : (isMobile ? 380.0 : (isTablet ? 450.0 : 500.0));
    final titleFontSize = isSmallMobile ? 24.0 : (isMobile ? 28.0 : 32.0);
    final labelFontSize = isSmallMobile ? 11.0 : 12.0;
    final iconSize = isSmallMobile ? 20.0 : 24.0;
    final fieldSpacing = isSmallMobile ? 18.0 : (isMobile ? 20.0 : 24.0);
    final checkboxFontSize = isSmallMobile ? 12.0 : (isMobile ? 13.0 : 14.0);
    final buttonPadding = isSmallMobile ? 12.0 : (isMobile ? 14.0 : 16.0);
    final buttonFontSize = isSmallMobile ? 14.0 : 16.0;
    final linkFontSize = isSmallMobile ? 13.0 : 14.0;
    final loaderSize = isSmallMobile ? 20.0 : 24.0;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background logo.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.85),
              BlendMode.lighten,
            ),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/app_logo.png',
                    height: logoSize,
                    width: logoSize,
                  ),
                  SizedBox(height: logoSpacing),
                  
                  // Register Form Card
                  Container(
                    constraints: BoxConstraints(maxWidth: cardMaxWidth),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(cardPadding),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Create Account',
                            style: poppinsStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallMobile ? 24.0 : 32.0),
                          
                          // Name Field
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              labelStyle: poppinsStyle(
                                fontSize: labelFontSize,
                                color: Colors.grey.shade600,
                              ),
                              suffixIcon: Icon(
                                Icons.person,
                                color: AppColors.textPrimary,
                                size: iconSize,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: fieldSpacing),
                          
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              labelStyle: poppinsStyle(
                                fontSize: labelFontSize,
                                color: Colors.grey.shade600,
                              ),
                              suffixIcon: Icon(
                                Icons.email,
                                color: AppColors.textPrimary,
                                size: iconSize,
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          SizedBox(height: fieldSpacing),
                          
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: poppinsStyle(
                                fontSize: labelFontSize,
                                color: Colors.grey.shade600,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.lock
                                      : Icons.lock_open,
                                  color: AppColors.textPrimary,
                                  size: iconSize,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: fieldSpacing),
                          
                          // Terms Checkbox
                          Row(
                            children: [
                              Checkbox(
                                value: _agreedToTerms,
                                onChanged: (value) {
                                  setState(() {
                                    _agreedToTerms = value ?? false;
                                  });
                                },
                                activeColor: AppColors.textPrimary,
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _agreedToTerms = !_agreedToTerms;
                                    });
                                  },
                                  child: RichText(
                                    text: TextSpan(
                                      style: poppinsStyle(
                                        fontSize: checkboxFontSize,
                                        color: Colors.grey.shade700,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'I have read and agree with the ',
                                        ),
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.baseline,
                                          baseline: TextBaseline.alphabetic,
                                          child: GestureDetector(
                                            onTap: () {
                                              _showTermsAndConditions(context);
                                            },
                                            child: Text(
                                              'Terms & Condition',
                                              style: poppinsStyle(
                                                fontSize: checkboxFontSize,
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallMobile ? 18.0 : 24.0),
                          
                          // Register Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.textPrimary,
                              padding: EdgeInsets.symmetric(vertical: buttonPadding),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: loaderSize,
                                    width: loaderSize,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Register Now',
                                    style: poppinsStyle(
                                      fontSize: buttonFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallMobile ? 18.0 : 24.0),
                  
                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: poppinsStyle(
                          color: Colors.grey.shade700,
                          fontSize: linkFontSize,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Login',
                          style: poppinsStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: linkFontSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}