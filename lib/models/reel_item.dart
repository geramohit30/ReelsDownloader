class ReelItem {
  final String id;              // e.g., timestamp-based
  final String sourceUrl;       // Instagram reel URL pasted by user
  final String filePath;        // Local path to downloaded mp4
  final String? thumbnailPath;  // Local path to generated jpg
  final DateTime createdAt;

  ReelItem({
    required this.id,
    required this.sourceUrl,
    required this.filePath,
    required this.createdAt,
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceUrl': sourceUrl,
    'filePath': filePath,
    'thumbnailPath': thumbnailPath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ReelItem.fromJson(Map<String, dynamic> json) => ReelItem(
    id: json['id'] as String,
    sourceUrl: json['sourceUrl'] as String,
    filePath: json['filePath'] as String,
    thumbnailPath: json['thumbnailPath'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
