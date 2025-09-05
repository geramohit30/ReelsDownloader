import 'dart:io';
import 'package:http/http.dart' as http;

class NetworkDiagnostics {
  static Future<NetworkDiagnosticsResult> runDiagnostics() async {
    final result = NetworkDiagnosticsResult();

    // Test 1: Basic internet connectivity
    try {
      final googleResult = await InternetAddress.lookup(
        'www.google.com',
      ).timeout(const Duration(seconds: 10));
      result.hasBasicInternet =
          googleResult.isNotEmpty && googleResult[0].rawAddress.isNotEmpty;
    } catch (e) {
      result.hasBasicInternet = false;
      result.errors.add('No basic internet connection: ${e.toString()}');
    }

    // Test 2: Instagram domain resolution
    try {
      final instagramResult = await InternetAddress.lookup(
        'www.instagram.com',
      ).timeout(const Duration(seconds: 10));
      result.canResolveInstagram = instagramResult.isNotEmpty;
      if (result.canResolveInstagram) {
        result.instagramIpAddress = instagramResult[0].address;
      }
    } catch (e) {
      result.canResolveInstagram = false;
      result.errors.add('Cannot resolve Instagram domain: ${e.toString()}');
    }

    // Test 3: Instagram HTTPS connectivity
    if (result.canResolveInstagram) {
      try {
        final response = await http
            .get(
              Uri.parse('https://www.instagram.com'),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 11; SAMSUNG SM-G973U) AppleWebKit/537.36',
              },
            )
            .timeout(const Duration(seconds: 15));

        result.canConnectToInstagram = response.statusCode == 200;
        result.instagramHttpStatus = response.statusCode;
      } catch (e) {
        result.canConnectToInstagram = false;
        result.errors.add('Cannot connect to Instagram: ${e.toString()}');
      }
    }

    // Test 4: Check if running in emulator
    result.isEmulator = await _checkIfEmulator();

    return result;
  }

  static Future<bool> _checkIfEmulator() async {
    try {
      // Check for common emulator indicators
      if (Platform.isAndroid) {
        final result = await Process.run('getprop', ['ro.product.model']);
        final model = result.stdout.toString().toLowerCase();
        return model.contains('sdk') || model.contains('emulator');
      }
    } catch (e) {
      // If we can't determine, assume it's a real device
    }
    return false;
  }

  static String generateTroubleshootingReport(NetworkDiagnosticsResult result) {
    final buffer = StringBuffer();
    buffer.writeln('🔍 Network Diagnostics Report');
    buffer.writeln('=' * 40);
    buffer.writeln();

    buffer.writeln('📡 Basic Connectivity:');
    buffer.writeln(
      '  Internet Access: ${result.hasBasicInternet ? "✅ Working" : "❌ Failed"}',
    );
    buffer.writeln(
      '  Instagram Domain: ${result.canResolveInstagram ? "✅ Resolved" : "❌ Failed"}',
    );
    if (result.instagramIpAddress != null) {
      buffer.writeln('  Instagram IP: ${result.instagramIpAddress}');
    }
    buffer.writeln(
      '  Instagram HTTPS: ${result.canConnectToInstagram ? "✅ Working" : "❌ Failed"}',
    );
    if (result.instagramHttpStatus != null) {
      buffer.writeln('  HTTP Status: ${result.instagramHttpStatus}');
    }
    buffer.writeln();

    buffer.writeln('💻 Environment:');
    buffer.writeln('  Platform: ${Platform.operatingSystem}');
    buffer.writeln('  Emulator: ${result.isEmulator ? "Yes" : "No"}');
    buffer.writeln();

    if (result.errors.isNotEmpty) {
      buffer.writeln('❌ Errors Found:');
      for (int i = 0; i < result.errors.length; i++) {
        buffer.writeln('  ${i + 1}. ${result.errors[i]}');
      }
      buffer.writeln();
    }

    buffer.writeln('💡 Troubleshooting Steps:');

    if (!result.hasBasicInternet) {
      buffer.writeln('  • Check your Wi-Fi or mobile data connection');
      buffer.writeln('  • Try opening a web browser and visiting google.com');
      if (result.isEmulator) {
        buffer.writeln('  • Restart your emulator');
        buffer.writeln('  • Check emulator network settings');
      }
    } else if (!result.canResolveInstagram) {
      buffer.writeln('  • Instagram may be blocked in your region');
      buffer.writeln('  • Try using a VPN');
      buffer.writeln('  • Check if Instagram is down (downdetector.com)');
    } else if (!result.canConnectToInstagram) {
      buffer.writeln('  • Instagram servers may be temporarily unavailable');
      buffer.writeln('  • Try again in a few minutes');
      buffer.writeln('  • Check if your firewall is blocking the connection');
    } else {
      buffer.writeln('  • Network connectivity appears to be working');
      buffer.writeln(
        '  • The issue may be with Instagram\'s API or content restrictions',
      );
      buffer.writeln('  • Try with a different Instagram reel URL');
    }

    return buffer.toString();
  }
}

class NetworkDiagnosticsResult {
  bool hasBasicInternet = false;
  bool canResolveInstagram = false;
  bool canConnectToInstagram = false;
  bool isEmulator = false;
  String? instagramIpAddress;
  int? instagramHttpStatus;
  List<String> errors = [];

  bool get isNetworkHealthy =>
      hasBasicInternet && canResolveInstagram && canConnectToInstagram;
}
