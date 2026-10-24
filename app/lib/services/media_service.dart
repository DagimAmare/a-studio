import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';
import '../platform/media_types.dart';
import '../platform/web_bridge.dart' as bridge;

export '../platform/media_types.dart' show PickedMedia, MediaException;

class UploadResult {
  final String url;
  final String thumbUrl;
  final String type; // image | video
  const UploadResult(this.url, this.thumbUrl, this.type);
}

/// Photos and videos live on the cPanel host (same origin as the app),
/// written by /api/upload.php after it verifies the Firebase sign-in.
class MediaService {
  MediaService._();

  static Future<String> _token() async {
    final t = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (t == null || t.isEmpty) {
      throw const MediaException('Please sign in again to upload.');
    }
    return t;
  }

  static Future<List<PickedMedia>> pickImages({bool multiple = true}) =>
      bridge.pickImages(multiple: multiple);

  static Future<PickedMedia?> pickVideo() => bridge.pickVideo();

  /// Uploads a video and, when the browser can grab a frame, a poster image.
  static Future<UploadResult> uploadVideoWithPoster(PickedMedia video,
      {void Function(double fraction)? onProgress}) async {
    final main = await upload(video, onProgress: onProgress);
    if (main.thumbUrl.isNotEmpty) return main;
    final poster = await bridge.videoPoster(video);
    if (poster == null) return main;
    try {
      final p = await upload(poster);
      return UploadResult(main.url, p.url, 'video');
    } catch (_) {
      return main;
    }
  }

  static Future<UploadResult> upload(PickedMedia media,
      {void Function(double fraction)? onProgress}) async {
    final token = await _token();
    final res = await bridge.postMultipart(
      AppConfig.uploadEndpoint,
      media,
      {'idToken': token},
      onProgress: onProgress,
    );
    final url = res['url'];
    if (url is! String || url.isEmpty) {
      throw MediaException((res['error'] as String?) ?? 'Upload failed. Try again.');
    }
    final thumb = res['thumbUrl'] is String ? res['thumbUrl'] as String : '';
    return UploadResult(url, thumb, media.isVideo ? 'video' : 'image');
  }

  /// Private files (ID or Fayda photo, work video for verification) go to a
  /// folder outside the website. Returns the private path, never a URL.
  static Future<String> uploadPrivate(PickedMedia media, String kind,
      {void Function(double fraction)? onProgress}) async {
    final token = await _token();
    final res = await bridge.postMultipart(
      AppConfig.uploadEndpoint,
      media,
      {'idToken': token, 'private': '1', 'kind': kind},
      onProgress: onProgress,
    );
    final path = res['path'];
    if (path is! String || path.isEmpty) {
      throw MediaException((res['error'] as String?) ?? 'Upload failed. Try again.');
    }
    return path;
  }

  /// A temporary blob: URL for a private file (owner or admin only).
  static Future<String> privateObjectUrl(String path) async {
    final token = await _token();
    return bridge.fetchObjectUrl(AppConfig.mediaEndpoint,
        {'idToken': token, 'action': 'private_get', 'path': path});
  }

  static Future<void> deletePrivate(String path) async {
    if (path.isEmpty) return;
    try {
      final token = await _token();
      await bridge.postForm(AppConfig.mediaEndpoint,
          {'idToken': token, 'action': 'private_delete', 'path': path});
    } catch (_) {}
  }

  /// Best effort: removes a file we own from the host.
  static Future<void> delete(String url) async {
    if (url.isEmpty || !url.contains('/media/')) return;
    try {
      final token = await _token();
      await bridge.postForm(AppConfig.mediaEndpoint,
          {'idToken': token, 'action': 'delete', 'url': url});
    } catch (_) {}
  }

  /// Deletes every file this account uploaded (account deletion).
  static Future<bool> purgeAll() async {
    try {
      final token = await _token();
      await bridge.postForm(
          AppConfig.mediaEndpoint, {'idToken': token, 'action': 'purge'});
      return true;
    } catch (_) {
      return false;
    }
  }
}
