import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'common.dart';
import 'video_view.dart';

class MediaItem {
  final String url;
  final bool isVideo;
  final String caption;
  const MediaItem(this.url, {this.isVideo = false, this.caption = ''});
}

/// Full-screen swipeable gallery of photos and videos.
Future<void> openMediaViewer(BuildContext context, List<MediaItem> items, int start) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.noir.withValues(alpha: 0.96),
    builder: (_) => _Viewer(items: items, start: start),
  );
}

class _Viewer extends StatefulWidget {
  final List<MediaItem> items;
  final int start;
  const _Viewer({required this.items, required this.start});
  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final PageController _pc = PageController(initialPage: widget.start);
  late int _index = widget.start;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.items.length - 1);
    _pc.animateToPage(next, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (c, i) {
              final m = widget.items[i];
              return Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 64, 16, 80),
                  child: m.isVideo
                      ? AspectRatio(aspectRatio: 9 / 16, child: WebVideo(m.url, autoplay: false))
                      : InteractiveViewer(child: NetImage(m.url, fit: BoxFit.contain)),
                ),
              );
            },
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          if (widget.items.length > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  onPressed: _index > 0 ? () => _go(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  onPressed: _index < widget.items.length - 1 ? () => _go(1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          ],
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Text(
              [
                '${_index + 1} / ${widget.items.length}',
                if (item.caption.isNotEmpty) item.caption,
              ].join('  ·  '),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'DMSans', color: AppColors.noirText, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
