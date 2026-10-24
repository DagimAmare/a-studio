import 'package:flutter/widgets.dart';

import 'media_types.dart';

String? readLocal(String key) => null;
void writeLocal(String key, String value) {}

Future<List<PickedMedia>> pickImages({bool multiple = true}) async => const [];
Future<PickedMedia?> pickVideo() async => null;

Future<PickedMedia?> videoPoster(PickedMedia video) async => null;

Future<Map<String, dynamic>> postMultipart(
  String url,
  PickedMedia media,
  Map<String, String> fields, {
  void Function(double fraction)? onProgress,
}) async =>
    throw const MediaException('Uploads work in the web app.');

Future<Map<String, dynamic>> postForm(String url, Map<String, String> fields) async =>
    throw const MediaException('Not available here.');

Future<Map<String, dynamic>> postJson(String url, Map<String, dynamic> body) async =>
    throw const MediaException('Not available here.');

Future<String> fetchObjectUrl(String url, Map<String, String> fields) async =>
    throw const MediaException('Not available here.');

Widget htmlVideo(String url,
        {bool autoplay = false,
        bool muted = false,
        bool loop = false,
        bool controls = true,
        bool cover = false}) =>
    const SizedBox.shrink();

Future<bool> nativeShare(
        {required String title, required String text, required String url}) async =>
    false;

void downloadText(String filename, String text, {String mime = 'application/json'}) {}

void removeSplash() {}

void setDocumentTitle(String title) {}
