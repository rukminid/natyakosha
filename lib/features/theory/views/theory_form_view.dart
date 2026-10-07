import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/theory_note.dart';
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/theory_thunks.dart' show maxTheoryImages;
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/form_fields.dart';
import '../view_models/theory_view_model.dart';

/// Add ([noteId] null) or edit a theory note. Staff only.
class TheoryFormView extends StatefulWidget {
  const TheoryFormView({super.key, this.noteId});

  final String? noteId;

  @override
  State<TheoryFormView> createState() => _TheoryFormViewState();
}

class _TheoryFormViewState extends State<TheoryFormView> {
  final _formKey = GlobalKey<FormState>();
  final _topic = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _level;
  List<String> _keptUrls = [];
  final List<String> _removedUrls = [];
  final List<String> _newPaths = [];
  bool _initialised = false;
  bool _saving = false;
  double _progress = 0;

  @override
  void dispose() {
    _topic.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  int get _imageCount => _keptUrls.length + _newPaths.length;

  Future<void> _addImages() async {
    final room = maxTheoryImages - _imageCount;
    if (room <= 0) {
      showSnack(context, 'A note can have up to $maxTheoryImages pictures', error: true);
      return;
    }
    final picked = await ImagePicker().pickMultiImage(limit: room);
    if (picked.isEmpty) return;
    setState(() => _newPaths.addAll(picked.take(room).map((f) => f.path)));
  }

  Future<void> _save(TheoryViewModel vm, TheoryNote? existing) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final note = TheoryNote(
      id: existing?.id ?? '',
      topic: _topic.text,
      title: _title.text,
      body: _body.text,
      level: _level,
      imageUrls: existing?.imageUrls ?? const [],
    );
    setState(() {
      _saving = true;
      _progress = 0;
    });
    final error = await vm.save(
      note,
      newImagePaths: _newPaths,
      removedUrls: _removedUrls,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      showSnack(context, error, error: true);
      return;
    }
    showSnack(context, existing == null ? 'Note added' : 'Note updated');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, TheoryViewModel>(
      converter: TheoryViewModel.fromStore,
      distinct: true,
      builder: (context, vm) {
        final editing = widget.noteId != null;
        final existing = editing ? vm.byId(widget.noteId!) : null;
        if (!vm.isStaff) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.lock_outline, title: 'Only staff can edit the library'),
          );
        }
        if (editing && existing == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.menu_book_outlined, title: 'Note not found'),
          );
        }
        if (!_initialised) {
          _initialised = true;
          _topic.text = existing?.topic ?? '';
          _title.text = existing?.title ?? '';
          _body.text = existing?.body ?? '';
          _level = existing?.level;
          _keptUrls = [...?existing?.imageUrls];
        }
        final suggestions = {...defaultTheoryTopics, ...vm.topics}.toList();
        return Scaffold(
          appBar: AppBar(title: Text(editing ? 'Edit note' : 'New note')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _topic,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Topic', hintText: 'Hastas, Adavus, Talas…'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Choose or type a topic' : null,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final t in suggestions)
                      ActionChip(
                        label: Text(t),
                        visualDensity: VisualDensity.compact,
                        onPressed: _saving ? null : () => setState(() => _topic.text = t),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _level,
                  decoration: const InputDecoration(labelText: 'Level (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Any level')),
                    for (final l in theoryLevels) DropdownMenuItem<String?>(value: l, child: Text(l)),
                  ],
                  onChanged: _saving ? null : (v) => setState(() => _level = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _body,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 6,
                  maxLines: 20,
                  decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true),
                ),
                const SizedBox(height: 16),
                Text('Pictures ($_imageCount/$maxTheoryImages)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final url in _keptUrls)
                      _Thumb(
                        image: CachedNetworkImageProvider(url),
                        onRemove: _saving
                            ? null
                            : () => setState(() {
                                  _keptUrls.remove(url);
                                  _removedUrls.add(url);
                                }),
                      ),
                    for (final path in _newPaths)
                      _Thumb(
                        image: FileImage(File(path)),
                        onRemove: _saving ? null : () => setState(() => _newPaths.remove(path)),
                      ),
                    if (_imageCount < maxTheoryImages)
                      InkWell(
                        onTap: _saving ? null : _addImages,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_photo_alternate_outlined),
                        ),
                      ),
                  ],
                ),
                if (_saving && _newPaths.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                ],
                const SizedBox(height: 24),
                LoadingButton(
                  label: editing ? 'Save changes' : 'Add note',
                  loading: _saving,
                  onPressed: () => _save(vm, existing),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, this.onRemove});

  final ImageProvider image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image(image: image, fit: BoxFit.cover)),
            Positioned(
              top: 0,
              right: 0,
              child: InkWell(
                onTap: onRemove,
                child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
              ),
            ),
          ],
        ),
      );
}
