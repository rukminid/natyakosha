import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/theory_note.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/theory_view_model.dart';

/// One theory note: text and pictures. Staff can edit or delete it.
class TheoryDetailView extends StatelessWidget {
  const TheoryDetailView({super.key, required this.noteId});

  final String noteId;

  Future<void> _confirmDelete(BuildContext context, TheoryViewModel vm, TheoryNote note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this note?'),
        content: Text('“${note.title}” and its pictures will be removed for everyone.'),
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
    if (ok != true || !context.mounted) return;
    final error = await vm.delete(note);
    if (!context.mounted) return;
    if (error != null) {
      showSnack(context, error, error: true);
      return;
    }
    showSnack(context, 'Note deleted');
    context.pop();
  }

  void _zoom(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, TheoryViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: TheoryViewModel.fromStore,
      distinct: true,
      builder: (context, vm) {
        final note = vm.byId(noteId);
        if (note == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.menu_book_outlined, title: 'Note not found'),
          );
        }
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(note.topic),
            actions: [
              if (vm.isStaff) ...[
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push(Routes.theoryEdit(note.id)),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, vm, note),
                ),
              ],
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(note.title, style: theme.textTheme.headlineSmall),
              if (note.level != null) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: StatusChip(label: note.level!, color: AppColors.info)),
              ],
              if (note.body.isNotEmpty) ...[
                const SizedBox(height: 16),
                SelectableText(note.body, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
              ],
              for (final url in note.imageUrls) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _zoom(context, url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                      errorWidget: (_, __, ___) => const SizedBox(
                        height: 120,
                        child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
