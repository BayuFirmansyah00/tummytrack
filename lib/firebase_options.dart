import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCBrOhAP6arkAwS2Ds_GtaHnusXQluBW7o',
    appId: '1:668877136617:web:d93c0b90eb2e94611e0678',
    messagingSenderId: '668877136617',
    projectId: 'tummy-track-a8b56',
    authDomain: 'tummy-track-a8b56.firebaseapp.com',
    storageBucket: 'tummy-track-a8b56.firebasestorage.app',
    measurementId: 'G-6J4GKZME4W',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDUMA0h6vAGIvSQQCbYFRkNzxk1T39f3x4',
    appId: '1:668877136617:android:a068a1097a70a92c1e0678',
    messagingSenderId: '668877136617',
    projectId: 'tummy-track-a8b56',
    storageBucket: 'tummy-track-a8b56.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDg9jw7c2oc0BaRQonjpodYyw8WLuuGRJE',
    appId: '1:668877136617:ios:77b8d44565bd0eb51e0678',
    messagingSenderId: '668877136617',
    projectId: 'tummy-track-a8b56',
    storageBucket: 'tummy-track-a8b56.firebasestorage.app',
    iosClientId: '668877136617-h2vph0ldhgievl8p33s2glv2l3tgb02q.apps.googleusercontent.com',
    iosBundleId: 'com.example.myapp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDg9jw7c2oc0BaRQonjpodYyw8WLuuGRJE',
    appId: '1:668877136617:ios:77b8d44565bd0eb51e0678',
    messagingSenderId: '668877136617',
    projectId: 'tummy-track-a8b56',
    storageBucket: 'tummy-track-a8b56.firebasestorage.app',
    iosClientId: '668877136617-h2vph0ldhgievl8p33s2glv2l3tgb02q.apps.googleusercontent.com',
    iosBundleId: 'com.example.myapp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'your-web-api-key',
    appId: 'your-web-app-id',
    messagingSenderId: 'your-sender-id',
    projectId: 'your-project-id',
    authDomain: 'your-project-id.firebaseapp.com',
    storageBucket: 'your-project-id.appspot.com',
  );
}