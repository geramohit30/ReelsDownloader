import 'package:flutter/widgets.dart';

import 'thumbnail_image_io.dart'
    if (dart.library.html) 'thumbnail_image_web.dart' as impl;

Widget buildThumbnailImage({
  required String? path,
  BoxFit fit = BoxFit.cover,
  BorderRadius? borderRadius,
}) {
  return impl.buildThumbnailImage(
    path: path,
    fit: fit,
    borderRadius: borderRadius,
  );
}


