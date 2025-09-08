/// Base interface for downloadable Instagram content
abstract class DownloadableItem {
  String get id;
  String get sourceUrl;
  String get filePath;
  String? get thumbnailPath;
  DateTime get createdAt;
  ContentType get contentType;
  
  Map<String, dynamic> toJson();
}

enum ContentType {
  reel,
  story;
  
  String get displayName {
    switch (this) {
      case ContentType.reel:
        return 'Reel';
      case ContentType.story:
        return 'Story';
    }
  }
  
  String get pluralName {
    switch (this) {
      case ContentType.reel:
        return 'Reels';
      case ContentType.story:
        return 'Stories';
    }
  }
}