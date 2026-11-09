// Firebase options for the local, emulator-only `demo-hakikisha` project.
//
// `demo-` project IDs never touch the cloud: the Firebase SDKs talk only to
// the Emulator Suite (see ../firebase). When you create the real Firebase
// project, run `flutterfire configure` from mobile/. It overwrites this file
// with the real project's options, keeping the `DefaultFirebaseOptions`
// name that lib/core/firebase_setup.dart uses.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => FirebaseOptions(
        apiKey: 'demo-api-key',
        // Checked first: in a browser, defaultTargetPlatform is the computer's
        // OS (e.g. Windows), not "web".
        appId: kIsWeb
            ? '1:000000000000:web:0000000000000000'
            : defaultTargetPlatform == TargetPlatform.iOS
                ? '1:000000000000:ios:0000000000000000'
                : '1:000000000000:android:0000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'demo-hakikisha',
        authDomain: 'demo-hakikisha.firebaseapp.com',
        iosBundleId: 'com.hakikisha.hakikisha',
      );
}
