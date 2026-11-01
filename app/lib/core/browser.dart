/// App browsers that Google refuses for sign-in ("disallowed_useragent"):
/// the pages people open from Instagram, Facebook, TikTok, Snapchat,
/// LinkedIn, LINE and WeChat, and any Android WebView. Telegram and
/// WhatsApp open links in the phone's real browser, so they are fine.
final RegExp _appBrowser = RegExp(
    r'FBAN|FBAV|FB_IAB|FBIOS|Instagram|musical_ly|BytedanceWebview|trill_|Snapchat|LinkedInApp| Line/|MicroMessenger');

bool isEmbeddedBrowser(String userAgent) {
  if (userAgent.isEmpty) return false;
  if (_appBrowser.hasMatch(userAgent)) return true;
  return userAgent.contains('Android') && userAgent.contains('; wv)');
}
