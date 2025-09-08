import 'package:flutter/widgets.dart';

Widget buildThumbnailImage({
  required String? path,
  BoxFit fit = BoxFit.cover,
  BorderRadius? borderRadius,
}) {
  if (path == null || path.isEmpty) return const SizedBox.shrink();
  final child = Image.network(path, fit: fit);
  if (borderRadius == null) return child;
  return ClipRRect(borderRadius: borderRadius, child: child);
}


