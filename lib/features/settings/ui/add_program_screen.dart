import 'package:flutter/material.dart';

import '../../../design_system/theme/app_chrome_theme.dart';

class ProgramFormResult {
  const ProgramFormResult({
    required this.name,
    required this.description,
    required this.classDuration,
    required this.numberOfClasses,
    required this.frequency,
    this.customDays = 1,
  });

  final String name;
  final String description;
  final String classDuration;
  final int numberOfClasses;
  final String frequency;
  final int customDays;
}

class AddProgramScreen extends StatefulWidget {
  const AddProgramScreen({
    super.key,
    this.initialData,
    this.title = 'Program Registration',
    this.submitLabel = 'Add Program',
  });

  final ProgramFormResult? initialData;
  final String title;
  final String submitLabel;

  @override
  State<AddProgramScreen> createState() => _AddProgramScreenState();
}

class _AddProgramScreenState extends State<AddProgramScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _frequency = 'Weekly';
  int _count = 8;
  int _customDays = 1;
  String _duration = '1 Hour';

  static const _durationOptions = <String>[
    '30 Min',
    '1 Hour',
    '2 Hours',
    '3 Hours',
  ];
  static const _customDurationOption = 'Custom';

  List<String> get _durationDropdownValues {
    final values = <String>[..._durationOptions];
    if (!values.contains(_duration)) {
      values.add(_duration);
    }
    values.add(_customDurationOption);
    return values;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    if (initial == null) return;

    _nameController.text = initial.name;
    _descriptionController.text = initial.description;
    _frequency = initial.frequency;
    _count = initial.numberOfClasses;
    _duration = initial.classDuration;
    _customDays = initial.customDays;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }


  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final result = ProgramFormResult(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      classDuration: _duration,
      numberOfClasses: _count,
      frequency: _frequency,
      customDays: _customDays,
    );

    Navigator.of(context).pop(result);
  }

  String _formatCustomDuration({required int hours, required int minutes}) {
    if (hours > 0 && minutes > 0) {
      final hoursLabel = hours == 1 ? '1 Hour' : '$hours Hours';
      return '$hoursLabel $minutes Min';
    }
    if (hours > 0) {
      return hours == 1 ? '1 Hour' : '$hours Hours';
    }
    return '$minutes Min';
  }

  Future<String?> _showCustomDurationDialog() async {
    final hoursController = TextEditingController(text: '0');
    final minutesController = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Custom duration'),
          content: Form(
            key: formKey,
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: hoursController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Hours',
                      hintText: 'e.g. 1',
                    ),
                    validator: (value) {
                      final hours = int.tryParse((value ?? '').trim());
                      if (hours == null || hours < 0) return '0+';
                      if (hours > 12) return 'Max 12';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: minutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      hintText: 'e.g. 30',
                    ),
                    validator: (value) {
                      final minutes = int.tryParse((value ?? '').trim());
                      if (minutes == null || minutes < 0) return '0+';
                      if (minutes > 59) return '0-59';

                      final hours = int.tryParse(hoursController.text.trim()) ?? 0;
                      if (hours == 0 && minutes == 0) return 'Required';

                      final totalMinutes = (hours * 60) + minutes;
                      if (totalMinutes > 720) return 'Max 12h';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final hours = int.parse(hoursController.text.trim());
                final minutes = int.parse(minutesController.text.trim());
                Navigator.of(dialogContext).pop(
                  _formatCustomDuration(hours: hours, minutes: minutes),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    hoursController.dispose();
    minutesController.dispose();
    return result;
  }

  Future<void> _onDurationChanged(String? value) async {
    if (value == null) return;

    if (value == _customDurationOption) {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      final customValue = await _showCustomDurationDialog();
      if (!mounted || customValue == null) return;
      setState(() => _duration = customValue);
      return;
    }

    setState(() => _duration = value);
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final onFrame = ThemeData.estimateBrightnessForColor(chrome.frameColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Scaffold(
      backgroundColor: chrome.frameColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: chrome.surfaceColor,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back),
                          color: onFrame.withOpacity(0.95),
                        ),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: onFrame.withOpacity(0.95),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: chrome.mutedColor.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                          child: Column(
                            children: [
                              _ProgramInput(
                                controller: _nameController,
                                label: 'Name of the program',
                              ),
                              const SizedBox(height: 10),
                              _ProgramInput(
                                controller: _descriptionController,
                                label: 'Program Description',
                                maxLines: 4,
                                isRequired: false,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ProgramDropdownField<String>(
                                      label: 'Frequency',
                                      value: _frequency,
                                      items: const [
                                        DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                                        DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                                        DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                                        DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                                      ],
                                      onChanged: (v) {
                                        if (v == null) return;
                                        setState(() => _frequency = v);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _NumberStepperField(
                                      label: 'Count',
                                      value: _count,
                                      min: 1,
                                      max: 99,
                                      onChanged: (v) => setState(() => _count = v),
                                    ),
                                  ),
                                ],
                              ),
                              if (_frequency == 'Custom') ...[
                                const SizedBox(height: 10),
                                _NumberStepperField(
                                  label: 'Repeat every (days)',
                                  value: _customDays,
                                  min: 1,
                                  max: 365,
                                  onChanged: (v) => setState(() => _customDays = v),
                                ),
                              ],
                              const SizedBox(height: 10),
                              _ProgramDropdownField<String>(
                                label: 'Duration',
                                value: _duration,
                                items: _durationDropdownValues
                                    .map(
                                      (d) => DropdownMenuItem<String>(
                                        value: d,
                                        child: Text(d),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _onDurationChanged,
                              ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.surface,
                                    foregroundColor: chrome.textColor.withOpacity(0.78),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text(widget.submitLabel),
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}

class _ProgramDropdownField<T> extends StatelessWidget {
  const _ProgramDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);
    final borderColor = chrome.textColor.withOpacity(0.38);

    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: chrome.textColor.withOpacity(0.55), width: 1.4),
          borderRadius: BorderRadius.circular(20),
        ),
        floatingLabelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: chrome.textColor.withOpacity(0.75),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: chrome.textColor.withOpacity(0.75),
          fontWeight: FontWeight.w500,
        ),
      ),
      icon: Icon(
        Icons.arrow_drop_down,
        color: chrome.textColor.withOpacity(0.7),
      ),
    );
  }
}

class _NumberStepperField extends StatelessWidget {
  const _NumberStepperField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);
    final borderColor = chrome.textColor.withOpacity(0.38);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: chrome.textColor.withOpacity(0.55), width: 1.4),
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: chrome.textColor.withOpacity(0.75),
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value <= min ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove),
            color: chrome.textColor,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            iconSize: 20,
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$value',
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: value >= max ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add),
            color: chrome.textColor,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}

class _ProgramInput extends StatelessWidget {
  const _ProgramInput({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.isRequired = true,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final borderColor = chrome.textColor.withOpacity(0.38);

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: (value) {
        if (isRequired && (value ?? '').trim().isEmpty) return 'Required';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: chrome.textColor.withOpacity(0.75),
              fontWeight: FontWeight.w500,
            ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: scheme.surface,
        contentPadding: EdgeInsets.fromLTRB(
          12,
          maxLines > 1 ? 18 : 12,
          12,
          maxLines > 1 ? 12 : 12,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: chrome.textColor.withOpacity(0.55), width: 1.4),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
