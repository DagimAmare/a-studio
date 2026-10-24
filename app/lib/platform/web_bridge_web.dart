// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

import 'media_types.dart';

String? readLocal(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void writeLocal(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

Future<Uint8List> _read(html.File file) async {
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoadEnd.first;
  final result = reader.result;
  if (result is! Uint8List) {
    throw MediaException('Could not read "${file.name}".');
  }
  return result;
}

/// Downscale in the browser (canvas) so phones on mobile data upload
/// ~300 KB instead of a 6 MB camera original. GIFs stay untouched;
/// any failure falls back to the original bytes.
Future<Uint8List> _shrink(Uint8List bytes, String mime) async {
  if (mime == 'image/gif') return bytes;
  final blobUrl = html.Url.createObjectUrlFromBlob(html.Blob([bytes], mime));
  try {
    final img = html.ImageElement();
    final loaded = Completer<bool>();
    img.onLoad.first.then((_) {
      if (!loaded.isCompleted) loaded.complete(true);
    });
    img.onError.first.then((_) {
      if (!loaded.isCompleted) loaded.complete(false);
    });
    img.src = blobUrl;
    if (!await loaded.future) return bytes;
    final w = img.naturalWidth;
    final h = img.naturalHeight;
    if (w <= 0 || h <= 0) return bytes;
    final longest = w > h ? w : h;
    // Small PNGs pass through. Every JPEG and WebP is redrawn, which also
    // strips EXIF data such as the GPS location a phone camera records.
    if (mime == 'image/png' && longest <= kImageMaxSide && bytes.lengthInBytes <= 900 * 1024) {
      return bytes;
    }
    final scale = longest <= kImageMaxSide ? 1.0 : kImageMaxSide / longest;
    final tw = (w * scale).round();
    final th = (h * scale).round();
    final canvas = html.CanvasElement(width: tw, height: th);
    canvas.context2D.drawImageScaled(img, 0, 0, tw, th);
    final png = mime == 'image/png';
    final dataUrl = png
        ? canvas.toDataUrl('image/png')
        : canvas.toDataUrl('image/jpeg', kJpegQuality);
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return bytes;
    final out = base64Decode(dataUrl.substring(comma + 1));
    // Keep the re-encoded copy for JPEG/WebP even if slightly larger, so
    // location data never leaves the phone.
    if (!png) return out;
    return out.lengthInBytes < bytes.lengthInBytes ? out : bytes;
  } catch (_) {
    return bytes;
  } finally {
    html.Url.revokeObjectUrl(blobUrl);
  }
}

Future<List<html.File>> _choose(String accept, bool multiple) async {
  final input = html.FileUploadInputElement()
    ..accept = accept
    ..multiple = multiple;
  final completer = Completer<List<html.File>>();
  input.onChange.first.then((_) {
    if (!completer.isCompleted) completer.complete(input.files ?? const []);
  });
  input.click();
  return completer.future;
}

Future<List<PickedMedia>> pickImages({bool multiple = true}) async {
  final files =
      await _choose('image/jpeg,image/png,image/webp,image/gif', multiple);
  final out = <PickedMedia>[];
  for (final f in files) {
    if (f.size > 40 * 1024 * 1024) {
      throw MediaException('"${f.name}" is larger than 40 MB.');
    }
    final raw = await _read(f);
    final mime = f.type.isEmpty ? 'image/jpeg' : f.type;
    final shrunk = await _shrink(raw, mime);
    if (shrunk.lengthInBytes > kImageMaxBytes) {
      throw MediaException('"${f.name}" is too large even after compression.');
    }
    final outMime = (mime == 'image/png' || mime == 'image/gif') ? mime : 'image/jpeg';
    var name = f.name;
    if (outMime == 'image/jpeg' && !name.toLowerCase().endsWith('.jpg')) {
      final dot = name.lastIndexOf('.');
      name = '${dot > 0 ? name.substring(0, dot) : name}.jpg';
    }
    out.add(PickedMedia(
      bytes: shrunk,
      name: name,
      mime: outMime,
      size: shrunk.lengthInBytes,
      isVideo: false,
    ));
  }
  return out;
}

Future<PickedMedia?> pickVideo() async {
  final files = await _choose('video/mp4,video/webm,video/quicktime', false);
  if (files.isEmpty) return null;
  final f = files.first;
  if (f.size > kVideoMaxBytes) {
    throw const MediaException('Videos must be 64 MB or smaller. Trim it and try again.');
  }
  return PickedMedia(
    file: f,
    name: f.name,
    mime: f.type.isEmpty ? 'video/mp4' : f.type,
    size: f.size,
    isVideo: true,
  );
}

/// A JPEG still from about one second into a picked video, used as the
/// poster in portfolio grids. Null when the browser cannot decode it.
Future<PickedMedia?> videoPoster(PickedMedia video) async {
  final file = video.file;
  if (file is! html.File) return null;
  final url = html.Url.createObjectUrlFromBlob(file);
  final v = html.VideoElement()
    ..muted = true
    ..preload = 'auto';
  v.setAttribute('playsinline', 'true');
  try {
    final meta = v.onLoadedMetadata.first;
    v.src = url;
    await meta.timeout(const Duration(seconds: 20));
    final duration = v.duration;
    final seeked = v.onSeeked.first;
    v.currentTime = (duration.isFinite && duration > 2) ? 1.0 : 0.1;
    await seeked.timeout(const Duration(seconds: 20));
    final w = v.videoWidth;
    final h = v.videoHeight;
    if (w <= 0 || h <= 0) return null;
    final longest = w > h ? w : h;
    final scale = longest <= 900 ? 1.0 : 900 / longest;
    final tw = (w * scale).round();
    final th = (h * scale).round();
    final canvas = html.CanvasElement(width: tw, height: th);
    canvas.context2D.drawImageScaled(v, 0, 0, tw, th);
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.8);
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    final bytes = base64Decode(dataUrl.substring(comma + 1));
    if (bytes.lengthInBytes < 2000) return null;
    return PickedMedia(
      bytes: bytes,
      name: 'poster.jpg',
      mime: 'image/jpeg',
      size: bytes.lengthInBytes,
      isVideo: false,
    );
  } catch (_) {
    return null;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}

Map<String, dynamic> _decode(html.HttpRequest req) {
  Map<String, dynamic> body = const {};
  try {
    final parsed = jsonDecode(req.responseText ?? '{}');
    if (parsed is Map) body = Map<String, dynamic>.from(parsed);
  } catch (_) {}
  if (req.status != 200) {
    throw MediaException(
        (body['error'] as String?) ?? 'Upload failed (HTTP ${req.status}).');
  }
  return body;
}

/// Multipart POST with real progress. The shared host can take a couple of
/// minutes to answer big videos (learned on Alfam), hence the long timeout.
Future<Map<String, dynamic>> postMultipart(
  String url,
  PickedMedia media,
  Map<String, String> fields, {
  void Function(double fraction)? onProgress,
}) async {
  final form = html.FormData();
  final blob = media.file is html.File
      ? media.file as html.File
      : html.Blob([media.bytes ?? Uint8List(0)], media.mime);
  form.appendBlob('file', blob, media.name);
  fields.forEach(form.append);
  final req = html.HttpRequest();
  final done = Completer<void>();
  req
    ..open('POST', url)
    ..timeout = 15 * 60 * 1000;
  req.upload.onProgress.listen((e) {
    final total = e.total ?? 0;
    final sent = e.loaded ?? 0;
    if (onProgress != null && total > 0) onProgress(sent / total);
  });
  req.onLoad.listen((_) {
    if (!done.isCompleted) done.complete();
  });
  req.onError.listen((_) {
    if (!done.isCompleted) {
      done.completeError(const MediaException(
          'Could not reach the upload server. Check your connection.'));
    }
  });
  req.onTimeout.listen((_) {
    if (!done.isCompleted) {
      done.completeError(
          const MediaException('The upload took too long. Try a smaller file.'));
    }
  });
  req.send(form);
  await done.future;
  return _decode(req);
}

Future<Map<String, dynamic>> postForm(String url, Map<String, String> fields) async {
  final form = html.FormData();
  fields.forEach(form.append);
  final req = html.HttpRequest();
  final done = Completer<void>();
  req
    ..open('POST', url)
    ..timeout = 60 * 1000;
  req.onLoad.listen((_) {
    if (!done.isCompleted) done.complete();
  });
  req.onError.listen((_) {
    if (!done.isCompleted) {
      done.completeError(const MediaException('Network error.'));
    }
  });
  req.onTimeout.listen((_) {
    if (!done.isCompleted) done.completeError(const MediaException('Timed out.'));
  });
  req.send(form);
  await done.future;
  return _decode(req);
}

/// JSON POST (Cloud Functions). Errors carry the server's message.
Future<Map<String, dynamic>> postJson(String url, Map<String, dynamic> body) async {
  final req = html.HttpRequest();
  final done = Completer<void>();
  req
    ..open('POST', url)
    ..timeout = 60 * 1000
    ..setRequestHeader('Content-Type', 'application/json');
  req.onLoad.listen((_) {
    if (!done.isCompleted) done.complete();
  });
  req.onError.listen((_) {
    if (!done.isCompleted) {
      done.completeError(const MediaException('No connection. Check your internet and try again.'));
    }
  });
  req.onTimeout.listen((_) {
    if (!done.isCompleted) done.completeError(const MediaException('That took too long. Try again.'));
  });
  req.send(jsonEncode(body));
  await done.future;
  Map<String, dynamic> out = const {};
  try {
    final parsed = jsonDecode(req.responseText ?? '{}');
    if (parsed is Map) out = Map<String, dynamic>.from(parsed);
  } catch (_) {}
  if (req.status != 200) {
    throw MediaException((out['error'] as String?) ?? 'Something went wrong (HTTP ${req.status}).');
  }
  return out;
}

/// POSTs a form and returns a blob: URL for the file that comes back
/// (private verification files, shown only to their owner and admins).
Future<String> fetchObjectUrl(String url, Map<String, String> fields) async {
  final form = html.FormData();
  fields.forEach(form.append);
  final req = html.HttpRequest();
  final done = Completer<void>();
  req
    ..open('POST', url)
    ..responseType = 'blob'
    ..timeout = 120 * 1000;
  req.onLoad.listen((_) {
    if (!done.isCompleted) done.complete();
  });
  req.onError.listen((_) {
    if (!done.isCompleted) done.completeError(const MediaException('Network error.'));
  });
  req.onTimeout.listen((_) {
    if (!done.isCompleted) done.completeError(const MediaException('Timed out.'));
  });
  req.send(form);
  await done.future;
  if (req.status != 200 || req.response is! html.Blob) {
    throw MediaException('Could not open the file (HTTP ${req.status}).');
  }
  return html.Url.createObjectUrlFromBlob(req.response as html.Blob);
}

int _seq = 0;

/// A native <video> element. On web, video_player rejects some valid MP4s
/// (seen on Alfam), while a plain element plays them all.
Widget htmlVideo(String url,
    {bool autoplay = false,
    bool muted = false,
    bool loop = false,
    bool controls = true,
    bool cover = false}) {
  final viewType = 'astudio-video-${_seq++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
    final v = html.VideoElement()
      ..src = url
      ..controls = controls
      ..autoplay = autoplay
      ..muted = muted
      ..loop = loop
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = cover ? 'cover' : 'contain'
      ..style.backgroundColor = '#14100E'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('preload', autoplay ? 'auto' : 'metadata');
    if (muted) v.setAttribute('muted', 'true');
    return v;
  });
  return HtmlElementView(viewType: viewType);
}

Future<bool> nativeShare(
    {required String title, required String text, required String url}) async {
  try {
    await html.window.navigator.share({'title': title, 'text': text, 'url': url});
    return true;
  } catch (_) {
    return false;
  }
}

/// Saves text as a file in the browser's downloads (data export).
void downloadText(String filename, String text, {String mime = 'application/json'}) {
  final blob = html.Blob([text], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(a);
  a.click();
  a.remove();
  Future<void>.delayed(const Duration(seconds: 30), () => html.Url.revokeObjectUrl(url));
}

/// Removes the CSS splash from index.html once Flutter has drawn.
void removeSplash() {
  try {
    html.document.getElementById('splash')?.remove();
  } catch (_) {}
}

void setDocumentTitle(String title) {
  try {
    html.document.title = title;
  } catch (_) {}
}
