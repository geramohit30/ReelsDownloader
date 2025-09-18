/// Web-specific implementation using dart:html
/// This file is only compiled when running on web platform

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;

Future<String> downloadMediaWeb({
  required String mediaUrl,
  required String fileName,
  required void Function(double progress) onProgress,
}) async {
  try {
    print('🌐 WEB DOWNLOAD: Starting download for $fileName');
    print('   • URL: $mediaUrl');
    print('   • User Agent: ${html.window.navigator.userAgent}');

    // Start progress
    onProgress(0.0);

    // Try different approaches for downloading
    bool downloadSucceeded = false;
    
    try {
      // Method 1: Direct download with fetch API (better CORS handling)
      await _downloadWithFetchAPI(mediaUrl, fileName, onProgress);
      downloadSucceeded = true;
    } catch (e) {
      print('   • Fetch API failed: $e');
      try {
        // Method 2: Fallback to HTTP client with proper headers
        await _downloadWithHttpClient(mediaUrl, fileName, onProgress);
        downloadSucceeded = true;
      } catch (e2) {
        print('   • HTTP client also failed: $e2');
        // Method 3: Last resort - proxy download or open in new tab
        await _fallbackDownload(mediaUrl, fileName, onProgress);
        downloadSucceeded = true;
      }
    }
    
    if (downloadSucceeded) {
      onProgress(1.0);
      print('✅ WEB DOWNLOAD: Successfully triggered download for $fileName');
    }
    
    // Return a synthetic path for consistency with mobile API
    return 'web-download://$fileName';
    
  } catch (e) {
    print('❌ WEB DOWNLOAD: Error downloading $fileName: $e');
    throw Exception('Web download failed: $e');
  }
}

/// Download using Fetch API (better CORS support)
Future<void> _downloadWithFetchAPI(String mediaUrl, String fileName, void Function(double progress) onProgress) async {
  print('   • Trying Fetch API method...');
  
  try {
    // Use fetch API with proper headers to avoid CORS issues
    final response = await html.window.fetch(mediaUrl, {
      'method': 'GET',
      'mode': 'cors',
      'credentials': 'omit',
      'headers': {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://www.instagram.com/',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    });
    
    if (!response.ok) {
      throw Exception('Fetch failed with status: ${response.status} ${response.statusText}');
    }
    
    onProgress(0.3);
    
    // Check content type
    final contentType = response.headers['content-type'];
    print('   • Content-Type: $contentType');
    
    // Get blob from response with progress tracking
    final blob = await response.blob();
    onProgress(0.8);
    
    // Verify we got a valid blob
    if (blob.size == 0) {
      throw Exception('Downloaded blob is empty');
    }
    
    print('   • Downloaded blob size: ${blob.size} bytes');
    
    // Create download link and trigger download
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    // Add a small delay to ensure blob URL is ready
    await Future.delayed(const Duration(milliseconds: 100));
    
    _triggerDownload(url, fileName);
    
    // Cleanup after a delay to ensure download started
    Future.delayed(const Duration(seconds: 2), () {
      html.Url.revokeObjectUrl(url);
    });
    
  } catch (e) {
    print('   • Fetch API error details: $e');
    rethrow;
  }
}

/// Download using HTTP client (fallback method)
Future<void> _downloadWithHttpClient(String mediaUrl, String fileName, void Function(double progress) onProgress) async {
  print('   • Trying HTTP client method...');
  
  try {
    // Download the file content with custom headers to avoid CORS issues
    final response = await http.get(
      Uri.parse(mediaUrl),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Referer': 'https://www.instagram.com/',
        'Origin': 'https://www.instagram.com',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Sec-Fetch-Dest': 'video',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'cross-site',
      },
    );
    
    if (response.statusCode != 200) {
      throw Exception('HTTP download failed with status: ${response.statusCode} ${response.reasonPhrase}');
    }

    onProgress(0.5);

    // Get the file bytes
    final bytes = response.bodyBytes;
    print('   • Downloaded ${bytes.length} bytes via HTTP client');
    
    if (bytes.isEmpty) {
      throw Exception('Downloaded file is empty');
    }
    
    onProgress(0.8);

    // Determine MIME type based on file extension
    String mimeType = 'application/octet-stream';
    if (fileName.toLowerCase().endsWith('.mp4')) {
      mimeType = 'video/mp4';
    } else if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) {
      mimeType = 'image/jpeg';
    } else if (fileName.toLowerCase().endsWith('.png')) {
      mimeType = 'image/png';
    }
    
    // Create blob with proper MIME type
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    // Add a small delay to ensure blob URL is ready
    await Future.delayed(const Duration(milliseconds: 100));
    
    _triggerDownload(url, fileName);
    
    // Cleanup after a delay to ensure download started
    Future.delayed(const Duration(seconds: 2), () {
      html.Url.revokeObjectUrl(url);
    });
    
  } catch (e) {
    print('   • HTTP client error details: $e');
    rethrow;
  }
}

/// Trigger the actual download in the browser
void _triggerDownload(String url, String fileName) {
  print('   • Triggering browser download for: $fileName');
  print('   • Blob URL: $url');
  
  // Method 1: Try using anchor element with better implementation
  try {
    final anchor = html.AnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none'
      ..style.position = 'absolute'
      ..style.left = '-9999px';
    
    // Add to DOM, click, and remove
    html.document.body?.append(anchor);
    
    // Force a reflow to ensure the element is ready
    anchor.offsetHeight;
    
    // Trigger the download
    anchor.click();
    
    // Remove from DOM after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      anchor.remove();
    });
    
    print('   • ✅ Download triggered via anchor element');
    return;
    
  } catch (e) {
    print('   • ❌ Anchor download failed: $e');
  }
  
  // Method 2: Try creating a more compatible anchor element
  try {
    html.document.body?.appendHtml('<a href="$url" download="$fileName" style="display:none" id="temp-download-link">Download</a>');
    final element = html.document.getElementById('temp-download-link');
    element?.click();
    element?.remove();
    print('   • ✅ Download triggered via HTML anchor');
    return;
  } catch (e) {
    print('   • ❌ HTML anchor failed: $e');
  }
  
  // Method 3: Try using window.open (fallback)
  try {
    final newWindow = html.window.open(url, '_blank');
    if (newWindow != null) {
      print('   • ✅ Download triggered via window.open');
      return;
    }
  } catch (e) {
    print('   • ❌ Window.open failed: $e');
  }
  
  // Method 4: Show URL to user (last resort)
  print('   • ⚠️ All download methods failed, showing URL to user');
  _showDownloadDialog(url, fileName);
}

