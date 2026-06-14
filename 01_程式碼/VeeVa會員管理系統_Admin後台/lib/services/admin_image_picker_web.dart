// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'admin_image_picker_base.dart';

export 'admin_image_picker_base.dart';

Future<PickedAdminImage?> pickAdminImage() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp,image/gif'
    ..multiple = false;
  input.click();

  await input.onChange.first;
  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) {
    return null;
  }

  return _compressForMobile(file);
}

Future<PickedAdminImage?> compressDroppedAdminImage(html.File file) {
  return _compressForMobile(file);
}

Future<PickedAdminImage?> _compressForMobile(html.File file) async {
  final sourceUrl = html.Url.createObjectUrlFromBlob(file);
  try {
    final image = await _loadImage(sourceUrl);
    final sourceWidth = image.naturalWidth;
    final sourceHeight = image.naturalHeight;
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return null;
    }

    final scale = _scaleForMobile(sourceWidth, sourceHeight);
    final width = (sourceWidth * scale).round().clamp(1, sourceWidth);
    final height = (sourceHeight * scale).round().clamp(1, sourceHeight);
    final canvas = html.CanvasElement(width: width, height: height);
    final context = canvas.context2D
      ..imageSmoothingEnabled = true
      ..imageSmoothingQuality = 'high';
    context.drawImageScaled(image, 0, 0, width, height);

    final encoded = _encodeMobileWebp(canvas);
    return PickedAdminImage(
      name: _webpFileName(file.name),
      bytes: encoded.bytes,
      contentType: encoded.contentType,
      sourceSizeBytes: file.size,
      width: width,
      height: height,
      quality: encoded.quality,
    );
  } finally {
    html.Url.revokeObjectUrl(sourceUrl);
  }
}

Future<html.ImageElement> _loadImage(String sourceUrl) {
  final completer = Completer<html.ImageElement>();
  final image = html.ImageElement();
  late StreamSubscription<html.Event> loadSubscription;
  late StreamSubscription<html.Event> errorSubscription;

  void finish([Object? error]) {
    loadSubscription.cancel();
    errorSubscription.cancel();
    if (error == null) {
      completer.complete(image);
    } else {
      completer.completeError(error);
    }
  }

  loadSubscription = image.onLoad.listen((_) => finish());
  errorSubscription =
      image.onError.listen((_) => finish(StateError('image load failed')));
  image.src = sourceUrl;
  return completer.future.timeout(const Duration(seconds: 12));
}

double _scaleForMobile(int width, int height) {
  const maxDimension = 1280;
  final longestSide = width > height ? width : height;
  if (longestSide <= maxDimension) {
    return 1;
  }
  return maxDimension / longestSide;
}

_EncodedAdminImage _encodeMobileWebp(html.CanvasElement canvas) {
  const qualities = [0.75, 0.70, 0.65, 0.60];
  _EncodedAdminImage? fallback;
  for (final quality in qualities) {
    final encoded = _dataUrlToImage(canvas.toDataUrl('image/webp', quality));
    fallback = _EncodedAdminImage(
      bytes: encoded.bytes,
      contentType: encoded.contentType,
      quality: quality,
    );
    if (encoded.bytes.lengthInBytes <= adminImageTargetBytes) {
      return fallback;
    }
  }
  return fallback!;
}

_DataUrlImage _dataUrlToImage(String dataUrl) {
  final match =
      RegExp(r'^data:([^;]+);base64,(.*)$').firstMatch(dataUrl.trim());
  if (match == null) {
    throw StateError('invalid image data url');
  }
  return _DataUrlImage(
    contentType: match.group(1) ?? 'image/webp',
    bytes: base64Decode(match.group(2) ?? ''),
  );
}

String _webpFileName(String fileName) {
  final sanitized = fileName
      .split(RegExp(r'[/\\]'))
      .last
      .toLowerCase()
      .replaceAll(RegExp(r'\.(png|jpe?g|webp|gif)$'), '')
      .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
  if (sanitized.isEmpty) {
    return 'image.webp';
  }
  return '$sanitized.webp';
}

class _EncodedAdminImage {
  const _EncodedAdminImage({
    required this.bytes,
    required this.contentType,
    required this.quality,
  });

  final Uint8List bytes;
  final String contentType;
  final double quality;
}

class _DataUrlImage {
  const _DataUrlImage({
    required this.bytes,
    required this.contentType,
  });

  final Uint8List bytes;
  final String contentType;
}
