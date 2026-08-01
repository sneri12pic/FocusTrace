import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Circular app icon with an initial-letter fallback.
class AppIconAvatar extends StatelessWidget {
  const AppIconAvatar({
    required this.appName,
    this.iconBytes,
    this.size = 40,
    super.key,
  });

  final String appName;
  final Uint8List? iconBytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = iconBytes;
    if (bytes != null) {
      return ClipOval(
        // Stable byte object + cacheWidth: decoded once, then served from the
        // image cache instead of re-decoding the PNG on every rebuild.
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          cacheWidth: (size * 3).round(),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      child: Text(appName.isEmpty ? '?' : appName[0].toUpperCase()),
    );
  }
}
