class InstagramErrorHandler {
  static String getHelpfulErrorMessage(Exception error) {
    final errorMsg = error.toString();

    // Handle specific error patterns
    if (errorMsg.contains('FormatException') &&
        errorMsg.contains('<!DOCTYPE html')) {
      return _getHtmlResponseError();
    }

    if (errorMsg.contains('blocking API access') ||
        errorMsg.contains('anti-bot')) {
      return _getBlockedAccessError();
    }

    if (errorMsg.contains('Could not find a direct video URL')) {
      return _getNoVideoUrlError();
    }

    if (errorMsg.contains('requires login')) {
      return _getLoginRequiredError();
    }

    if (errorMsg.contains('private account')) {
      return _getPrivateAccountError();
    }

    if (errorMsg.contains('SocketException') ||
        errorMsg.contains('Failed host lookup')) {
      return _getNetworkError();
    }

    // Default enhanced error
    return _getGenericEnhancedError(errorMsg);
  }

  static String _getHtmlResponseError() {
    return '🚫 Instagram API Access Blocked\n\n'
        'Instagram is returning a webpage instead of data, which means:\n\n'
        '• Instagram has detected automated access\n'
        '• Your IP address may be temporarily blocked\n'
        '• Instagram requires browser-based verification\n'
        '• Rate limiting is in effect\n\n'
        '💡 Solutions to try:\n'
        '• Wait 15-30 minutes before trying again\n'
        '• Try using a different network (mobile data/WiFi)\n'
        '• Check if the reel is publicly accessible in a browser\n'
        '• Use a VPN to try from a different location\n\n'
        '⚠️ This is a temporary restriction by Instagram, not an app issue.';
  }

  static String _getBlockedAccessError() {
    return '🛡️ Instagram Anti-Bot Protection Active\n\n'
        'Instagram has activated protection measures:\n\n'
        '• Automated requests are being blocked\n'
        '• Geographic restrictions may apply\n'
        '• Account verification might be required\n'
        '• Rate limiting is in effect\n\n'
        '💡 What you can do:\n'
        '• Try again in 30-60 minutes\n'
        '• Use a different network connection\n'
        '• Check if Instagram works normally in your browser\n'
        '• Verify the reel URL is correct and public\n\n'
        '📋 This is Instagram\'s standard protection against automated access.';
  }

  static String _getNoVideoUrlError() {
    return '❌ Video Not Found\n\n'
        'Could not extract the video from this reel:\n\n'
        '• The reel might be private or restricted\n'
        '• Instagram may have changed their page structure\n'
        '• The content could be age-restricted\n'
        '• Geographic restrictions might apply\n\n'
        '💡 Try these solutions:\n'
        '• Make sure the reel is publicly accessible\n'
        '• Copy the URL again from Instagram\n'
        '• Try with a different public reel first\n'
        '• Check if you can view it in a web browser\n\n'
        '🔍 If other reels work, this specific reel has access restrictions.';
  }

  static String _getLoginRequiredError() {
    return '🔐 Login Required\n\n'
        'This reel requires you to be logged into Instagram:\n\n'
        '• The content is restricted to logged-in users\n'
        '• Instagram is enforcing authentication\n'
        '• The reel might be from a restricted account\n\n'
        '💡 Alternative options:\n'
        '• Try with a different, completely public reel\n'
        '• Make sure the reel link is correct\n'
        '• Verify the account is public, not private\n\n'
        '⚠️ Apps cannot bypass Instagram\'s login requirements for security reasons.';
  }

  static String _getPrivateAccountError() {
    return '🔒 Private Account Content\n\n'
        'This reel is from a private account or restricted content:\n\n'
        '• The account owner has made their content private\n'
        '• Only approved followers can access this content\n'
        '• The reel may have been deleted or made private\n\n'
        '💡 What to try:\n'
        '• Make sure you have the correct URL\n'
        '• Try with a reel from a public account\n'
        '• Check if the reel still exists on Instagram\n\n'
        '📝 Private content cannot be downloaded by third-party apps.';
  }

  static String _getNetworkError() {
    return '🌐 Network Connection Issue\n\n'
        'Cannot connect to Instagram servers:\n\n'
        '• No internet connection available\n'
        '• Instagram may be blocked in your region\n'
        '• DNS resolution problems\n'
        '• Firewall or proxy blocking access\n\n'
        '💡 Network troubleshooting:\n'
        '• Check your internet connection\n'
        '• Try switching between WiFi and mobile data\n'
        '• Run the network diagnostics test\n'
        '• Contact your network administrator if on corporate network\n\n'
        '🔧 Use the "Network Test" feature for detailed diagnostics.';
  }

  static String _getGenericEnhancedError(String originalError) {
    return '⚠️ Download Failed\n\n'
        'An unexpected error occurred:\n\n'
        '$originalError\n\n'
        '💡 General troubleshooting:\n'
        '• Make sure the Instagram URL is correct\n'
        '• Try with a different reel URL\n'
        '• Check your internet connection\n'
        '• Wait a few minutes and try again\n'
        '• Verify the reel is publicly accessible\n\n'
        '🔧 If problems persist, use the Network Diagnostics feature.';
  }

  static bool isInstagramBlocking(Exception error) {
    final errorMsg = error.toString();
    return errorMsg.contains('FormatException') &&
            errorMsg.contains('<!DOCTYPE html') ||
        errorMsg.contains('blocking API access') ||
        errorMsg.contains('anti-bot');
  }

  static bool isNetworkIssue(Exception error) {
    final errorMsg = error.toString();
    return errorMsg.contains('SocketException') ||
        errorMsg.contains('Failed host lookup') ||
        errorMsg.contains('Network error');
  }

  static bool requiresUserAction(Exception error) {
    final errorMsg = error.toString();
    return errorMsg.contains('requires login') ||
        errorMsg.contains('private account') ||
        errorMsg.contains('Could not find a direct video URL');
  }
}
