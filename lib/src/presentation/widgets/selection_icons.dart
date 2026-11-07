import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/datasources/screen_time_channel.dart';
import 'app_icon_avatar.dart';

/// The icons of an iOS picker selection (`ios-sel:<id>` app keys). iOS draws
/// them natively (platform view `focustrace/selection_icons`), because Flutter
/// never receives the apps' names or images. Anywhere else, including tests,
/// it falls back to the letter avatar of the rule name.
class SelectionIcons extends StatelessWidget {
  const SelectionIcons({
    required this.appKey,
    required this.appName,
    this.size = 40,
    this.maxIcons = 2,
    super.key,
  });

  final String appKey;
  final String appName;
  final double size;
  final int maxIcons;

  @override
  Widget build(BuildContext context) {
    final selectionId = iosSelectionId(appKey);
    if (selectionId == null ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      return AppIconAvatar(appName: appName, size: size);
    }
    return Semantics(
      label: appName,
      child: SizedBox(
        // Room for the icons and a "+N" for the rest.
        width: size * maxIcons + 4 * (maxIcons - 1) + size * 0.9,
        height: size,
        child: UiKitView(
          // A new selection id is a new native view.
          key: ValueKey('selection-icons-$selectionId'),
          viewType: 'focustrace/selection_icons',
          creationParams: {
            'selectionId': selectionId,
            'maxIcons': maxIcons,
            'iconSize': size,
          },
          creationParamsCodec: const StandardMessageCodec(),
        ),
      ),
    );
  }
}
