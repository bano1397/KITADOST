// Placeholder firebase_options.dart
// This file is intentionally a safe stub so the project compiles if
// the real firebase_options.dart hasn't been generated yet.
//
// To generate the real file with your project's Firebase configuration,
// run:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
// from the project root and follow the prompts. That command will create
// a proper `lib/firebase_options.dart` with DefaultFirebaseOptions for
// each platform.

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // This throws to clearly indicate it's a placeholder and must be
    // replaced by running `flutterfire configure`.
    throw UnsupportedError('''DefaultFirebaseOptions.currentPlatform was accessed but `lib/firebase_options.dart` is still the placeholder.

To fix this:
  1) Install the FlutterFire CLI: `dart pub global activate flutterfire_cli`
  2) Run `flutterfire configure` in the project root and follow the prompts.
  3) Re-run your app.

If you intentionally want to use platform-specific automatic config (Android with google-services.json, iOS with GoogleService-Info.plist), avoid calling DefaultFirebaseOptions and initialize Firebase using `Firebase.initializeApp()` on non-web platforms. On web, explicit options are required.''');
  }
}