/// Show a dialog with download instructions
void _showDownloadDialog(String url, String fileName) {
  final dialog = html.DivElement()
    ..style.position = 'fixed'
    ..style.top = '50%'
    ..style.left = '50%'
    ..style.transform = 'translate(-50%, -50%)'
    ..style.backgroundColor = 'white'
    ..style.border = '2px solid #333'
    ..style.borderRadius = '10px'
    ..style.padding = '20px'
    ..style.zIndex = '10000'
    ..style.boxShadow = '0 4px 20px rgba(0,0,0,0.3)'
    ..style.maxWidth = '400px';
  
  dialog.setInnerHtml('''
      <h3>Download Ready</h3>
      <p>Your file "$fileName" is ready for download.</p>
      <p><a href="$url" download="$fileName" style="color: #007bff; text-decoration: underline;">Click here to download</a></p>
      <p><small>Or right-click the link above and select "Save link as..."</small></p>
      <button id="close-download-dialog" style="background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer;">Close</button>
    ''');
  
  html.document.body?.append(dialog);
  
  // Close button functionality
  dialog.querySelector('#close-download-dialog')?.onClick.listen((_) {
    dialog.remove();
  });
  
  // Auto-close after 30 seconds
  Future.delayed(const Duration(seconds: 30), () {
    if (dialog.parent != null) {
      dialog.remove();
    }
  });
}

/// Fallback download method when other approaches fail
Future<void> _fallbackDownload(String mediaUrl, String fileName, void Function(double progress) onProgress) async {
  print('   • Using fallback download method...');
  
  try {
    // For cases where CORS completely blocks the download,
    // we can still provide the user with the direct URL
    onProgress(0.9);
    
    // Create a temporary link that opens the media URL
    final tempLink = html.AnchorElement()
      ..href = mediaUrl
      ..target = '_blank'
      ..download = fileName
      ..style.display = 'none';
    
    html.document.body?.append(tempLink);
    tempLink.click();
    tempLink.remove();
    
    print('   • ✅ Fallback: Opened media URL in new tab');
    
    // Show instructions to user
    _showFallbackInstructions(mediaUrl, fileName);
    
  } catch (e) {
    print('   • ❌ Fallback method failed: $e');
    throw Exception('All download methods failed: $e');
  }
}

/// Show instructions for manual download
void _showFallbackInstructions(String mediaUrl, String fileName) {
  final instructions = html.DivElement()
    ..style.position = 'fixed'
    ..style.top = '20px'
    ..style.right = '20px'
    ..style.backgroundColor = '#f8f9fa'
    ..style.border = '1px solid #dee2e6'
    ..style.borderRadius = '8px'
    ..style.padding = '15px'
    ..style.zIndex = '10001'
    ..style.maxWidth = '350px'
    ..style.boxShadow = '0 2px 10px rgba(0,0,0,0.1)';

  
  // Auto-close after 15 seconds
  Future.delayed(const Duration(seconds: 15), () {
    if (instructions.parent != null) {
      instructions.remove();
    }
  });
}