import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../view_models/chat_view_models.dart';

/// Staff create a group: a name and the people in it.
class NewGroupView extends StatefulWidget {
  const NewGroupView({super.key});

  @override
  State<NewGroupView> createState() => _NewGroupViewState();
}

class _NewGroupViewState extends State<NewGroupView> {
  final _name = TextEditingController();
  final _picked = <String>{};
  String? _nameError;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create(PeopleViewModel vm) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Give the group a name');
      return;
    }
    if (name.length > 60) {
      setState(() => _nameError = 'Name must be under 60 characters');
      return;
    }
    if (_picked.isEmpty) {
      showSnack(context, 'Choose at least one person', error: true);
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });
    final result = await vm.createGroup(name, _picked.toList());
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.error != null) {
      showSnack(context, result.error!, error: true);
      return;
    }
    context.pushReplacement(Routes.chatRoom(result.chatId!));
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, PeopleViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: PeopleViewModel.fromStore,
      distinct: true,
      onInit: (store) => PeopleViewModel.fromStore(store).load(),
      builder: (context, vm) {
        final all = vm.people;
        final allPicked = all.isNotEmpty && all.every((m) => _picked.contains(m.id));
        return Scaffold(
          appBar: AppBar(title: const Text('New group')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppTheme.input('Group name', prefixIcon: const Icon(Icons.groups_outlined))
                      .copyWith(errorText: _nameError),
                ),
              ),
              ListTile(
                title: Text('Members (${_picked.length})'),
                trailing: TextButton(
                  onPressed: all.isEmpty || _saving
                      ? null
                      : () => setState(() {
                            if (allPicked) {
                              _picked.clear();
                            } else {
                              _picked.addAll(all.map((m) => m.id));
                            }
                          }),
                  child: Text(allPicked ? 'Clear' : 'Select all'),
                ),
              ),
              if (vm.loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: vm.error != null && all.isEmpty
                    ? ErrorRetry(message: vm.error!, onRetry: vm.load)
                    : all.isEmpty
                        ? EmptyState(
                            icon: Icons.groups_outlined,
                            title: vm.loading ? 'Loading…' : 'Nobody to add yet',
                            message: vm.loading ? null : 'People appear here once they are approved.',
                          )
                        : ListView(
                            children: [
                              for (final m in all)
                                CheckboxListTile(
                                  value: _picked.contains(m.id),
                                  secondary: UserAvatar(name: m.name, photoUrl: m.photoUrl, radius: 20),
                                  title: Text(m.name),
                                  subtitle: Text(m.role.label),
                                  onChanged: _saving
                                      ? null
                                      : (on) => setState(() => on == true ? _picked.add(m.id) : _picked.remove(m.id)),
                                ),
                            ],
                          ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  top: false,
                  child: LoadingButton(
                    label: 'Create group',
                    loading: _saving,
                    onPressed: vm.isOnline ? () => _create(vm) : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
