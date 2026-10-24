import 'dart:typed_data';

/// A file the user picked, ready to upload. On web [file] is the browser
/// File (videos stream from it); images are already downscaled into [bytes].
class PickedMedia {
  final Uint8List? bytes;
  final Object? file;
  final String name;
  final String mime;
  final int size;
  final bool isVideo;

  const PickedMedia({
    this.bytes,
    this.file,
    required this.name,
    required this.mime,
    required this.size,
    required this.isVideo,
  });
}

class MediaException implements Exception {
  final String message;
  const MediaException(this.message);
  @override
  String toString() => message;
}

const int kImageMaxBytes = 8 * 1024 * 1024; // keep in sync with upload.php
const int kVideoMaxBytes = 64 * 1024 * 1024; // keep in sync with upload.php
const int kImageMaxSide = 1600;
const double kJpegQuality = 0.84;
