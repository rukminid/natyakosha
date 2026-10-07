import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/event_fee.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/event_fee_view_models.dart';

final _rupees = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _day = DateFormat('d MMM yyyy');

Color feeStatusColor(EventFeeStatus s) => switch (s) {
      EventFeeStatus.pending => AppColors.warning,
      EventFeeStatus.submitted => AppColors.info,
      EventFeeStatus.paid => AppColors.success,
      EventFeeStatus.waived => Colors.grey,
    };

class EventFeeStatusChip extends StatelessWidget {
  const EventFeeStatusChip({super.key, required this.status});
  final EventFeeStatus status;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: status.label, color: feeStatusColor(status));
}

void _openScreenshot(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url)),
    ),
  );
}

/// One event's fees. Staff: totals, a row per dancer with Paid / Waived /
/// amount actions, and "Remind pending". Student or parent: their own fee,
/// with a screenshot upload while it is pending.
class EventFeeDetailView extends StatelessWidget {
  const EventFeeDetailView({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, EventFeeDetailViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: (store) => EventFeeDetailViewModel.fromStore(store, eventId),
      distinct: true,
      onInit: (store) => EventFeeDetailViewModel.fromStore(store, eventId).refresh(),
      builder: (context, vm) {
        final event = vm.event;
        if (event == null || event.fee == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.event_busy, title: 'No fee for this event'),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(event.title, overflow: TextOverflow.ellipsis)),
          body: RefreshIndicator(
            onRefresh: vm.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _FeeTerms(vm: vm),
                const SizedBox(height: 12),
                if (vm.fees.isEmpty && vm.loading)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                else if (vm.fees.isEmpty && vm.error != null)
                  ErrorRetry(message: vm.error!, onRetry: vm.refresh)
                else if (vm.fees.isEmpty)
                  EmptyState(
                    icon: Icons.request_quote_outlined,
                    title: vm.isStaff ? 'No dancers yet' : 'No fee for you',
                    message: vm.isStaff
                        ? 'Add dancers to the event and their fees appear here.'
                        : 'You are not on this event.',
                  )
                else if (vm.isStaff) ...[
                  _Summary(vm: vm),
                  const SizedBox(height: 12),
                  for (final f in vm.fees) _StaffFeeTile(vm: vm, fee: f),
                ] else
                  for (final f in vm.fees) _MyFeeCard(vm: vm, fee: f),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FeeTerms extends StatelessWidget {
  const _FeeTerms({required this.vm});
  final EventFeeDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final fee = vm.event!.fee!;
    return Card(
      color: AppColors.gold.withValues(alpha: 0.15),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.currency_rupee),
            title: Text('${_rupees.format(fee.amount)} per dancer'),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.event_available_outlined),
            title: Text('Pay by ${_day.format(fee.dueDate)}'),
          ),
          if (fee.upiId != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text('UPI: ${fee.upiId}'),
              trailing: IconButton(
                tooltip: 'Copy UPI id',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: fee.upiId!));
                  showSnack(context, 'UPI id copied');
                },
              ),
            ),
          if (fee.description != null)
            ListTile(dense: true, leading: const Icon(Icons.sell_outlined), title: Text(fee.description!)),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.vm});
  final EventFeeDetailViewModel vm;

  Future<void> _remind(BuildContext context) async {
    final error = await vm.remind();
    if (!context.mounted) return;
    showSnack(context, error ?? 'Reminder sent to everyone pending', error: error != null);
  }

  @override
  Widget build(BuildContext context) {
    final s = vm.summary;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Figure('Expected', _rupees.format(s.expected)),
                _Figure('Collected', _rupees.format(s.collected), color: AppColors.success),
                _Figure('Outstanding', _rupees.format(s.outstanding), color: AppColors.warning),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: s.progress, minHeight: 8, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 8),
            Text(
              '${s.settledCount} of ${s.total} settled · ${s.submittedCount} to check · ${s.pendingCount} pending',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: s.pendingCount == 0 ? null : () => _remind(context),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Remind pending'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _StaffFeeTile extends StatelessWidget {
  const _StaffFeeTile({required this.vm, required this.fee});
  final EventFeeDetailViewModel vm;
  final EventFee fee;

  Future<void> _run(BuildContext context, Future<String?> Function() action) async {
    final error = await action();
    if (context.mounted && error != null) showSnack(context, error, error: true);
  }

  Future<void> _editAmount(BuildContext context) async {
    final controller = TextEditingController(text: fee.amount.toStringAsFixed(fee.amount % 1 == 0 ? 0 : 2));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Amount for ${fee.studentName}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(prefixIcon: Icon(Icons.currency_rupee)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || !context.mounted) return;
    await _run(context, () => vm.update(fee.studentId, amount: amount));
  }

  Future<void> _actions(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(fee.studentName),
              subtitle: Text('${_rupees.format(fee.amount)} · ${fee.status.label}'),
            ),
            if (fee.screenshotUrl != null)
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('View payment screenshot'),
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
            if (fee.status != EventFeeStatus.paid)
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
                title: const Text('Mark paid'),
                onTap: () => Navigator.pop(ctx, 'paid'),
              ),
            if (fee.status != EventFeeStatus.waived)
              ListTile(
                leading: const Icon(Icons.volunteer_activism_outlined),
                title: const Text('Waive fee'),
                onTap: () => Navigator.pop(ctx, 'waived'),
              ),
            if (fee.status != EventFeeStatus.pending)
              ListTile(
                leading: const Icon(Icons.undo),
                title: Text(fee.status == EventFeeStatus.submitted ? 'Reject, ask to pay again' : 'Back to pending'),
                onTap: () => Navigator.pop(ctx, 'pending'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Change amount'),
              onTap: () => Navigator.pop(ctx, 'amount'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'view':
        _openScreenshot(context, fee.screenshotUrl!);
      case 'paid':
        await _run(context, () => vm.update(fee.studentId, status: EventFeeStatus.paid));
      case 'waived':
        await _run(context, () => vm.update(fee.studentId, status: EventFeeStatus.waived));
      case 'pending':
        await _run(context, () => vm.update(fee.studentId, status: EventFeeStatus.pending));
      case 'amount':
        await _editAmount(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: fee.status == EventFeeStatus.submitted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.info),
            )
          : null,
      child: ListTile(
        onTap: () => _actions(context),
        title: Text(fee.studentName),
        subtitle: Text([
          _rupees.format(fee.amount),
          if (fee.upiTxnId != null) 'Ref ${fee.upiTxnId}',
          if (fee.note != null) fee.note!,
        ].join(' · ')),
        trailing: EventFeeStatusChip(status: fee.status),
      ),
    );
  }
}

