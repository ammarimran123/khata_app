import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/khata_chip.dart';
import '../../../dashboard/presentation/dashboard_providers.dart';
import '../../data/client_transaction.dart';
import '../../data/clients_repository.dart';
import '../../domain/transaction_sheet_mode.dart';
import '../clients_providers.dart';
import 'field_label.dart';

/// Opens the credit/debit/receive-payment/make-payment entry sheet for
/// [clientId]. Pass [editing] to edit an existing transaction instead of
/// creating one — the sheet then opens straight on the details step,
/// matching the design.
Future<void> showTransactionSheet(
  BuildContext context, {
  required String clientId,
  required TransactionSheetMode mode,
  required double currentBalance,
  ClientTransaction? editing,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(),
    builder: (_) => _TransactionSheet(
      clientId: clientId,
      mode: mode,
      currentBalance: currentBalance,
      editing: editing,
    ),
  );
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet({
    required this.clientId,
    required this.mode,
    required this.currentBalance,
    this.editing,
  });

  final String clientId;
  final TransactionSheetMode mode;
  final double currentBalance;
  final ClientTransaction? editing;

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  static const _methods = ['Cash', 'Bank Transfer', 'Card', 'Cheque', 'Other'];

  late int _step;
  String _amountText = '';
  bool _amountError = false;
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  late String _method;
  late DateTime _date;
  late TimeOfDay _time;
  bool _submitting = false;

  bool get _isEdit => widget.editing != null;

  /// The client's balance with the transaction being edited backed out —
  /// so the "after" preview reflects replacing it, not stacking a second
  /// effect on top of the one already counted in currentBalance.
  double get _baseBalance {
    final editing = widget.editing;
    if (editing == null) return widget.currentBalance;
    final oldEffect = editing.type == TransactionType.credit
        ? editing.amount
        : -editing.amount;
    return widget.currentBalance - oldEffect;
  }

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _step = 2;
      _amountText = editing.amount.round().toString();
      _descCtrl.text = editing.description ?? '';
      _refCtrl.text = editing.referenceNo ?? '';
      _method = editing.paymentMethod ?? _methods.first;
      _date = editing.occurredAt;
      _time = TimeOfDay(
        hour: editing.occurredAt.hour,
        minute: editing.occurredAt.minute,
      );
    } else {
      _step = 1;
      final now = DateTime.now();
      _date = now;
      _time = TimeOfDay(hour: now.hour, minute: now.minute);
      _method = _methods.first;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountText) ?? 0;

  void _pressKey(String k) {
    setState(() {
      if (k == '⌫') {
        _amountText = _amountText.isEmpty
            ? ''
            : _amountText.substring(0, _amountText.length - 1);
      } else if (k == '000') {
        if (_amountText.isNotEmpty) _amountText += '000';
      } else {
        _amountText = (_amountText + k).replaceFirst(RegExp(r'^0+(?=\d)'), '');
      }
      if (_amountText.length > 9) {
        _amountText = _amountText.substring(0, 9);
      }
      _amountError = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  String _balanceSentence(double balance) {
    if (balance > 0) return 'You will receive ${Formatters.currency(balance)}';
    if (balance < 0) return 'You will owe ${Formatters.currency(balance)}';
    return 'Account settled';
  }

  Future<void> _submit() async {
    final spec = transactionSheetSpec(widget.mode);
    setState(() => _submitting = true);
    final repo = ref.read(clientsRepositoryProvider);
    final occurredAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final desc = _descCtrl.text.trim().isEmpty
        ? spec.descriptionPlaceholder
        : _descCtrl.text.trim();
    final reference = _refCtrl.text.trim().isEmpty
        ? null
        : _refCtrl.text.trim();

    try {
      if (_isEdit) {
        await repo.updateTransaction(
          id: widget.editing!.id,
          type: spec.type,
          amount: _amount,
          occurredAt: occurredAt,
          description: desc,
          paymentMethod: _method,
          referenceNo: reference,
        );
      } else {
        await repo.createTransaction(
          clientId: widget.clientId,
          type: spec.type,
          amount: _amount,
          occurredAt: occurredAt,
          description: desc,
          paymentMethod: _method,
          referenceNo: reference,
        );
      }
      ref.invalidate(clientDetailProvider(widget.clientId));
      ref.invalidate(clientSummariesProvider);
      ref.invalidate(periodTotalsProvider);
      final after =
          _baseBalance +
          (spec.type == TransactionType.credit ? _amount : -_amount);
      if (mounted) {
        Navigator.pop(
          context,
          _isEdit
              ? 'Transaction updated · ${_balanceSentence(after)}'
              : 'Saved · ${_balanceSentence(after)}',
        );
      }
    } on ClientRepositoryException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = transactionSheetSpec(widget.mode);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.text, width: AppSpacing.ruleWidth),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spec.kicker,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                                color: AppColors.neutral600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              spec.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.text, width: 2),
                            ),
                            child: const Icon(Icons.close, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Container(
                      height: AppSpacing.ruleWidth,
                      color: AppColors.text,
                    ),
                  ),
                  if (_step == 1) _buildStep1(spec) else _buildStep2(spec),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(TransactionSheetSpec spec) {
    final amt = _amount;
    final after =
        _baseBalance + (spec.type == TransactionType.credit ? amt : -amt);
    final effectLine = amt == 0
        ? 'Balance stays at ${Formatters.currency(_baseBalance)}'
        : 'Balance after: ${_balanceSentence(after)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AMOUNT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.neutral700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Rs.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _amountText.isEmpty
                    ? '0'
                    : Formatters.groupedNumber(int.parse(_amountText)),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: spec.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            effectLine,
            style: const TextStyle(fontSize: 12, color: AppColors.neutral700),
          ),
          if (_amountError)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Amount must be greater than zero.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent700,
                ),
              ),
            ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.8,
            children: [
              for (final k in [
                '1',
                '2',
                '3',
                '4',
                '5',
                '6',
                '7',
                '8',
                '9',
                '000',
                '0',
                '⌫',
              ])
                _KeypadButton(label: k, onTap: () => _pressKey(k)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (amt <= 0) {
                  setState(() => _amountError = true);
                  return;
                }
                setState(() => _step = 2);
              },
              child: const Text('Next · details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(TransactionSheetSpec spec) {
    final amt = _amount;
    final after =
        _baseBalance + (spec.type == TransactionType.credit ? amt : -amt);
    final sign = spec.type == TransactionType.credit ? '+ ' : '− ';
    final previewLabel = after == 0
        ? 'Account settled'
        : after > 0
        ? 'You will receive'
        : 'You will owe';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('Edit amount'),
              ),
              Text(
                '$sign${Formatters.currency(amt)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: spec.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const FieldLabel('Description'),
          TextFormField(
            controller: _descCtrl,
            decoration: InputDecoration(hintText: spec.descriptionPlaceholder),
          ),
          const SizedBox(height: AppSpacing.s3),
          const FieldLabel('Payment method'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in _methods)
                KhataChip(
                  label: m,
                  selected: _method == m,
                  onTap: () => setState(() => _method = m),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: _ReadonlyField(
                  label: 'Date',
                  value: Formatters.date(_date),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReadonlyField(
                  label: 'Time',
                  value: _time.format(context),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          const FieldLabel('Reference / invoice no.'),
          TextFormField(
            controller: _refCtrl,
            decoration: const InputDecoration(hintText: 'Optional'),
          ),
          const SizedBox(height: AppSpacing.s4),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.text, width: AppSpacing.ruleWidth),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  previewLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.neutral700,
                  ),
                ),
                Text(
                  Formatters.currency(after),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEdit
                          ? 'Update transaction'
                          : 'Save · ${spec.title.replaceFirst('Add ', '')}',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              border: Border.all(color: AppColors.neutral400, width: 2),
            ),
            child: Text(value, style: const TextStyle(fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neutral100,
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral400, width: 2),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
