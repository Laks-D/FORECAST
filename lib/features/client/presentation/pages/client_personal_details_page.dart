import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/profile/user_profile_cubit.dart';
import '../../../../core/utils/date_utils.dart';

import 'package:snow/design_system/theme/app_chrome_theme.dart';
import '../../domain/entities/client.dart';
import '../bloc/client_bloc.dart';
import '../bloc/client_event.dart';

/// Common country-code suggestions for the autocomplete (without +, prefix shown in field).
const _commonCodes = <String>[
  '91', // India
  '1', // US / Canada
  '44', // UK
  '971', // UAE
  '61', // Australia
  '65', // Singapore
  '966', // Saudi Arabia
  '974', // Qatar
  '965', // Kuwait
  '92', // Pakistan
  '880', // Bangladesh
  '977', // Nepal
  '94', // Sri Lanka
  '86', // China
  '81', // Japan
  '82', // South Korea
  '49', // Germany
  '33', // France
  '39', // Italy
  '34', // Spain
  '55', // Brazil
  '52', // Mexico
  '27', // South Africa
  '234', // Nigeria
  '254', // Kenya
  '60', // Malaysia
  '63', // Philippines
  '66', // Thailand
  '62', // Indonesia
  '7', // Russia
];

class ClientPersonalDetailsPage extends StatefulWidget {
  final Client entity;

  /// When false, the status field is hidden and status updates are not emitted.
  final bool allowStatusEdit;

  /// When false, the email field is read-only (still displayed).
  /// Useful for client self-edit while keeping email-based linking stable.
  final bool allowEmailEdit;

  const ClientPersonalDetailsPage({
    super.key,
    required this.entity,
    this.allowStatusEdit = true,
    this.allowEmailEdit = true,
  });

  @override
  State<ClientPersonalDetailsPage> createState() =>
      _ClientPersonalDetailsPageState();
}

class _ClientPersonalDetailsPageState extends State<ClientPersonalDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _countryCodeController;

  late String _status;
  String? _gender;
  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entity.name);
    _middleNameController =
        TextEditingController(text: widget.entity.middleName ?? '');
    _phoneController =
        TextEditingController(text: widget.entity.primaryContact);
    _emailController = TextEditingController(text: widget.entity.email ?? '');
    _addressController =
        TextEditingController(text: widget.entity.address ?? '');
    _countryCodeController = TextEditingController(
        text: (widget.entity.countryCode ?? '+91').replaceAll('+', ''));
    _status = widget.entity.status;
    if (_status.trim().toLowerCase() == 'upcoming') {
      _status = 'Pending';
    }
    _gender = widget.entity.gender;
    _dateOfBirth = widget.entity.dateOfBirth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _middleNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _countryCodeController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return AppDateUtils.displayDate(dt);
  }

  String _money(double amount, String currency) =>
      '${currency}${amount.toStringAsFixed(1)}';

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  void _save() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final bloc = context.read<ClientBloc>();

    final nameChanged = name != widget.entity.name;
    final phoneChanged = phone != widget.entity.primaryContact;
    final statusChanged = _status.trim().toLowerCase() !=
        widget.entity.status.trim().toLowerCase();

    final middleName = _middleNameController.text.trim();
    final email = _emailController.text.trim();
    final address = _addressController.text.trim();

    final countryCode = _countryCodeController.text.trim();

    final detailsChanged = nameChanged ||
        phoneChanged ||
        middleName != (widget.entity.middleName ?? '') ||
        countryCode !=
            (widget.entity.countryCode ?? '+91').replaceAll('+', '') ||
        email != (widget.entity.email ?? '') ||
        _gender != widget.entity.gender ||
        _dateOfBirth != widget.entity.dateOfBirth ||
        address != (widget.entity.address ?? '');

    if (detailsChanged) {
      bloc.add(
        UpdateClientDetails(
          entityId: widget.entity.id,
          name: name,
          primaryContact: phone,
          middleName: middleName.isEmpty ? null : middleName,
          countryCode: () {
            var c = countryCode.replaceAll('+', '');
            if (c.isEmpty) return '+91';
            return '+$c';
          }(),
          email: widget.allowEmailEdit ? email : widget.entity.email,
          gender: _gender,
          dateOfBirth: _dateOfBirth,
          address: address.isEmpty ? null : address,
        ),
      );
    }

    if (widget.allowStatusEdit && statusChanged) {
      bloc.add(UpdateClientStatus(entityId: widget.entity.id, status: _status));
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final defaultCurrency =
        context.select((UserProfileCubit c) => c.state.currency);
    final currency = widget.entity.currency ?? defaultCurrency;

    Widget row(String label, Widget value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: chrome.mutedColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
                child: Align(alignment: Alignment.centerRight, child: value)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal details'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // ── Name ──
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Middle name ──
                  TextFormField(
                    controller: _middleNameController,
                    decoration: const InputDecoration(
                      labelText: 'Middle name (optional)',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  // ── Gender ──
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender (optional)',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                  const SizedBox(height: 12),

                  // ── Phone with country code ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Autocomplete<String>(
                          initialValue: _countryCodeController.value,
                          optionsBuilder: (textEditingValue) {
                            final input = textEditingValue.text.trim();
                            if (input.isEmpty) return _commonCodes;
                            return _commonCodes.where((c) => c.contains(input));
                          },
                          fieldViewBuilder: (context, controller, focusNode,
                              onFieldSubmitted) {
                            controller.addListener(() {
                              _countryCodeController.text = controller.text;
                            });
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Code',
                                prefixText: '+',
                              ),
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontSize: 14),
                            );
                          },
                          onSelected: (code) {
                            _countryCodeController.text = code;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone *',
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'Phone is required';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Email ──
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: widget.allowEmailEdit,
                    validator: (v) {
                      final val = (v ?? '').trim();
                      if (val.isEmpty) return 'Required';
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  // ── Date of birth ──
                  GestureDetector(
                    onTap: _pickDateOfBirth,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Date of birth (optional)',
                          suffixIcon:
                              const Icon(Icons.calendar_today, size: 20),
                        ),
                        controller: TextEditingController(
                          text: _dateOfBirth != null
                              ? AppDateUtils.displayDate(_dateOfBirth!)
                              : '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Address ──
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                    ),
                    maxLines: 2,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  if (widget.allowStatusEdit) ...[
                    // ── Status ──
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'Active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'Inactive', child: Text('Inactive')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _status = v);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: chrome.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: chrome.mutedColor.withOpacity(0.18)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  children: [
                    row(
                      'Last Activity',
                      Text(
                        _formatDate(widget.entity.lastActivityAt),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: chrome.textColor),
                      ),
                    ),
                    row(
                      'Total Payments',
                      Text(
                        _money(widget.entity.outstandingAmount, currency),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: chrome.textColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
