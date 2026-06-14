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
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
  final int? sourceSizeBytes;
  final int? width;
  final int? height;
  final double? quality;

  int get sizeBytes => bytes.lengthInBytes;
  int get originalSizeBytes => sourceSizeBytes ?? sizeBytes;
  bool get wasCompressed =>
      sourceSizeBytes != null && sourceSizeBytes != sizeBytes;
}
