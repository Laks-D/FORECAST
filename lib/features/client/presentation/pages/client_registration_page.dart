import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
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

class ClientRegistrationPage extends StatefulWidget {
  const ClientRegistrationPage({super.key, this.referredBy});

  final String? referredBy;

  @override
  State<ClientRegistrationPage> createState() => _ClientRegistrationPageState();
}

class _ClientRegistrationPageState extends State<ClientRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _countryCode = TextEditingController(text: '91');

  String? _gender;
  DateTime? _dateOfBirth;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _countryCode.dispose();
    super.dispose();
  }

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final first = _firstName.text.trim();
    final middle = _middleName.text.trim();
    final last = _lastName.text.trim();
    final name = '$first $last'.trim();
    final phone = _phone.text.trim();

    context.read<ClientBloc>().add(
          CreateClient(
            name: name,
            primaryContact: phone,
            referredBy: widget.referredBy,
            middleName: middle.isEmpty ? null : middle,
            countryCode: () {
              var c = _countryCode.text.trim().replaceAll('+', '');
              if (c.isEmpty) return '+91';
              return '+$c';
            }(),
            email: _email.text.trim(),
            gender: _gender,
            dateOfBirth: _dateOfBirth,
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          ),
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final onFrame = ThemeData.estimateBrightnessForColor(chrome.frameColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;

    return Scaffold(
      backgroundColor: chrome.frameColor,
      appBar: AppBar(
        backgroundColor: chrome.frameColor,
        foregroundColor: onFrame,
        elevation: 0,
        title: const Text('Client Registration'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: chrome.surfaceColor,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // ── First & Last name (required) ──
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstName,
                              decoration: const InputDecoration(
                                labelText: 'First name *',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lastName,
                              decoration: const InputDecoration(
                                labelText: 'Last name *',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Middle name (optional) ──
                      TextFormField(
                        controller: _middleName,
                        decoration: const InputDecoration(
                          labelText: 'Middle name (optional)',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),

                      // ── Gender (optional) ──
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender (optional)',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'Female', child: Text('Female')),
                          DropdownMenuItem(
                              value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                      const SizedBox(height: 12),

                      // ── Phone with country code (required) ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Autocomplete<String>(
                              initialValue: _countryCode.value,
                              optionsBuilder: (textEditingValue) {
                                final input = textEditingValue.text.trim();
                                if (input.isEmpty) return _commonCodes;
                                return _commonCodes
                                    .where((c) => c.contains(input));
                              },
                              fieldViewBuilder: (context, controller, focusNode,
                                  onFieldSubmitted) {
                                // Keep our own controller in sync.
                                controller.addListener(() {
                                  _countryCode.text = controller.text;
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
                                _countryCode.text = code;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone *',
                              ),
                              keyboardType: TextInputType.phone,
                              autofillHints: const [AutofillHints.telephoneNumber],
                              validator: (v) {
                                final val = (v ?? '').trim();
                                if (val.isEmpty) return 'Required';
                                final digits = val.replaceAll(RegExp(r'\D'), '');
                                if (digits.length != 10) {
                                  return 'Must be 10 digits';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Email (required) ──
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
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

                      // ── Date of birth (optional) ──
                      GestureDetector(
                        onTap: _pickDateOfBirth,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Date of birth (optional)',
                              hintText: _dateOfBirth != null
                                  ? AppDateUtils.displayDate(_dateOfBirth!)
                                  : 'Tap to select',
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

                      // ── Address (optional) ──
                      TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'Address (optional)',
                        ),
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 24),

                      // ── Submit ──
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: chrome.textColor,
                            foregroundColor: chrome.surfaceColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('Register Client'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
