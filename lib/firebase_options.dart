import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDvFmI-EzewecBXm7t--BKTis19h5s9JT4',
    appId: '1:176939323980:android:5d59e9cae26be24b161ae9',
    messagingSenderId: '176939323980',
    projectId: 'micompra-3aa0d',
    storageBucket: 'micompra-3aa0d.firebasestorage.app',
  );
}
