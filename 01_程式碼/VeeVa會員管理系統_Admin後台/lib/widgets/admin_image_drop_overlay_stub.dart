import 'package:flutter/widgets.dart';

import '../services/admin_image_picker_base.dart';

class AdminImageDropOverlay extends StatelessWidget {
  const AdminImageDropOverlay({
    required this.onImage,
    this.onHoverChanged,
    super.key,
  });

  final ValueChanged<PickedAdminImage> onImage;
  final ValueChanged<bool>? onHoverChanged;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}
