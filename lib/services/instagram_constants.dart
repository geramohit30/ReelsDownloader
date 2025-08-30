class InstagramEndpoints {
  static const String getByPost = '/p';
  static const String getByGraphQL = '/api/graphql/';
  static const String baseUrl = 'https://www.instagram.com';
}

class InstagramHeaders {
  static const String userAgentMobile =
      'Mozilla/5.0 (Linux; Android 11; SAMSUNG SM-G973U) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/14.2 Chrome/87.0.4280.141 Mobile Safari/537.36';

  static const String userAgentDesktop =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/117.0';

  static const String xIgAppId = '1217981644879628';
  static const String xCsrfToken = 'RVDUooU5MYsBbS1CNN3CzVAuEP8oHB52';
  static const String xFbLsd = 'AVqbxe3J_YA';
  static const String xAsbdId = '129477';
}
