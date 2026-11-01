import 'package:a_studio/core/browser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app browsers Google refuses', () {
    const blocked = [
      // Instagram, Android
      'Mozilla/5.0 (Linux; Android 13; SM-A536B Build/TP1A.220624.014; wv) AppleWebKit/537.36 (KHTML, like Gecko) '
          'Version/4.0 Chrome/118.0.5993.80 Mobile Safari/537.36 Instagram 305.0.0.34.110 Android (33/13; 450dpi)',
      // Instagram, iPhone
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) '
          'Mobile/15E148 Instagram 302.0.0.23.115 (iPhone14,5; iOS 17_0; en_US; en)',
      // Facebook, iPhone
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) '
          'Mobile/15E148 [FBAN/FBIOS;FBAV/439.0.0.33.111;FBBV/553164390;FBDV/iPhone14,5]',
      // TikTok, iPhone
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) '
          'Mobile/15E148 musical_ly_32.2.0 JsSdk/2.0 NetType/WIFI Channel/App Store ByteLocale/en Region/ET',
      // Any other Android WebView
      'Mozilla/5.0 (Linux; Android 12; Pixel 6 Build/SD1A.210817.023; wv) AppleWebKit/537.36 (KHTML, like Gecko) '
          'Version/4.0 Chrome/94.0.4606.71 Mobile Safari/537.36',
    ];
    for (final ua in blocked) {
      expect(isEmbeddedBrowser(ua), isTrue, reason: ua);
    }
  });

  test('real browsers', () {
    const fine = [
      '', // tests and older browsers
      // Chrome, Android (also what Telegram opens links in)
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
      // Safari, iPhone
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) '
          'Version/17.0 Mobile/15E148 Safari/604.1',
      // Chrome, iPhone
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) '
          'CriOS/118.0.5993.92 Mobile/15E148 Safari/604.1',
      // Chrome, Windows
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
    ];
    for (final ua in fine) {
      expect(isEmbeddedBrowser(ua), isFalse, reason: ua);
    }
  });
}
