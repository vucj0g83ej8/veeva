import 'liff_service_base.dart';
import 'liff_service_stub.dart' if (dart.library.html) 'liff_service_web.dart'
    as implementation;

export 'liff_service_base.dart';

LiffService createLiffService({required LiffConfig config}) {
  return implementation.createLiffService(config: config);
}
