import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/client.dart';
import '../data/clients_repository.dart';
import 'clients_providers.dart';
import 'widgets/field_label.dart';

enum _OpeningType { receivable, payable, zero }

/// Add Client when [clientId] is null, Edit Client otherwise — one form
/// serves both, matching how the design treats them as the same screen.
class AddEditClientScreen extends ConsumerStatefulWidget {
  const AddEditClientScreen({super.key, this.clientId});

  final String? clientId;

  bool get isEdit => clientId != null;

  @override
  ConsumerState<AddEditClientScreen> createState() =>
      _AddEditClientScreenState();
}

class _AddEditClientScreenState extends ConsumerState<AddEditClientScreen> {
  static final _phoneRegex = RegExp(r'^0\d{2,4}-?\d{6,8}$');

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _businessCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _openingCtrl = TextEditingController();

  _OpeningType _openingType = _OpeningType.receivable;
  bool _submitting = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _businessCtrl.dispose();
    _notesCtrl.dispose();
    _openingCtrl.dispose();
    super.dispose();
  }

  void _prefill(Client client) {
    if (_prefilled) return;
    _prefilled = true;
    _nameCtrl.text = client.name;
    _phoneCtrl.text = client.phone;
    _businessCtrl.text = client.businessName ?? '';
    _notesCtrl.text = client.notes ?? '';
    final opening = client.openingBalance;
    _openingType = opening > 0
        ? _OpeningType.receivable
        : opening < 0
        ? _OpeningType.payable
        : _OpeningType.zero;
    _openingCtrl.text = opening == 0 ? '' : opening.abs().toStringAsFixed(0);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final repo = ref.read(clientsRepositoryProvider);
    final openingRaw =
        double.tryParse(_openingCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0;
    final signedOpening = switch (_openingType) {
      _OpeningType.receivable => openingRaw,
      _OpeningType.payable => -openingRaw,
      _OpeningType.zero => 0.0,
    };
    final businessName = _businessCtrl.text.trim().isEmpty
        ? null
        : _businessCtrl.text.trim();
    final notes = _notesCtrl.text.trim().isEmpty
        ? null
        : _notesCtrl.text.trim();

    try {
      if (widget.isEdit) {
        await repo.updateClient(
          id: widget.clientId!,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          businessName: businessName,
          notes: notes,
          openingBalance: signedOpening,
        );
        ref.invalidate(clientDetailProvider(widget.clientId!));
        ref.invalidate(singleClientProvider(widget.clientId!));
      } else {
        await repo.createClient(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          businessName: businessName,
          notes: notes,
          openingBalance: signedOpening,
        );
      }
      await ref.read(clientSummariesProvider.notifier).refresh();
      if (mounted) context.pop();
    } on ClientRepositoryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEdit) {
      final clientAsync = ref.watch(singleClientProvider(widget.clientId!));
      return clientAsync.when(
        data: (client) {
          _prefill(client);
          return _buildForm(title: 'Edit Client', saveLabel: 'Update Client');
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Scaffold(body: Center(child: Text('Could not load client.\n$e'))),
      );
    }
    return _buildForm(title: 'Add Client', saveLabel: 'Save Client');
  }

  Widget _buildForm({required String title, required String saveLabel}) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => context.pop(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'CANCEL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.s4),
                Container(height: AppSpacing.ruleWidth, color: AppColors.text),
                const SizedBox(height: AppSpacing.s4),
                const FieldLabel('Full name · required'),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Client name cannot be empty.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.s3),
                const FieldLabel('Phone number · required'),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || !_phoneRegex.hasMatch(v.trim())) {
                      return 'Enter a valid phone number, e.g. 0300-1234567.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s3),
                const FieldLabel('Business name'),
                TextFormField(
                  controller: _businessCtrl,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.s3),
                const FieldLabel('Address, email, notes'),
                TextFormField(controller: _notesCtrl, maxLines: 2),
                const SizedBox(height: AppSpacing.s3),
                const FieldLabel('Opening balance'),
                TextFormField(
                  controller: _openingCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.text, width: 2),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < _OpeningType.values.length; i++)
                        Expanded(
                          child: _OpeningTypeSegment(
                            label: switch (_OpeningType.values[i]) {
                              _OpeningType.receivable => 'RECEIVABLE',
                              _OpeningType.payable => 'PAYABLE',
                              _OpeningType.zero => 'ZERO BALANCE',
                            },
                            selected: _openingType == _OpeningType.values[i],
                            showDivider: i < _OpeningType.values.length - 1,
                            onTap: () => setState(
                              () => _openingType = _OpeningType.values[i],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
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
                        : Text(saveLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpeningTypeSegment extends StatelessWidget {
  const _OpeningTypeSegment({
    required this.label,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(right: BorderSide(color: AppColors.divider))
            : null,
        color: selected ? AppColors.text : Colors.transparent,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: selected ? Colors.white : AppColors.neutral800,
            ),
          ),
        ),
      ),
    );
  }
}
