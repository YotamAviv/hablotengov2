import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

/// Secondary Firebase connection to the one-of-us-net project,
/// mirroring the OneofusFire pattern in nerdster14.
class OneofusFire {
  static const FirebaseOptions _oneofusWeb = FirebaseOptions(
    apiKey: 'AIzaSyCTR3oVW3zXG8JJdcRFzbEsz8SFPfwz8OE',
    authDomain: 'one-of-us-net.firebaseapp.com',
    projectId: 'one-of-us-net',
    storageBucket: 'one-of-us-net.appspot.com',
    messagingSenderId: '62898847921',
    appId: '1:62898847921:web:7f020461c378930e29a290',
  );

  static late final FirebaseFirestore firestore;
  static late final FirebaseFunctions functions;

  static Future<void> init() async {
    final app = await Firebase.initializeApp(
      name: 'oneofus',
      options: _oneofusWeb,
    );
    firestore = FirebaseFirestore.instanceFor(app: app);
    functions = FirebaseFunctions.instanceFor(app: app);
  }
}
