import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'get_started_module.dart' as start;

void main() {
	WidgetsFlutterBinding.ensureInitialized();
	runApp(const AppEntry());
}

Future<FirebaseApp> _initializeFirebase() async {
  try {
    if (kIsWeb) {
      // Web requires explicit Firebase options.
      // To run on web, you must first run: flutterfire configure
      // This will generate lib/firebase_options.dart with the proper config
      throw UnsupportedError(
        'Web platform requires firebase_options.dart. Run: flutterfire configure'
      );
    }

    // For Android/iOS: Use platform-specific configuration files
    // (google-services.json on Android, GoogleService-Info.plist on iOS)
    debugPrint('Initializing Firebase using platform-specific config (google-services.json/GoogleService-Info.plist)');
    final app = await Firebase.initializeApp();
    
    // Configure Realtime Database
    // IMPORTANT: Get the exact database URL from Firebase Console:
    // 1. Go to Firebase Console → Your project (notebook-fbaf9) → Realtime Database
    // 2. Look at the top of the page - you'll see the database URL
    // 3. Copy that URL exactly (it might be in a different region like asia-southeast1)
    // 4. Replace the URL below with your actual database URL
    
    // Common database URL formats:
    // - Default region: https://notebook-fbaf9-default-rtdb.firebaseio.com
    // - Asia region: https://notebook-fbaf9-default-rtdb.asia-southeast1.firebasedatabase.app
    // - US region: https://notebook-fbaf9-default-rtdb.us-central1.firebasedatabase.app
    
    // If your database is in a different region, update this URL:
    final databaseUrl = 'https://notebook-fbaf9-default-rtdb.firebaseio.com';
    
    // Alternative: If your database is in asia-southeast1 region, use:
    // final databaseUrl = 'https://notebook-fbaf9-default-rtdb.asia-southeast1.firebasedatabase.app';
    
    FirebaseDatabase.instance.databaseURL = databaseUrl;
    debugPrint('Realtime Database configured: ${FirebaseDatabase.instance.databaseURL}');
    debugPrint('Project ID from google-services.json: notebook-fbaf9');
    
    return app;
  } catch (e) {
    debugPrint('Firebase Init Error: $e');
    rethrow;
  }
}

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _initializeFirebase(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          debugPrint('Firebase Init Error (caught in builder): $error');
          return MaterialApp(
            theme: ThemeData(fontFamily: 'Poppins'),
            home: Scaffold(
              body: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final isSmallMobile = width < 360;
                    final isMobile = width < 600;
                    
                    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : 32.0);
                    final fontSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : 16.0);
                    
                    return SingleChildScrollView(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: Text(
                        'Firebase initialization failed:\n\n$error\n\nCheck:\n1. google-services.json in android/app/\n2. Firebase Console Email/Password enabled\n3. Correct project ID & package name\n4. Internet connection',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: fontSize),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }				if (snapshot.connectionState == ConnectionState.done) {
					return const start.MyApp();
				}

				return MaterialApp(
					theme: ThemeData(fontFamily: 'Poppins'),
					home: Scaffold(
						body: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isSmallMobile = width < 360;
                  final isMobile = width < 600;
                  
                  final indicatorSize = isSmallMobile ? 36.0 : (isMobile ? 40.0 : 48.0);
                  final strokeWidth = isSmallMobile ? 3.0 : (isMobile ? 3.5 : 4.0);
                  
                  return SizedBox(
                    width: indicatorSize,
                    height: indicatorSize,
                    child: CircularProgressIndicator(
                      strokeWidth: strokeWidth,
                    ),
                  );
                },
              ),
            ),
					),
				);
			},
		);
	}
}