class _MyFeeCard extends StatelessWidget {
  const _MyFeeCard({required this.vm, required this.fee});
  final EventFeeDetailViewModel vm;
  final EventFee fee;

  Future<void> _upload(BuildContext context) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FeeProofSheet(vm: vm, fee: fee),
    );
    if (done == true && context.mounted) showSnack(context, 'Uploaded. Your guru will check it soon.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(fee.studentName, style: theme.textTheme.titleMedium)),
                EventFeeStatusChip(status: fee.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(_rupees.format(fee.amount),
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            switch (fee.status) {
              EventFeeStatus.pending => const Text('Pay by UPI, then upload the screenshot.'),
              EventFeeStatus.submitted => const Text('Uploaded. Waiting for your guru to check it.'),
              EventFeeStatus.paid => const Text('Paid. Thank you!'),
              EventFeeStatus.waived => const Text('No fee for this event.'),
            },
            if (fee.screenshotUrl != null)
              TextButton.icon(
                onPressed: () => _openScreenshot(context, fee.screenshotUrl!),
                icon: const Icon(Icons.image_outlined),
                label: const Text('View my screenshot'),
              ),
            if (fee.status == EventFeeStatus.pending)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _upload(context),
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Upload payment screenshot'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pick the UPI screenshot, add the reference number, and upload. Pops `true`.
class FeeProofSheet extends StatefulWidget {
  const FeeProofSheet({super.key, required this.vm, required this.fee});

  final EventFeeDetailViewModel vm;
  final EventFee fee;

  @override
  State<FeeProofSheet> createState() => _FeeProofSheetState();
}

class _FeeProofSheetState extends State<FeeProofSheet> {
  final _txn = TextEditingController();
  final _note = TextEditingController();
  XFile? _file;
  bool _missing = false;
  bool _busy = false;
  double _progress = 0;

  @override
  void dispose() {
    _txn.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return;
    setState(() {
      _file = file;
      _missing = false;
    });
  }

  Future<void> _submit() async {
    final txn = _txn.text.trim();
    if (txn.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(txn)) {
      showSnack(context, 'A UPI reference has 12 digits', error: true);
      return;
    }
    if (_file == null) {
      setState(() => _missing = true);
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
    });
    final error = await widget.vm.submitProof(
      widget.fee.studentId,
      screenshotPath: _file!.path,
      upiTxnId: txn,
      note: _note.text.trim(),
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _busy = false);
      showSnack(context, error, error: true);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment for ${widget.fee.studentName}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_file != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_file!.path), height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_file == null ? 'Choose screenshot' : 'Change'),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                ],
              ),
              if (_missing)
                const Text('Please attach the screenshot', style: TextStyle(color: AppColors.danger)),
              const SizedBox(height: 8),
              TextField(
                controller: _txn,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                maxLength: 12,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'UPI reference (optional)'),
              ),
              TextField(
                controller: _note,
                enabled: !_busy,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 8),
              if (_busy) LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Uploading…' : 'Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
