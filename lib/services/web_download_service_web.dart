/// Web-specific implementation using dart:html
/// This file is only compiled when running on web platform

import 'dart:async';
import 'dart:html' as html;

Future<String> downloadMediaWeb({
  required String mediaUrl,
  required String fileName,
  required void Function(double progress) onProgress,
}) async {
  try {
    print('🌐 WEB DOWNLOAD: Starting direct download for $fileName');
    print('   • URL: $mediaUrl');

    // Start progress
    onProgress(0.0);

    // Use XMLHttpRequest to download content and force download
    await _xmlHttpRequestDownload(mediaUrl, fileName);
    
    onProgress(1.0);
    print('✅ WEB DOWNLOAD: Direct download triggered for $fileName');
    
    // Return a synthetic path for consistency with mobile API
    return 'web-download://$fileName';
    
  } catch (e) {
    print('❌ WEB DOWNLOAD: Error downloading $fileName: $e');
    print('   • Stack trace: ${StackTrace.current}');
    throw Exception('Web download failed: $e');
  }
}

/// Use XMLHttpRequest to download content and force download
Future<void> _xmlHttpRequestDownload(String mediaUrl, String fileName) async {
  print('   • Using XMLHttpRequest method for: $fileName');
  print('   • Media URL: $mediaUrl');
  
  try {
    // Create XMLHttpRequest
    final xhr = html.HttpRequest();
    xhr.open('GET', mediaUrl);
    xhr.responseType = 'blob'; // Important: set response type to blob
    
    // Set up onload handler
    xhr.onLoad.first.then((_) {
      if (xhr.status == 200) {
        print('   • XMLHttpRequest successful, creating download');
        final blob = xhr.response as html.Blob;
        
        // Create a blob with application/octet-stream to force download
        final downloadBlob = html.Blob([blob], 'application/octet-stream');
        final url = html.Url.createObjectUrlFromBlob(downloadBlob);
        
        // Create invisible anchor element
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..setAttribute('download', fileName)
          ..style.display = 'none';
        
        // Add to DOM, click, and remove
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        
        // Clean up URL object after delay
        Future.delayed(const Duration(seconds: 10), () {
          html.Url.revokeObjectUrl(url);
        });
        
        print('   • ✅ Direct download triggered successfully');
      } else {
        print('   • ❌ XMLHttpRequest failed with status: ${xhr.status}');
        // Try fallback method
        _fallbackDownload(mediaUrl, fileName);
      }
    });
    
    // Set up onerror handler
    xhr.onError.first.then((_) {
      print('   • ❌ XMLHttpRequest error occurred');
      // Try fallback method
      _fallbackDownload(mediaUrl, fileName);
    });
    
    // Send the request
    xhr.send();
  } catch (e) {
    print('   • ❌ XMLHttpRequest failed: $e');
    // Try fallback method
    _fallbackDownload(mediaUrl, fileName);
  }
}

/// Fallback download method
void _fallbackDownload(String mediaUrl, String fileName) {
  try {
    print('   • Trying fallback method with modified headers');
    
    // Create XMLHttpRequest with custom headers
    final xhr = html.HttpRequest();
    xhr.open('GET', mediaUrl);
    xhr.responseType = 'blob';
    
    // Try to set headers that might help with download
    try {
      xhr.setRequestHeader('Accept', 'application/octet-stream');
    } catch (e) {
      print('   • Could not set Accept header: $e');
    }
    
    xhr.onLoad.first.then((_) {
      if (xhr.status == 200) {
        final blob = xhr.response as html.Blob;
        
        // Force download with generic content type
        final downloadBlob = html.Blob([blob], 'application/octet-stream');
        final url = html.Url.createObjectUrlFromBlob(downloadBlob);
        
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..setAttribute('download', fileName)
          ..style.display = 'none';
        
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        
        html.Url.revokeObjectUrl(url);
        print('   • ✅ Fallback download triggered successfully');
      } else {
        print('   • ❌ Fallback XMLHttpRequest failed with status: ${xhr.status}');
        // Last resort: try simple anchor
        _lastResortDownload(mediaUrl, fileName);
      }
    });
    
    xhr.onError.first.then((_) {
      print('   • ❌ Fallback XMLHttpRequest error occurred');
      _lastResortDownload(mediaUrl, fileName);
    });
    
    xhr.send();
  } catch (e) {
    print('   • ❌ Fallback XMLHttpRequest failed: $e');
    _lastResortDownload(mediaUrl, fileName);
  }
}

/// Last resort download method
void _lastResortDownload(String mediaUrl, String fileName) {
  try {
    print('   • Trying last resort method');
    
    // Create a temporary anchor with download attribute and special handling
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = mediaUrl
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    
    // Try to force download by temporarily changing the href
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    print('   • ✅ Last resort download triggered');
  } catch (e) {
    print('   • ❌ All download methods failed: $e');
    // Final fallback: open in new tab with instructions
    print('   • Opening in new tab as last resort');
    html.window.open(mediaUrl, '_blank');
  }
}
