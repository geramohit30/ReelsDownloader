# Local API Integration Guide

This guide explains how to use the Instagram Reel Downloader app with your local API server.

## Overview

The app now supports two modes for fetching Instagram reel data:
1. **Instagram Direct**: Fetches data directly from Instagram (existing functionality)
2. **Local API Server**: Uses your localhost:3000 API endpoint (new functionality)

## Your cURL Command Implementation

Your original cURL command:
```bash
curl --location 'http://localhost:3000/api/insta/reels' \
--header 'Content-Type: application/json' \
--data '{
    "url" : "https://www.instagram.com/reel/DKG8krgseWt/"
}'
```

Has been implemented in the `LocalApiService` class with the following features:

### 📁 Files Created/Modified

1. **`lib/services/local_api_service.dart`** - Main service handling API communication
2. **`lib/models/instagram_reel_data.dart`** - Data model for API responses
3. **`lib/providers/download_provider.dart`** - Updated to support local API
4. **`lib/screens/home_screen.dart`** - Added API source toggle
5. **`test/local_api_test.dart`** - Test examples and documentation

### 🚀 How It Works

1. **HTTP Client**: Uses Flutter's `http` package to make POST requests
2. **Request Format**: Exactly matches your cURL command structure
3. **Error Handling**: Comprehensive error handling with user-friendly messages
4. **Connection Testing**: Tests server availability before making requests

## API Response Format

Your localhost:3000 endpoint should return JSON in this format:

```json
{
  "id": "reel_id_or_shortcode",
  "media_url": "https://scontent.cdninstagram.com/video.mp4",
  "thumbnail_url": "https://scontent.cdninstagram.com/image.jpg",
  "title": "Reel title or caption",
  "author": "username", 
  "duration": 30
}
```

### Alternative Field Names (Also Supported)

```json
{
  "video_url": "...",     // instead of "media_url"
  "thumbnail": "...",     // instead of "thumbnail_url"
  "caption": "...",       // instead of "title"
  "username": "...",      // instead of "author"
  "user": "..."          // instead of "author"
}
```

## Using the Local API

### Method 1: Through the App UI

1. Open the Instagram Reel Downloader app
2. Look for the **"API Source"** card below the download button
3. Toggle the switch to **"Local API Server"**
4. Paste your Instagram reel URL
5. Tap **"Download Reel"**

The app will:
- Test connection to `localhost:3000`
- Send the exact POST request from your cURL command
- Parse the response and show preview
- Allow download as usual

### Method 2: Programmatically

```dart
import 'package:instareeldownloader/services/local_api_service.dart';

// Test connection first
final isConnected = await LocalApiService.testConnection();
if (!isConnected) {
  print('Local API server is not running');
  return;
}

// Fetch reel data
try {
  final reelData = await LocalApiService.fetchInstagramReel(
    'https://www.instagram.com/reel/DKG8krgseWt/'
  );
  
  print('Video URL: ${reelData.mediaUrl}');
  print('Author: ${reelData.author}');
  print('Title: ${reelData.title}');
} catch (e) {
  print('Error: $e');
}
```

## Error Handling

The implementation includes comprehensive error handling:

### Connection Errors
```
❌ Cannot connect to local API server. Please ensure the server is running on localhost:3000.
```

### Invalid URLs
```
❌ Please provide a valid Instagram reel URL.
```

### Server Errors
```
❌ The local API server encountered an error. Please check the server logs.
```

### Timeout Errors
```
❌ The request timed out. The local API server may be slow or unresponsive.
```

## Testing

Run the test file to verify your implementation:

```bash
flutter test test/local_api_test.dart
```

This will:
1. Test connection to localhost:3000
2. Send the same request as your cURL command
3. Verify response parsing
4. Test error handling

## Debugging

### Enable Debug Logging

The `LocalApiService` includes detailed debug logging:

```
🚀 LOCAL API: Fetching Instagram reel data
   • Target URL: https://www.instagram.com/reel/DKG8krgseWt/
   • API Endpoint: http://localhost:3000/api/insta/reels

📤 REQUEST DETAILS:
   • Method: POST
   • Headers: {Content-Type: application/json, Accept: application/json, ...}
   • Body: {"url":"https://www.instagram.com/reel/DKG8krgseWt/"}

📥 RESPONSE DETAILS:
   • Status Code: 200
   • Content-Type: application/json
   • Content Length: 1234 bytes

✅ SUCCESS RESPONSE:
   • Response parsed successfully
   • JSON keys: [id, media_url, thumbnail_url, title, author, duration]
```

### Common Issues

1. **Server Not Running**
   ```
   Solution: Start your server on localhost:3000
   ```

2. **Port Already in Use**
   ```
   Solution: Change server port or update LocalApiService._baseUrl
   ```

3. **CORS Issues**
   ```
   Solution: Ensure your server allows requests from localhost
   ```

4. **Invalid JSON Response**
   ```
   Solution: Check your API response format matches the expected structure
   ```

## Implementation Details

### Request Structure
- **URL**: `http://localhost:3000/api/insta/reels`
- **Method**: POST
- **Headers**: `Content-Type: application/json`
- **Body**: `{"url": "instagram_reel_url"}`
- **Timeout**: 30 seconds

### Response Handling
- **Success**: Status 200 with JSON data
- **Errors**: Any non-200 status with error message
- **Timeouts**: Automatic retry with user notification

### Security Features
- URL validation for Instagram domains only
- Request timeout protection
- Safe JSON parsing with fallbacks
- Connection testing before requests

## Integration with Download Flow

The local API integrates seamlessly with the existing download flow:

1. **Preview**: Fetches metadata for preview screen
2. **Download**: Uses the media URL from your API
3. **Thumbnails**: Uses thumbnail URL if provided
4. **Storage**: Saves to local device as usual

Your local API server becomes a drop-in replacement for the Instagram scraping logic, making it easy to switch between direct Instagram access and your custom backend.

## Next Steps

1. **Start your server** on localhost:3000
2. **Test the endpoint** with the provided cURL command
3. **Open the app** and toggle to "Local API Server"
4. **Try downloading** a reel to see the integration in action

The implementation is production-ready with proper error handling, logging, and user feedback!