import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Whether to use the local Firebase Emulator Suite (`npm run emulators` in
/// ../firebase) instead of a real project. On by default; build with
/// `--dart-define=USE_FIREBASE_EMULATORS=false` once the app points at a real
/// project.
const useFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS', defaultValue: true);

/// Where the emulators run. `localhost` is mapped to 10.0.2.2 on the Android
/// emulator automatically; on a physical phone, pass your computer's LAN IP:
/// `--dart-define=FIREBASE_EMULATOR_HOST=192.168.1.20`.
const _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');

/// Ports from ../firebase/firebase.json.
const _authPort = 9099;
const _firestorePort = 8080;

/// The app uses only Firebase services on the free Spark plan: Auth and
/// Firestore. (Cloud Storage and Cloud Functions need the paid Blaze plan.)
Future<void> initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (useFirebaseEmulators) {
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, _authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, _firestorePort);
  }
}
