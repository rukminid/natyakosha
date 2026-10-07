import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/payment.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/payments_view_model.dart';

final _rupees = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

Color statusColor(PaymentStatus s) => switch (s) {
      PaymentStatus.pending => AppColors.warning,
      PaymentStatus.submitted => AppColors.info,
      PaymentStatus.verified => AppColors.success,
      PaymentStatus.rejected => AppColors.danger,
    };

class PaymentsView extends StatefulWidget {
  const PaymentsView({super.key});

  @override
  State<PaymentsView> createState() => _PaymentsViewState();
}

class _PaymentsViewState extends State<PaymentsView> {
  /// Local UI state (the selected filter) stays in the widget, not Redux.
  PaymentStatus? _filter;

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, PaymentsViewModel>(
      converter: PaymentsViewModel.fromStore,
      distinct: true,
      onInit: (store) => PaymentsViewModel.fromStore(store).refresh(),
      onWillChange: (prev, next) {
        if (next.error != null && next.error != prev?.error && prev != null) {
          showSnack(context, next.error!, error: true);
        }
      },
      builder: (context, vm) {
        final items = _filter == null ? vm.items : vm.items.where((p) => p.status == _filter).toList();
        return Scaffold(
          appBar: AppBar(title: Text(vm.isStaff ? 'Fee payments' : 'My fees')),
          floatingActionButton: vm.isStaff
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => context.push(Routes.uploadPayment),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload payment'),
                ),
          body: Column(
            children: [
              _FilterBar(
                selected: _filter,
                awaitingCount: vm.awaitingCount,
                onSelected: (f) => setState(() => _filter = f),
              ),
              if (vm.loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: vm.refresh,
                  child: _buildList(context, vm, items),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context, PaymentsViewModel vm, List<Payment> items) {
    if (vm.error != null && vm.items.isEmpty) {
      return ListView(children: [ErrorRetry(message: vm.error!, onRetry: vm.refresh)]);
    }
    if (items.isEmpty && !vm.loading) {
      return ListView(
        children: [
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: vm.isStaff ? 'Nothing here yet' : 'No payments uploaded yet',
            message: vm.isStaff
                ? 'Payment screenshots from students will appear here.'
                : 'After paying your guru by UPI, tap "Upload payment" and attach the screenshot.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _PaymentCard(
        payment: items[i],
        isStaff: vm.isStaff,
        busy: vm.reviewingIds.contains(items[i].id),
        canReview: vm.isOnline,
        onReview: (approve) => vm.review(items[i].id, approve: approve),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.awaitingCount, required this.onSelected});

  final PaymentStatus? selected;
  final int awaitingCount;
  final ValueChanged<PaymentStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <(PaymentStatus?, String)>[
      (null, 'All'),
      (PaymentStatus.submitted, 'To verify ($awaitingCount)'),
      (PaymentStatus.verified, 'Paid'),
      (PaymentStatus.rejected, 'Rejected'),
    ];
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final (status, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected == status,
                onSelected: (_) => onSelected(status),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.isStaff,
    required this.busy,
    required this.canReview,
    required this.onReview,
  });

  final Payment payment;
  final bool isStaff;
  final bool busy;
  final bool canReview;
  final ValueChanged<bool> onReview;

  String get _monthLabel {
    final d = DateTime.tryParse('${payment.month}-01');
    return d == null ? payment.month : DateFormat('MMMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (payment.screenshotUrl != null)
              GestureDetector(
                onTap: () => _openScreenshot(context, payment.screenshotUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: payment.screenshotUrl!,
                    width: 64,
                    height: 88,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 64, height: 88, color: Colors.black12),
                    errorWidget: (_, __, ___) => const SizedBox(
                      width: 64,
                      height: 88,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isStaff ? payment.studentName : _monthLabel,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      StatusChip(label: payment.status.label, color: statusColor(payment.status)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_rupees.format(payment.amount)}${isStaff ? ' · $_monthLabel' : ''}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (payment.upiTxnId != null)
                    Text('UPI ref: ${payment.upiTxnId}', style: theme.textTheme.bodySmall),
                  if (payment.note != null)
                    Text(payment.note!, style: theme.textTheme.bodySmall),
                  if (isStaff && payment.status == PaymentStatus.submitted) ...[
                    const SizedBox(height: 8),
                    busy
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Row(
                            children: [
                              OutlinedButton(
                                onPressed: canReview ? () => onReview(false) : null,
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: canReview ? () => onReview(true) : null,
                                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                                child: const Text('Mark paid'),
                              ),
                            ],
                          ),
                  ],
                  if (!isStaff && payment.status == PaymentStatus.rejected)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Your guru could not match this payment. Please upload it again.',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
}
