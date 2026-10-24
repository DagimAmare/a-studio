import 'package:flutter/material.dart';

import '../platform/web_bridge.dart' as bridge;

/// A native HTML video, registered once per widget instance.
class WebVideo extends StatefulWidget {
  final String url;
  final bool autoplay;
  final bool muted;
  final bool loop;
  final bool controls;
  final bool cover;
  const WebVideo(this.url,
      {super.key,
      this.autoplay = false,
      this.muted = false,
      this.loop = false,
      this.controls = true,
      this.cover = false});

  @override
  State<WebVideo> createState() => _WebVideoState();
}

class _WebVideoState extends State<WebVideo> {
  late final Widget _view = bridge.htmlVideo(widget.url,
      autoplay: widget.autoplay,
      muted: widget.muted,
      loop: widget.loop,
      controls: widget.controls,
      cover: widget.cover);

  @override
  Widget build(BuildContext context) => _view;
}
