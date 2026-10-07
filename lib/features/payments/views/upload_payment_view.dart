import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validators/app_validators.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/payments_view_model.dart';

/// Student uploads a UPI payment screenshot for a month's fee.
///
/// Reference feature for the MVVM + Redux + Firebase pattern:
///   View (this file) → ViewModel.submit → thunk → repository
///   → StorageService (compress + upload) → Firestore → reducer → View.
class UploadPaymentView extends StatefulWidget {
  const UploadPaymentView({super.key});

  @override
  State<UploadPaymentView> createState() => _UploadPaymentViewState();
}

class _UploadPaymentViewState extends State<UploadPaymentView> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _picker = ImagePicker();
  XFile? _screenshot;
  bool _showScreenshotError = false;

  /// Current month, three before it and one ahead (advance payment).
  late final List<DateTime> _months = () {
    final now = DateTime.now();
    return [for (var i = -1; i <= 3; i++) DateTime(now.year, now.month - i)];
  }();

  String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source);
    if (file == null) return;
    setState(() {
      _screenshot = file;
      _showScreenshotError = false;
    });
  }

  void _submit(UploadPaymentViewModel vm) {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState!;
    final valid = form.saveAndValidate();
    setState(() => _showScreenshotError = _screenshot == null);
    if (!valid || _screenshot == null) return;

    final v = form.value;
    vm.submit(
      month: v['month'] as String,
      amount: double.parse((v['amount'] as String).trim()),
      screenshotPath: _screenshot!.path,
      upiTxnId: (v['upiTxnId'] as String?)?.trim(),
      note: (v['note'] as String?)?.trim(),
      onSuccess: () {
        if (!mounted) return;
        showSnack(context, 'Uploaded. Your guru will verify it soon.');
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, UploadPaymentViewModel>(
      converter: UploadPaymentViewModel.fromStore,
      distinct: true,
      onWillChange: (prev, next) {
        if (next.error != null && next.error != prev?.error) {
          showSnack(context, next.error!, error: true);
        }
      },
      builder: (context, vm) => PopScope(
        canPop: !vm.submitting,
        child: Scaffold(
          appBar: AppBar(title: const Text('Upload payment')),
          body: FormBuilder(
            key: _formKey,
            enabled: !vm.submitting,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FormBuilderDropdown<String>(
                  name: 'month',
                  initialValue: _monthKey(_months[1]),
                  decoration: AppTheme.input('Fee for month'),
                  validator: AppValidators.required<String>('Month'),
                  items: [
                    for (final m in _months)
                      DropdownMenuItem(
                        value: _monthKey(m),
                        child: Text(DateFormat('MMMM yyyy').format(m)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'amount',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: AppTheme.input('Amount paid', prefixIcon: const Icon(Icons.currency_rupee)),
                  validator: AppValidators.amount(),
                ),
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'upiTxnId',
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: AppTheme.input(
                    'UPI reference number (optional)',
                    helper: 'The 12-digit UTR / reference in GPay, PhonePe or Paytm',
                  ),
                  validator: AppValidators.optionalUpiTxnId(),
                ),
                const SizedBox(height: 8),
                FormBuilderTextField(
                  name: 'note',
                  maxLines: 2,
                  decoration: AppTheme.input('Note for your guru (optional)'),
                  validator: AppValidators.maxLength(200, 'Note'),
                ),
                const SizedBox(height: 16),
                _ScreenshotPicker(
                  file: _screenshot,
                  showError: _showScreenshotError,
                  enabled: !vm.submitting,
                  onPick: _pick,
                ),
                const SizedBox(height: 24),
                if (vm.submitting) ...[
                  LinearProgressIndicator(value: vm.progress > 0 ? vm.progress : null),
                  const SizedBox(height: 8),
                  Text(
                    vm.progress > 0 ? 'Uploading… ${(vm.progress * 100).round()}%' : 'Preparing image…',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: vm.submitting || !vm.isOnline ? null : () => _submit(vm),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(vm.isOnline ? 'Submit payment' : 'Go online to upload'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenshotPicker extends StatelessWidget {
  const _ScreenshotPicker({
    required this.file,
    required this.showError,
    required this.enabled,
    required this.onPick,
  });

  final XFile? file;
  final bool showError;
  final bool enabled;
  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    final borderColor = showError ? AppColors.danger : AppColors.gold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment screenshot', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          height: 220,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: file == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 48, color: AppColors.gold),
                      SizedBox(height: 8),
                      Text('Attach the screenshot from your UPI app'),
                    ],
                  ),
                )
              : Image.file(File(file!.path), fit: BoxFit.contain),
        ),
        if (showError)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 12),
            child: Text(
              'Please attach the payment screenshot',
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? () => onPick(ImageSource.gallery) : null,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(file == null ? 'Choose from gallery' : 'Change'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? () => onPick(ImageSource.camera) : null,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
