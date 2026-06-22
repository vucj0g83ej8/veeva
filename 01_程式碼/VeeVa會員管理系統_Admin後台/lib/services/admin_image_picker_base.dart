import 'dart:typed_data';

const adminImageSourceMaxBytes = 10 * 1024 * 1024;
const adminImageUploadMaxBytes = 2 * 1024 * 1024;
const adminImageTargetBytes = 200 * 1024;

class PickedAdminImage {
  const PickedAdminImage({
    required this.name,
    required this.bytes,
    required this.contentType,
    this.sourceSizeBytes,
    this.width,
    this.height,
    this.quality,
    this.shareName,
    this.shareBytes,
    this.shareContentType,
    this.shareQuality,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
  final int? sourceSizeBytes;
  final int? width;
  final int? height;
  final double? quality;
  final String? shareName;
  final Uint8List? shareBytes;
  final String? shareContentType;
  final double? shareQuality;

  int get sizeBytes => bytes.lengthInBytes;
  int get originalSizeBytes => sourceSizeBytes ?? sizeBytes;
  bool get wasCompressed =>
      sourceSizeBytes != null && sourceSizeBytes != sizeBytes;
  bool get hasShareVariant =>
      shareBytes != null &&
      shareBytes!.isNotEmpty &&
      (shareContentType?.isNotEmpty ?? false);
}
