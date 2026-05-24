import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/storage/program_catalog_storage.dart';
import '../../../design_system/theme/app_chrome_theme.dart';
import '../../../design_system/widgets/app_card.dart';
import '../../../design_system/widgets/app_empty_state.dart';
import '../../../design_system/widgets/app_search_field.dart';
import 'add_program_screen.dart';

class ProgramManagementScreen extends StatefulWidget {
  const ProgramManagementScreen({super.key});

  @override
  State<ProgramManagementScreen> createState() =>
      _ProgramManagementScreenState();
}

class _ProgramManagementScreenState extends State<ProgramManagementScreen> {
  final List<_ProgramItem> _programs = [];

  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    final storedPrograms = await ProgramCatalogStorage.getRegisteredPrograms();
    if (!mounted) return;
    setState(() {
      _programs
        ..clear()
        ..addAll(
          storedPrograms.map(
            (item) => _ProgramItem(
              name: item.name,
              description: item.description,
              classDuration: item.classDuration,
              numberOfClasses: item.numberOfClasses,
              frequency: item.frequency,
              customDays: item.customDays,
            ),
          ),
        );
    });
  }

  Future<void> _openAddProgram() async {
    final result = await _openProgramFormSheet(
      title: 'Program Registration',
      submitLabel: 'Add Program',
    );

    if (!mounted || result == null) return;

    setState(() {
      _programs.insert(
        0,
        _ProgramItem(
          name: result.name,
          description: result.description,
          classDuration: result.classDuration,
          numberOfClasses: result.numberOfClasses,
          frequency: result.frequency,
          customDays: result.customDays,
        ),
      );
    });

    await _persistPrograms();
  }

  Future<void> _persistPrograms() async {
    final registered = _programs
        .map(
          (p) => RegisteredProgram(
            name: p.name,
            description: p.description,
            frequency: p.frequency,
            numberOfClasses: p.numberOfClasses,
            classDuration: p.classDuration,
            customDays: p.customDays,
          ),
        )
        .toList(growable: false);

    await ProgramCatalogStorage.saveRegisteredPrograms(registered);
  }

  Future<void> _onProgramTap(_ProgramItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                    'Description: ${item.description.isEmpty ? '-' : item.description}'),
                const SizedBox(height: 6),
                Text(
                    'Frequency: ${item.frequency.isEmpty ? '-' : item.frequency}'),
                const SizedBox(height: 6),
                Text(
                    'Count: ${item.numberOfClasses > 0 ? item.numberOfClasses : '-'}'),
                const SizedBox(height: 6),
                Text(
                    'Duration: ${item.classDuration.isEmpty ? '-' : item.classDuration}'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop('edit'),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop('delete'),
                        style: FilledButton.styleFrom(
                            backgroundColor: VibrantColors.softPink),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    final index = _programs.indexOf(item);
    if (index < 0) return;

    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dctx) {
          return AlertDialog(
            title: const Text('Delete program?'),
            content: Text('Delete "${item.name}"? This can’t be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (!mounted || confirmed != true) return;

      setState(() => _programs.removeAt(index));
      await _persistPrograms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Program deleted.'),
        ),
      );
      return;
    }

    if (action == 'edit') {
      final updated = await _openProgramFormSheet(
        initialData: ProgramFormResult(
          name: item.name,
          description: item.description,
          classDuration: item.classDuration,
          numberOfClasses: item.numberOfClasses,
          frequency: item.frequency,
          customDays: item.customDays,
        ),
        title: 'Edit Program',
        submitLabel: 'Update Program',
      );

      if (!mounted || updated == null) return;

      setState(() {
        _programs[index] = _ProgramItem(
          name: updated.name,
          description: updated.description,
          classDuration: updated.classDuration,
          numberOfClasses: updated.numberOfClasses,
          frequency: updated.frequency,
          customDays: updated.customDays,
        );
      });

      await _persistPrograms();
    }
  }

  Future<ProgramFormResult?> _openProgramFormSheet({
    ProgramFormResult? initialData,
    required String title,
    required String submitLabel,
  }) {
    return showModalBottomSheet<ProgramFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
              ),
              child: _ProgramFormSheet(
                initialData: initialData,
                title: title,
                submitLabel: submitLabel,
              ),
            ),
          ),
        );
      },
    );
  }

  List<_ProgramItem> get _filteredPrograms {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _programs;

    return _programs
        .where(
          (p) =>
              p.name.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query) ||
              p.frequency.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filteredPrograms;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        title: const Text('Program Management'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSearchField(
                hintText: 'Search program',
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: AppEmptyState(
                          message: 'No programs found',
                          icon: Icons.menu_book_outlined,
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _ProgramCard(
                            name: item.name,
                            onTap: () => _onProgramTap(item),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: AppCard(
                  onTap: _openAddProgram,
                  radius: 16,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18, color: scheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Add New Program',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgramItem {
  const _ProgramItem({
    required this.name,
    this.description = '',
    this.classDuration = '',
    this.numberOfClasses = 0,
    this.frequency = '',
    this.customDays = 1,
  });

  final String name;
  final String description;
  final String classDuration;
  final int numberOfClasses;
  final String frequency;
  final int customDays;
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.name,
    required this.onTap,
  });

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isEmpty ? '?' : name.characters.first,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramFormSheet extends StatefulWidget {
  const _ProgramFormSheet({
    this.initialData,
    required this.title,
    required this.submitLabel,
  });

  final ProgramFormResult? initialData;
  final String title;
  final String submitLabel;

  @override
  State<_ProgramFormSheet> createState() => _ProgramFormSheetState();
}

class _ProgramFormSheetState extends State<_ProgramFormSheet> {
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
    if (initial.frequency.isNotEmpty) {
      _frequency = initial.frequency;
    }
    if (initial.numberOfClasses > 0) {
      _count = initial.numberOfClasses;
    }
    if (initial.customDays > 0) {
      _customDays = initial.customDays;
    }
    if (initial.classDuration.isNotEmpty) {
      _duration = initial.classDuration;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      hintText: 'e.g. 30',
                    ),
                    validator: (value) {
                      final minutes = int.tryParse((value ?? '').trim());
                      if (minutes == null || minutes < 0) return '0+';
                      if (minutes > 59) return '0-59';

                      final hours =
                          int.tryParse(hoursController.text.trim()) ?? 0;
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

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: chrome.mutedColor.withOpacity(0.08)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: scheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return 'Required';
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Name of the program',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: 'Program description (optional)',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _frequency,
                        items: const [
                          DropdownMenuItem(
                              value: 'Daily', child: Text('Daily')),
                          DropdownMenuItem(
                              value: 'Weekly', child: Text('Weekly')),
                          DropdownMenuItem(
                              value: 'Monthly', child: Text('Monthly')),
                          DropdownMenuItem(
                              value: 'Custom', child: Text('Custom')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _frequency = v);
                        },
                        decoration: InputDecoration(
                          labelText: 'Frequency',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NumberField(
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
                  const SizedBox(height: 12),
                  _NumberField(
                    label: 'Repeat every (days)',
                    value: _customDays,
                    min: 1,
                    max: 365,
                    onChanged: (v) => setState(() => _customDays = v),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _duration,
                  items: _durationDropdownValues
                      .map(
                        (d) => DropdownMenuItem<String>(
                          value: d,
                          child: Text(d),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _onDurationChanged,
                  decoration: InputDecoration(
                    labelText: 'Duration',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.onSurface,
                          side: BorderSide(
                              color: scheme.outlineVariant.withOpacity(0.9)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          widget.submitLabel,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
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
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value <= min ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove),
            splashRadius: 18,
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
              ),
            ),
          ),
          IconButton(
            onPressed: value >= max ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}
