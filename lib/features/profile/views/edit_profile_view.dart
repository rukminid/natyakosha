import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validators/app_validators.dart';
import '../../../data/models/app_user.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../view_models/profile_view_model.dart';

/// Edit name, date of birth, gender and photo. Mobile, role and institute
/// are fixed: the mobile number is the login id.
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormBuilderState>();
  String? _pickedPhoto;
  bool _saving = false;

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null && mounted) setState(() => _pickedPhoto = file.path);
  }

  Future<void> _save(ProfileViewModel vm) async {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState!;
    if (!form.saveAndValidate()) return;
    final v = form.value;

    setState(() => _saving = true);
    final error = await vm.updateProfile(
      name: v['name'] as String,
      dob: v['dob'] as DateTime?,
      gender: v['gender'] as Gender?,
      localPhotoPath: _pickedPhoto,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      showSnack(context, error, error: true);
      return;
    }
    showSnack(context, 'Profile updated');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return StoreConnector<AppState, ProfileViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: ProfileViewModel.fromStore,
      distinct: true,
      builder: (context, vm) {
        final u = vm.user;
        return Scaffold(
          appBar: AppBar(title: const Text('Edit profile')),
          body: FormBuilder(
            key: _formKey,
            enabled: !_saving,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Center(
                  child: Stack(
                    children: [
                      UserAvatar(name: u.name, photoUrl: u.photoUrl, localPath: _pickedPhoto, radius: 52),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: AppColors.gold,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Change photo',
                            icon: const Icon(Icons.photo_camera_outlined, size: 20),
                            color: AppColors.ink,
                            onPressed: _saving ? null : _pickPhoto,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FormBuilderTextField(
                  name: 'name',
                  initialValue: u.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: AppTheme.input('Full name', prefixIcon: const Icon(Icons.person_outline)),
                  validator: AppValidators.name(),
                ),
                const SizedBox(height: 16),
                FormBuilderDateTimePicker(
                  name: 'dob',
                  initialValue: u.dob,
                  inputType: InputType.date,
                  format: DateFormat('d MMM yyyy'),
                  firstDate: DateTime(today.year - 100),
                  lastDate: today,
                  initialEntryMode: DatePickerEntryMode.calendarOnly,
                  decoration: AppTheme.input('Date of birth', prefixIcon: const Icon(Icons.cake_outlined)),
                  validator: AppValidators.dob(),
                ),
                const SizedBox(height: 16),
                FormBuilderDropdown<Gender>(
                  name: 'gender',
                  initialValue: u.gender,
                  decoration: AppTheme.input('Gender', prefixIcon: const Icon(Icons.wc_outlined)),
                  validator: AppValidators.required<Gender>('Gender'),
                  items: [
                    for (final g in Gender.values) DropdownMenuItem(value: g, child: Text(g.label)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  enabled: false,
                  initialValue: u.phone ?? '',
                  decoration: AppTheme.input(
                    'Mobile number',
                    prefixIcon: const Icon(Icons.phone_iphone),
                    helper: 'This is your login id and cannot be changed here.',
                  ),
                ),
                const SizedBox(height: 24),
                if (!vm.isOnline)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('You are offline. Connect to save changes.'),
                  ),
                LoadingButton(
                  label: 'Save changes',
                  loading: _saving,
                  onPressed: vm.isOnline ? () => _save(vm) : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
