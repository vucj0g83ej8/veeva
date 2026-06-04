import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'veeva_repository.dart';

Future<VeevaRepository> createVeevaRepository() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return FirestoreVeevaRepository();
  } catch (_) {
    return DemoVeevaRepository();
  }
}
