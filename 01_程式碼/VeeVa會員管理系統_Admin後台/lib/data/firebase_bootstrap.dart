import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../firebase_options.dart';
import 'veeva_repository.dart';

const veevaAdminImageStorageBucket = String.fromEnvironment(
  'VEEVA_STORAGE_BUCKET',
  defaultValue: 'gs://veeva-8d30c-us-images',
);

Future<VeevaRepository> createVeevaRepository() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return FirestoreVeevaRepository(
      storage: FirebaseStorage.instanceFor(
        bucket: veevaAdminImageStorageBucket,
      ),
    );
  } catch (_) {
    return DemoVeevaRepository();
  }
}
