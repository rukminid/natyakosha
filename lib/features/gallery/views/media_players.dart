import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../data/models/media_item.dart';

/// Full-screen photo viewer: swipe between [photos], pinch to zoom.
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({super.key, required this.photos, required this.initial, this.captionFor});

  final List<MediaItem> photos;
  final int initial;
  final String? Function(MediaItem item)? captionFor;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.photos[_index];
    final caption = widget.captionFor?.call(current);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.photos.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.photos[i].url,
              fit: BoxFit.contain,
              placeholder: (_, __) => const CircularProgressIndicator(),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
      bottomNavigationBar: caption == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(caption, style: const TextStyle(color: Colors.white)),
              ),
            ),
    );
  }
}

/// Plays a video or an audio clip (the same player handles both).
class MediaPlayerPage extends StatefulWidget {
  const MediaPlayerPage({super.key, required this.item, this.subtitle});

  final MediaItem item;
  final String? subtitle;

  @override
  State<MediaPlayerPage> createState() => _MediaPlayerPageState();
}

class _MediaPlayerPageState extends State<MediaPlayerPage> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _error = 'This file could not be played.');
    });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.item.type == MediaType.video;
    final v = _controller.value;
    return Scaffold(
      backgroundColor: isVideo ? Colors.black : null,
      appBar: AppBar(
        backgroundColor: isVideo ? Colors.black : null,
        foregroundColor: isVideo ? Colors.white : null,
        title: Text(widget.item.caption ?? (isVideo ? 'Video' : 'Audio')),
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: isVideo ? Colors.white : null)))
          : !_ready
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: isVideo
                            ? AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(_controller))
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.music_note, size: 96, color: Theme.of(context).colorScheme.primary),
                                  if (widget.subtitle != null) ...[
                                    const SizedBox(height: 12),
                                    Text(widget.subtitle!, style: Theme.of(context).textTheme.titleMedium),
                                  ],
                                ],
                              ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slider(
                              value: v.position.inMilliseconds.clamp(0, v.duration.inMilliseconds).toDouble(),
                              max: v.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                              onChanged: (ms) => _controller.seekTo(Duration(milliseconds: ms.round())),
                            ),
                            Row(
                              children: [
                                Text(_fmt(v.position), style: TextStyle(color: isVideo ? Colors.white : null)),
                                const Spacer(),
                                IconButton.filled(
                                  iconSize: 32,
                                  onPressed: () {
                                    if (v.position >= v.duration) _controller.seekTo(Duration.zero);
                                    v.isPlaying ? _controller.pause() : _controller.play();
                                  },
                                  icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow),
                                ),
                                const Spacer(),
                                Text(_fmt(v.duration), style: TextStyle(color: isVideo ? Colors.white : null)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
