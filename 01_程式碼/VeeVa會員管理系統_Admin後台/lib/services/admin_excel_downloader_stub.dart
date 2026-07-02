import 'dart:typed_data';

Future<void> downloadAdminExcelFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  throw UnsupportedError('此平台不支援直接下載 Excel 檔案');
}
