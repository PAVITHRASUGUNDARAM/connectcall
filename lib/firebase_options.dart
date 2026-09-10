import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';

/// Generated-style Firebase options. Replace placeholders with
/// `flutterfire configure` output, or edit the constants below.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for ConnectCall.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static bool get isConfigured =>
      android.apiKey != 'YOUR_ANDROID_API_KEY' &&
      android.appId != 'YOUR_ANDROID_APP_ID';

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCmrIqy24yoMh2O9Ou5ReqzgLtOznhhIeA',
    appId: '1:939624797203:android:eb6239fae4bcc7af1f5be6',
    messagingSenderId: '939624797203',
    projectId: 'connect-call-3b792',
    storageBucket: 'connect-call-3b792.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCvDhv6luyDe5imCghg-1UBDSv-YneXoPw',
    appId: '1:939624797203:ios:9c56041623674e6a1f5be6',
    messagingSenderId: '939624797203',
    projectId: 'connect-call-3b792',
    storageBucket: 'connect-call-3b792.firebasestorage.app',
    iosClientId: '939624797203-iisbgafim9notpofd2uljnoabpupg8sg.apps.googleusercontent.com',
    iosBundleId: 'com.connectcall.connectCall',
  );
}
