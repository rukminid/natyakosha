import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';

import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/announcement_thunks.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/form_fields.dart';
import '../view_models/announcements_view_model.dart';

/// Post ([announcementId] null) or edit an announcement. Staff only.
class AnnouncementFormView extends StatefulWidget {
  const AnnouncementFormView({super.key, this.announcementId});

  final String? announcementId;

  @override
  State<AnnouncementFormView> createState() => _AnnouncementFormViewState();
}

class _AnnouncementFormViewState extends State<AnnouncementFormView> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _pinned = false;
  bool _initialised = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save(AnnouncementsViewModel vm) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.announcementId == null ? null : vm.byId(widget.announcementId!);
    setState(() => _saving = true);
    final error = await vm.save(existing: existing, title: _title.text, body: _body.text, pinned: _pinned);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      showSnack(context, error, error: true);
      return;
    }
    showSnack(context, existing == null ? 'Announcement posted' : 'Announcement updated');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AnnouncementsViewModel>(
      converter: AnnouncementsViewModel.fromStore,
      distinct: true,
      builder: (context, vm) {
        final editing = widget.announcementId != null;
        final existing = editing ? vm.byId(widget.announcementId!) : null;
        if (!vm.isStaff) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.lock_outline, title: 'Only staff can post announcements'),
          );
        }
        if (editing && existing == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.campaign_outlined, title: 'Announcement not found'),
          );
        }
        if (!_initialised) {
          _initialised = true;
          _title.text = existing?.title ?? '';
          _body.text = existing?.body ?? '';
          _pinned = existing?.pinned ?? false;
        }
        return Scaffold(
          appBar: AppBar(title: Text(editing ? 'Edit announcement' : 'New announcement')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _title,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: maxAnnouncementTitle,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _body,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 5,
                  maxLines: 12,
                  maxLength: maxAnnouncementBody,
                  decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Write the announcement' : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pin to the top'),
                  subtitle: const Text('Pinned notices stay above newer ones'),
                  value: _pinned,
                  onChanged: _saving ? null : (v) => setState(() => _pinned = v),
                ),
                const SizedBox(height: 16),
                LoadingButton(
                  label: editing ? 'Save changes' : 'Post announcement',
                  loading: _saving,
                  onPressed: () => _save(vm),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
