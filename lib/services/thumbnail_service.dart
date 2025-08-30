import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ThumbnailService {
  Future<String?> generate(String videoPath) async {
    final bytes = await VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      quality: 70,
    );
    if (bytes == null) return null;

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
