import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/media_item.dart';
import '../../../redux/selectors/selectors.dart' as sel;
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/gallery_view_model.dart';
import 'media_players.dart';
import 'media_upload_sheet.dart';

/// Photos, videos and audio, grouped by event. Staff add and delete.
class GalleryView extends StatefulWidget {
  const GalleryView({super.key});

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  MediaType? _filter;

  Future<void> _add(GalleryViewModel vm) async {
    final count = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MediaUploadSheet(vm: vm),
    );
    if (count != null && mounted) showSnack(context, count == 1 ? 'Added to the gallery' : '$count files added');
  }

  Future<void> _confirmDelete(GalleryViewModel vm, MediaItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this file?'),
        content: const Text('It will be removed from the gallery for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await vm.delete(item);
    if (mounted && error != null) showSnack(context, error, error: true);
  }

  void _open(GalleryViewModel vm, MediaItem item, List<MediaItem> photos) {
    final route = switch (item.type) {
      MediaType.photo => MaterialPageRoute<void>(
          builder: (_) => PhotoViewerPage(
            photos: photos,
            initial: photos.indexOf(item).clamp(0, photos.length - 1),
            captionFor: (m) {
              final parts = [
                if (m.caption != null) m.caption!,
                if (vm.songName(m) != null) vm.songName(m)!,
              ];
              return parts.isEmpty ? null : parts.join(' · ');
            },
          ),
        ),
      _ => MaterialPageRoute<void>(builder: (_) => MediaPlayerPage(item: item, subtitle: vm.songName(item))),
    };
    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, GalleryViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: GalleryViewModel.fromStore,
      distinct: true,
      onInit: (store) => GalleryViewModel.fromStore(store).refresh(),
      builder: (context, vm) {
        final shown = sel.filterMedia(vm.media, type: _filter);
        return Scaffold(
          appBar: AppBar(title: const Text('Gallery')),
          floatingActionButton: vm.isStaff
              ? FloatingActionButton.extended(
                  onPressed: () => _add(vm),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add'),
                )
              : null,
          body: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    for (final (label, type) in <(String, MediaType?)>[
                      ('All', null),
                      ('Photos', MediaType.photo),
                      ('Videos', MediaType.video),
                      ('Audio', MediaType.audio),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _filter == type,
                          onSelected: (_) => setState(() => _filter = type),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _body(vm, shown)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(GalleryViewModel vm, List<MediaItem> shown) {
    if (shown.isEmpty) {
      if (vm.loading) return const Center(child: CircularProgressIndicator());
      if (vm.error != null && vm.media.isEmpty) return ErrorRetry(message: vm.error!, onRetry: vm.refresh);
      return RefreshIndicator(
        onRefresh: vm.refresh,
        child: ListView(children: [
          SizedBox(
            height: 360,
            child: EmptyState(
              icon: Icons.photo_library_outlined,
              title: _filter == null ? 'No photos or videos yet' : 'Nothing here yet',
              message: vm.isStaff
                  ? 'Tap “Add” to share photos, videos and audio from an event.'
                  : 'Your guru will share event photos and videos here.',
            ),
          ),
        ]),
      );
    }

    // Group by event: events newest first, then anything whose event is gone.
    final order = [for (final e in vm.events) e.id];
    final groups = <String, List<MediaItem>>{};
    for (final m in shown) {
      groups.putIfAbsent(m.eventId, () => []).add(m);
    }
    final ids = [
      ...order.where(groups.containsKey),
      ...groups.keys.where((k) => !order.contains(k)),
    ];

    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, vm.isStaff ? 88 : 24),
        children: [
          for (final id in ids) ..._section(vm, id, groups[id]!),
        ],
      ),
    );
  }

  List<Widget> _section(GalleryViewModel vm, String eventId, List<MediaItem> items) {
    final visual = items.where((m) => m.type != MediaType.audio).toList();
    final audio = items.where((m) => m.type == MediaType.audio).toList();
    final photos = items.where((m) => m.type == MediaType.photo).toList();
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Text('${vm.eventTitle(eventId) ?? 'Other'} (${items.length})',
            style: Theme.of(context).textTheme.titleMedium),
      ),
      if (visual.isNotEmpty)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: visual.length,
          itemBuilder: (_, i) => _Tile(
            item: visual[i],
            onTap: () => _open(vm, visual[i], photos),
            onDelete: vm.isStaff ? () => _confirmDelete(vm, visual[i]) : null,
          ),
        ),
      for (final a in audio)
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.play_arrow)),
            title: Text(a.caption ?? vm.songName(a) ?? 'Audio clip'),
            subtitle: a.caption != null && vm.songName(a) != null ? Text(vm.songName(a)!) : null,
            onTap: () => _open(vm, a, photos),
            trailing: vm.isStaff
                ? IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(vm, a),
                  )
                : null,
          ),
        ),
    ];
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.onTap, this.onDelete});

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == MediaType.video;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideo)
              const ColoredBox(color: Colors.black87, child: Icon(Icons.play_circle_outline, color: Colors.white, size: 40))
            else
              CachedNetworkImage(
                imageUrl: item.url,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                placeholder: (_, __) => const ColoredBox(color: Color(0x11000000)),
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: Color(0x11000000),
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
            if (isVideo && item.caption != null)
              Positioned(
                left: 6,
                right: 6,
                bottom: 4,
                child: Text(item.caption!,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }
}
