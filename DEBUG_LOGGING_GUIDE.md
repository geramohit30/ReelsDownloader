# Debug Logging Guide - Instagram Reel Download

## 🎯 Debug Information Added

I've added comprehensive debug logging to show exactly what data is being received from Instagram when hitting their URLs. Here's what you'll see in the logs:

## 📱 Debug Log Output Format

### 🚀 **Initial Process Start**
```
🚀 Starting Instagram Reel Download Process
🚀 URL: https://www.instagram.com/reel/ABC123DEF45/
🚀 Shortcode: ABC123DEF45
🟢 Network connectivity check passed
```

### 🔄 **Strategy 1: GraphQL API Attempt**
```
🔄 Attempting Strategy 1: GraphQL API
🟦 GraphQL Response Debug:
🟦 URL: https://www.instagram.com/api/graphql/
🟦 Status Code: 200
🟦 Content Length: 1234
🟦 Response Headers: {content-type: application/json, ...}
🟦 First 500 chars of response: {"data":{"xdt_shortcode_media":...}
```

#### Success Case:
```
🟢 Successfully parsed JSON response
🟢 JSON Keys: [data, extensions]
🟢 Data field exists: _Map<String, dynamic>
🟢 Data keys: [xdt_shortcode_media]
🟢 GraphQL Strategy SUCCESS: Found video URL: https://scontent.cdninstagram.com/...
```

#### HTML Response Case (Instagram Blocking):
```
🔴 Instagram returned HTML instead of JSON - Anti-bot protection active!
🔴 Full HTML response (first 1000 chars): <!DOCTYPE html><html class="_9dls touch _ar44" lang="en"...
🔴 GraphQL Strategy FAILED: Instagram is blocking API access...
```

#### JSON Parse Error Case:
```
🔴 JSON Parse Error: FormatException: Unexpected character...
🔴 Raw response that failed to parse (first 1000 chars): Some unexpected content...
🔴 GraphQL Strategy FAILED: Invalid response format...
```

### 🔄 **Strategy 2: HTML Parsing Attempt**
```
🔄 Attempting Strategy 2: HTML Parsing
🟦 HTML Response Debug:
🟦 URL: https://www.instagram.com/reel/ABC123DEF45/
🟦 Status Code: 200
🟦 Content Length: 45678
🟦 Response Headers: {content-type: text/html, ...}
🟦 HTML Title: Instagram Reel by @username
🟦 Contains video meta tags: true
🟦 Contains JSON data: false
🟦 First 300 chars of HTML: <!DOCTYPE html><html class="_9dls...
```

#### Video URL Extraction Attempts:
```
🔍 Trying Strategy 1: Open Graph og:video meta tag
🟢 Strategy 1 SUCCESS: Found og:video URL: https://scontent.cdninstagram.com/video.mp4

OR

🔴 Strategy 1 FAILED: No og:video meta tag found
🔍 Trying Strategy 2: Open Graph og:video:secure_url meta tag
🔴 Strategy 2 FAILED: No og:video:secure_url meta tag found
🔍 Trying Strategy 3: JSON video_url extraction
🔴 Strategy 3 FAILED: No video_url in JSON found
🔍 Trying Strategy 4: Alternative video URL patterns
🔍 Searching for alternative video URL patterns...
🔍 Trying alternative pattern 1: "playback_url"\s*:\s*"([^"]+?\.mp4[^"]*)"
🔴 Alternative pattern 1 FAILED: No match
🔍 Trying alternative pattern 2: "src"\s*:\s*"([^"]+?fbcdn[^"]*\.mp4[^"]*)"
🔴 Alternative pattern 2 FAILED: No match
🔍 Trying alternative pattern 3: "url"\s*:\s*"([^"]+?instagram[^"]*\.mp4[^"]*)"
🔴 Alternative pattern 3 FAILED: No match
🔍 Trying alternative pattern 4: "([^"]*scontent[^"]*\.mp4[^"]*)"
🔴 Alternative pattern 4 FAILED: No match
🔴 Strategy 4 FAILED: No alternative video URLs found
🔴 ALL STRATEGIES FAILED - No video URL found in HTML
```

#### Final Success Case:
```
🟢 HTML Parsing Strategy SUCCESS: Found video URL: https://scontent.cdninstagram.com/video.mp4
```

#### Final Failure Case:
```
🔴 HTML Parsing Strategy FAILED: Could not find a direct video URL...
🔴 ALL STRATEGIES FAILED
```

## 🔍 **Key Information You'll See**

### **GraphQL Response Analysis**
- **Status codes**: HTTP response status
- **Headers**: Response headers from Instagram
- **Content type**: Whether Instagram returned JSON or HTML
- **Response size**: How much data was returned
- **JSON structure**: What fields are present in successful JSON responses
- **Error details**: Specific GraphQL errors if any

### **HTML Response Analysis**
- **Page title**: What Instagram page title says
- **Meta tags presence**: Whether video meta tags exist
- **JSON data**: Whether embedded JSON data is found
- **Content sample**: First few characters to identify the page type
- **Pattern matching**: Which regex patterns match for video URLs

### **Network Information**
- **URLs being accessed**: Exact endpoints being called
- **Request headers**: What headers are being sent
- **Response headers**: What Instagram is sending back
- **Timeouts**: If requests are timing out

## 📊 **How to Use This Debug Information**

### **For Network Issues**:
- Look for `SocketException` or `Failed host lookup` messages
- Check if status codes are 200 (success) or error codes
- Verify if Instagram is returning HTML login pages

### **For Instagram Blocking**:
- Watch for HTML responses instead of JSON from GraphQL
- Look for specific error patterns in response content
- Check if different strategies find different results

### **For URL Extraction Issues**:
- See which regex patterns are being tried
- Check if meta tags or JSON data structures exist
- Identify if Instagram has changed their page structure

## 🧪 **Testing Instructions**

1. **Run your app**: `flutter run`
2. **Try downloading a reel**: Paste any Instagram reel URL
3. **Watch the console**: You'll see detailed debug output
4. **Analyze the results**: Use the patterns above to understand what's happening

The debug output will show you exactly what Instagram is returning and help identify why downloads might be failing!