import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/gallery_view_model.dart';

/// Staff add photos, a video or audio clips to an event. Photos are
/// compressed on the phone before they go up.
class MediaUploadSheet extends StatefulWidget {
  const MediaUploadSheet({super.key, required this.vm});

  final GalleryViewModel vm;

  @override
  State<MediaUploadSheet> createState() => _MediaUploadSheetState();
}

class _MediaUploadSheetState extends State<MediaUploadSheet> {
  final _caption = TextEditingController();
  MediaType _type = MediaType.photo;
  String? _eventId;
  String? _itemId;
  List<String> _paths = [];
  bool _busy = false;
  int _done = 0;
  double _current = 0;

  @override
  void initState() {
    super.initState();
    // The most recent event that has already started, else the soonest.
    final events = widget.vm.events;
    if (events.isNotEmpty) {
      final now = DateTime.now();
      _eventId = (events.where((e) => !e.date.isAfter(now)).firstOrNull ?? events.last).id;
      widget.vm.loadSongs(_eventId!);
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final List<String> picked;
    switch (_type) {
      case MediaType.photo:
        picked = [for (final f in await ImagePicker().pickMultiImage(limit: 20)) f.path];
      case MediaType.video:
        final f = await ImagePicker().pickVideo(source: ImageSource.gallery);
        picked = f == null ? [] : [f.path];
      case MediaType.audio:
        final r = await FilePicker.pickFiles(type: FileType.audio, allowMultiple: true);
        picked = [for (final f in r?.files ?? const []) if (f.path != null) f.path!];
    }
    if (picked.isNotEmpty) setState(() => _paths = picked);
  }

  Future<void> _upload() async {
    if (_eventId == null) return;
    if (_paths.isEmpty) {
      showSnack(context, 'Choose at least one file', error: true);
      return;
    }
    setState(() {
      _busy = true;
      _done = 0;
      _current = 0;
    });
    final error = await widget.vm.upload(
      eventId: _eventId!,
      type: _type,
      paths: _paths,
      itemId: _itemId,
      caption: _caption.text,
      onProgress: (done, total, current) {
        if (!mounted) return;
        setState(() {
          _done = done;
          _current = current;
        });
      },
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _busy = false);
      showSnack(context, error, error: true);
      return;
    }
    Navigator.pop(context, _paths.length);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final songs = _eventId == null ? const [] : (vm.songs[_eventId] ?? const []);
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add to gallery', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (vm.events.isEmpty)
                const Text('Create an event first, then add its photos and videos here.')
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _eventId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Event'),
                  items: [
                    for (final e in vm.events) DropdownMenuItem(value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) {
                          setState(() {
                            _eventId = v;
                            _itemId = null;
                          });
                          if (v != null) vm.loadSongs(v);
                        },
                ),
                const SizedBox(height: 12),
                SegmentedButton<MediaType>(
                  segments: const [
                    ButtonSegment(value: MediaType.photo, icon: Icon(Icons.photo_outlined), label: Text('Photos')),
                    ButtonSegment(value: MediaType.video, icon: Icon(Icons.videocam_outlined), label: Text('Video')),
                    ButtonSegment(value: MediaType.audio, icon: Icon(Icons.audiotrack_outlined), label: Text('Audio')),
                  ],
                  selected: {_type},
                  onSelectionChanged: _busy
                      ? null
                      : (s) => setState(() {
                            _type = s.first;
                            _paths = [];
                          }),
                ),
                const SizedBox(height: 12),
                if (songs.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    initialValue: _itemId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Song (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Whole event')),
                      for (final s in songs) DropdownMenuItem<String?>(value: s.id, child: Text('${s.order}. ${s.songName}', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _itemId = v),
                  ),
                TextField(
                  controller: _caption,
                  enabled: !_busy,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Caption (optional)'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_paths.isEmpty
                      ? 'Choose ${_type == MediaType.photo ? 'photos' : _type == MediaType.video ? 'a video' : 'audio files'}'
                      : '${_paths.length} selected · change'),
                ),
                if (_type != MediaType.photo)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Files up to 200 MB.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                const SizedBox(height: 12),
                if (_busy) ...[
                  LinearProgressIndicator(value: _paths.isEmpty ? null : (_done + _current) / _paths.length),
                  const SizedBox(height: 4),
                  Text('Uploading ${(_done + 1).clamp(1, _paths.length)} of ${_paths.length}…',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                    onPressed: _busy ? null : _upload,
                    child: Text(_busy ? 'Uploading…' : 'Upload'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
