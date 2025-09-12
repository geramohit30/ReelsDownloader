import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Log screen view (page navigation)
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenName,
    );
  }

  /// Log when a download starts
  static Future<void> logDownloadStarted(String reelId) async {
    await _analytics.logEvent(
      name: 'download_started',
      parameters: {
        'reel_id': reelId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log when a download completes
  static Future<void> logDownloadCompleted(String reelId) async {
    await _analytics.logEvent(
      name: 'download_completed',
      parameters: {
        'reel_id': reelId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log a generic custom event
  static Future<void> logCustomEvent(String eventName, Map<String, Object>? params) async {
    await _analytics.logEvent(name: eventName, parameters: params);
  }
}
