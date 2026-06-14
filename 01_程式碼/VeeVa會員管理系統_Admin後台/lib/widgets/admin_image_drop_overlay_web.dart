// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

import '../services/admin_image_picker_web.dart';

class AdminImageDropOverlay extends StatefulWidget {
  const AdminImageDropOverlay({
    required this.onImage,
    this.onHoverChanged,
    super.key,
  });

  final ValueChanged<PickedAdminImage> onImage;
  final ValueChanged<bool>? onHoverChanged;

  @override
  State<AdminImageDropOverlay> createState() => _AdminImageDropOverlayState();
}

class _AdminImageDropOverlayState extends State<AdminImageDropOverlay> {
  static int _viewId = 0;

  late final String _viewType;
  final List<StreamSubscription<html.Event>> _subscriptions = [];
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'veeva-admin-image-drop-${_viewId++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, _createElement);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  html.DivElement _createElement(int viewId) {
    final element = html.DivElement()..title = '拖曳圖片到這裡或點擊選擇圖片';
    element.style
      ..width = '100%'
      ..height = '100%'
      ..minHeight = '100%'
      ..display = 'block'
      ..cursor = 'pointer'
      ..backgroundColor = 'rgba(0,0,0,0)'
      ..border = '0'
      ..padding = '0'
      ..margin = '0'
      ..outline = 'none';

    _subscriptions.add(element.onClick.listen((event) async {
      event.preventDefault();
      final image = await pickAdminImage();
      if (!mounted || image == null) {
        return;
      }
      widget.onImage(image);
    }));

    _subscriptions.add(element.onDragEnter.listen((event) {
      event.preventDefault();
      _setHovering(true);
    }));

    _subscriptions.add(element.onDragOver.listen((event) {
      event.preventDefault();
      event.dataTransfer.dropEffect = 'copy';
      _setHovering(true);
    }));

    _subscriptions.add(element.onDragLeave.listen((event) {
      event.preventDefault();
      _setHovering(false);
    }));

    _subscriptions.add(element.onDrop.listen((event) async {
      event.preventDefault();
      _setHovering(false);
      final files = event.dataTransfer.files;
      if (files == null || files.isEmpty) {
        return;
      }
      final image = await compressDroppedAdminImage(files.first);
      if (!mounted || image == null) {
        return;
      }
      widget.onImage(image);
    }));

    return element;
  }

  void _setHovering(bool value) {
    if (_isHovering == value) {
      return;
    }
    _isHovering = value;
    widget.onHoverChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
