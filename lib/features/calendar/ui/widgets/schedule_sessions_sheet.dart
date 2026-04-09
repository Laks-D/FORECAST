import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/app/app_mode.dart';
import '../../../../core/storage/program_catalog_storage.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../../design_system/theme/app_visual_style.dart';
import '../../../client/domain/entities/client.dart';
import '../../../client/domain/usecases/get_clients_usecase.dart';
import '../../bloc/sessions_cubit.dart';
import '../../domain/entities/schedule_session.dart';
import '../../domain/services/schedule_generator.dart';

class ScheduleSessionsSheet extends StatefulWidget {
  const ScheduleSessionsSheet({
    super.key,
    required this.initialDate,
    this.presetClientId,
    this.lockClient = false,
    this.initialCount,
  });

  final DateTime initialDate;
  final String? presetClientId;
  final bool lockClient;
  final int? initialCount;

  @override
  State<ScheduleSessionsSheet> createState() => _ScheduleSessionsSheetState();
}

class _ScheduleSessionsSheetState extends State<ScheduleSessionsSheet> {
  final _formKey = GlobalKey<FormState>();

  static const _customDurationKey = '__custom_duration__';

  late final List<Client> _clients;

  String? _clientId;
  String _frequency = 'Weekly';
  int _sessionCount = 8;
  int _weeklyDay = DateTime.monday;
  int _monthlyDate = 1;
  int _startTimeMinutes = 10 * 60;
  int _customDays = 1;
  List<RegisteredProgram> _registeredPrograms = const [];
  String? _programName;
  SessionDuration? _duration;
  int? _customDurationMinutes;

  List<ScheduleSession> _draft = const [];
  Set<int> _clashIds = const {};

  @override
  void initState() {
    super.initState();
    _clients = sl<GetClientsUseCase>().execute();
    _clientId = widget.presetClientId;
    if (widget.initialCount != null) {
      _sessionCount = widget.initialCount!.clamp(1, 60);
    }
    _weeklyDay = widget.initialDate.weekday;
    _monthlyDate = widget.initialDate.day;
    _loadRegisteredPrograms();
  }

  Future<void> _loadRegisteredPrograms() async {
    final programs = await ProgramCatalogStorage.getRegisteredPrograms();
    if (!mounted) return;
    setState(() {
      _registeredPrograms = programs;
      final containsSelected = _registeredPrograms.any((p) => p.name == _programName);
      if (_programName != null && !containsSelected) {
        _programName = null;
      }
    });
  }

  int? _parseDurationMinutes(String label) {
    final text = label.trim().toLowerCase();
    if (text.isEmpty) return null;

    final hourMatch = RegExp(r'(\d+)\s*hour').firstMatch(text);
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(text);

    final hours = hourMatch != null ? int.tryParse(hourMatch.group(1) ?? '') ?? 0 : 0;
    final mins = minMatch != null ? int.tryParse(minMatch.group(1) ?? '') ?? 0 : 0;
    final total = (hours * 60) + mins;

    if (total > 0) return total;

    final onlyNumber = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
    return (onlyNumber != null && onlyNumber > 0) ? onlyNumber : null;
  }

  SessionDuration? _durationFromMinutes(int minutes) {
    switch (minutes) {
      case 30:
        return SessionDuration.halfHour;
      case 60:
        return SessionDuration.oneHour;
      case 120:
        return SessionDuration.twoHours;
      case 180:
        return SessionDuration.threeHours;
      case 480:
        return SessionDuration.wholeDay;
      default:
        return null;
    }
  }

  void _applyProgramTemplate(String? selectedName) {
    if (selectedName == null) {
      setState(() => _programName = null);
      return;
    }

    final selected = _registeredPrograms.cast<RegisteredProgram?>().firstWhere(
          (p) => p?.name == selectedName,
          orElse: () => null,
        );

    if (selected == null) {
      setState(() => _programName = selectedName);
      return;
    }

    final parsedMinutes = _parseDurationMinutes(selected.classDuration);
    final mappedDuration = parsedMinutes != null ? _durationFromMinutes(parsedMinutes) : null;

    setState(() {
      _programName = selected.name;
      if (selected.frequency.isNotEmpty) {
        _frequency = selected.frequency;
      }
      if (selected.numberOfClasses > 0) {
        _sessionCount = selected.numberOfClasses;
      }
      if (_frequency == 'Custom' && selected.customDays > 0) {
        _customDays = selected.customDays;
      }
      _duration = mappedDuration;
      _customDurationMinutes = mappedDuration == null ? parsedMinutes : null;
    });
  }

  void _generateDraft(List<ScheduleSession> existingSessions) {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) return;

    if (_duration == null && _customDurationMinutes == null) {
      setState(() {
        _draft = const [];
        _clashIds = const {};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Select duration'),
        ),
      );
      return;
    }

    // Never generate sessions starting in the past.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final effectiveStart = widget.initialDate.isBefore(today)
        ? today
        : widget.initialDate;

    final maxSessionNo = existingSessions
        .where((s) => s.clientId == _clientId)
        .fold<int>(0, (m, s) => s.sessionNo > m ? s.sessionNo : m);

    final generated = ScheduleGenerator.generate(
      count: _sessionCount,
      startDate: effectiveStart,
      frequency: _frequency,
      timeSlot: AppDateUtils.formatTimeRangeFromStartAndDuration(
        startLabel: AppDateUtils.formatTimeLabelFromMinutes(_startTimeMinutes),
        durationMinutes: _customDurationMinutes ?? ((_duration!.hours) * 60).round(),
      ),
      weeklyDay: _weeklyDay,
      monthlyDate: _monthlyDate,
      clientId: _clientId!,
      startSessionNo: maxSessionNo + 1,
      courseName: _programName,
      duration: _duration,
      customDays: _customDays,
    );

    final clashes = ScheduleGenerator.findClashes(generated, existingSessions);

    setState(() {
      _draft = generated;
      _clashIds = clashes;
    });
  }

  Future<void> _saveDraft() async {
    final cubit = context.read<SessionsCubit>();
    if (_draft.isEmpty) return;
    if (_clashIds.isNotEmpty) return;

    await cubit.addSessions(_draft);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final visual = AppVisualStyle.of(context);

    final isClientMode = AppModeScope.isClient(context);

    final selectedProgram = _registeredPrograms.any((p) => p.name == _programName) ? _programName : null;
    final startLabel = AppDateUtils.formatTimeLabelFromMinutes(_startTimeMinutes);

    Future<void> pickStartTime() async {
      final initial = TimeOfDay(
        hour: (_startTimeMinutes ~/ 60) % 24,
        minute: _startTimeMinutes % 60,
      );

      final picked = await showTimePicker(
        context: context,
        initialTime: initial,
      );
      if (picked == null) return;
      setState(() => _startTimeMinutes = picked.hour * 60 + picked.minute);
    }

    Future<int?> pickCustomDurationMinutes() async {
      final controller = TextEditingController(
        text: (_customDurationMinutes ?? ((_duration ?? SessionDuration.oneHour).hours * 60).round()).toString(),
      );

      return showDialog<int>(
        context: context,
        builder: (context) {
          String? error;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Custom duration'),
                content: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Minutes',
                    errorText: error,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final raw = controller.text.trim();
                      final minutes = int.tryParse(raw);

                      if (minutes == null || minutes <= 0) {
                        setDialogState(() => error = 'Enter minutes');
                        return;
                      }
                      if (minutes < 5 || minutes > 480) {
                        setDialogState(() => error = 'Use 5–480 minutes');
                        return;
                      }
                      Navigator.of(context).pop(minutes);
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        },
      );
    }
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: visual.neumorphism
              ? AppVisualStyle.neumorphicShadows(
                  context,
                  blurRadius: 22,
                  offset: const Offset(10, 10),
                  highlightOpacityLight: 0.55,
                )
              : null,
        ),
        padding: const EdgeInsets.all(20.0),
        child: BlocBuilder<SessionsCubit, SessionsState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Schedule Sessions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _SearchableSelectField<String>(
                        label: 'Client',
                        value: _clientId,
                        displayValue: _clientId != null
                            ? (_clients
                                    .where((c) => c.id == _clientId)
                                    .map((c) => c.name)
                                    .firstOrNull ??
                                'Select')
                            : 'Select',
                        enabled: !widget.lockClient,
                        options: _clients
                            .map((c) => _OptionItem(
                                  value: c.id,
                                  label: c.name,
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _clientId = v),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Select client' : null,
                      ),
                      const SizedBox(height: 12),
                      _SearchableSelectField<String>(
                        label: 'Program',
                        value: selectedProgram,
                        displayValue: selectedProgram ?? 'Select',
                        enabled: _registeredPrograms.isNotEmpty,
                        options: _registeredPrograms
                            .map(
                              (program) => _OptionItem(
                                value: program.name,
                                label: program.name,
                              ),
                            )
                            .toList(),
                        onChanged: _applyProgramTemplate,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DropdownField<String>(
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: _NumberField(
                              label: 'Count',
                              value: _sessionCount,
                              min: 1,
                              max: 60,
                              onChanged: (v) => setState(() => _sessionCount = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: pickStartTime,
                                borderRadius: BorderRadius.circular(16),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Time',
                                    filled: true,
                                    fillColor: scheme.surfaceContainerHighest,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          startLabel,
                                          style: Theme.of(context).textTheme.bodyLarge,
                                        ),
                                      ),
                                      Icon(Icons.access_time, color: scheme.onSurfaceVariant),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<Object>(
                              value: _customDurationMinutes != null
                                  ? _customDurationKey
                                  : _duration,
                              items: [
                                ...SessionDuration.values.map(
                                  (d) => DropdownMenuItem<Object>(
                                    value: d,
                                    child: Text(d.displayName),
                                  ),
                                ),
                                DropdownMenuItem<Object>(
                                  value: _customDurationKey,
                                  child: Text(
                                    _customDurationMinutes == null
                                        ? 'Custom'
                                        : 'Custom (${_customDurationMinutes} min)',
                                  ),
                                ),
                              ],
                              onChanged: (v) async {
                                if (v == null) return;

                                if (v == _customDurationKey) {
                                  final minutes = await pickCustomDurationMinutes();
                                  if (!mounted) return;
                                  if (minutes == null) return;
                                  setState(() {
                                    _duration = null;
                                    _customDurationMinutes = minutes;
                                  });
                                  return;
                                }

                                if (v is SessionDuration) {
                                  setState(() {
                                    _duration = v;
                                    _customDurationMinutes = null;
                                  });
                                }
                              },
                              validator: (v) {
                                if (_duration != null) return null;
                                if (_customDurationMinutes != null) return null;
                                return 'Select duration';
                              },
                              decoration: InputDecoration(
                                labelText: 'Duration',
                                filled: true,
                                fillColor: scheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
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
                      if (_frequency == 'Weekly') ...[
                        const SizedBox(height: 12),
                        _DropdownField<int>(
                          label: 'Day of week',
                          value: _weeklyDay,
                          items: const [
                            DropdownMenuItem(value: DateTime.monday, child: Text('Monday')),
                            DropdownMenuItem(value: DateTime.tuesday, child: Text('Tuesday')),
                            DropdownMenuItem(value: DateTime.wednesday, child: Text('Wednesday')),
                            DropdownMenuItem(value: DateTime.thursday, child: Text('Thursday')),
                            DropdownMenuItem(value: DateTime.friday, child: Text('Friday')),
                            DropdownMenuItem(value: DateTime.saturday, child: Text('Saturday')),
                            DropdownMenuItem(value: DateTime.sunday, child: Text('Sunday')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _weeklyDay = v);
                          },
                        ),
                      ],
                      if (_frequency == 'Monthly') ...[
                        const SizedBox(height: 12),
                        _NumberField(
                          label: 'Day of month',
                          value: _monthlyDate,
                          min: 1,
                          max: 28,
                          onChanged: (v) => setState(() => _monthlyDate = v),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: (isClientMode || state.isLoading)
                                  ? null
                                  : () => _generateDraft(state.sessions),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: scheme.onSurface,
                                  side: BorderSide(color: scheme.outlineVariant),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Generate'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: (isClientMode || _draft.isEmpty || _clashIds.isNotEmpty)
                                  ? null
                                  : _saveDraft,
                              style: FilledButton.styleFrom(
                                backgroundColor: VibrantColors.pastelGreen,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isClientMode) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Client mode: view-only.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: chrome.mutedColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_draft.isNotEmpty) ...[
                  Text(
                    'Preview',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: chrome.textColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 240,
                    child: ListView.separated(
                      itemCount: _draft.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final s = _draft[index];
                        final isClash = _clashIds.contains(s.id);
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: chrome.surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isClash ? VibrantColors.softPink.withOpacity(0.55) : chrome.mutedColor.withOpacity(0.12),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${s.date} • ${s.time}',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: isClash ? VibrantColors.softPink : chrome.textColor,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isClash ? 'Clash with existing session' : 'Session ${s.sessionNo}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: isClash ? VibrantColors.softPink.withOpacity(0.85) : chrome.mutedColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isClash)
                                  Icon(Icons.warning_amber_rounded, color: VibrantColors.softPink, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (_draft.isNotEmpty && _clashIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Resolve clashes to enable Save.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VibrantColors.softPink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            IconButton(
              onPressed: value <= min ? null : () => onChanged(value - 1),
              icon: const Icon(Icons.remove),
              splashRadius: 18,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$value',
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        height: 1.0,
                      ),
                ),
              ),
            ),
            IconButton(
              onPressed: value >= max ? null : () => onChanged(value + 1),
              icon: const Icon(Icons.add),
              splashRadius: 18,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionItem<T> {
  const _OptionItem({required this.value, required this.label});

  final T value;
  final String label;
}

class _SearchableSelectField<T> extends StatefulWidget {
  const _SearchableSelectField({
    required this.label,
    required this.value,
    required this.displayValue,
    required this.options,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final String displayValue;
  final List<_OptionItem<T>> options;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final bool enabled;

  @override
  State<_SearchableSelectField<T>> createState() => _SearchableSelectFieldState<T>();
}

class _SearchableSelectFieldState<T> extends State<_SearchableSelectField<T>> {
  bool _expanded = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _expanded) {
        // Delay collapse so an in-progress tap on a list item can register.
        Future.delayed(const Duration(milliseconds: 120), () {
          if (!mounted || !_expanded) return;
          setState(() {
            _expanded = false;
            _searchController.clear();
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleExpanded(FormFieldState<T> state) {
    if (!widget.enabled) return;
    setState(() {
      _expanded = !_expanded;
      if (!_expanded) {
        _searchController.clear();
        _searchFocusNode.unfocus();
      }
    });
    // Don't auto-focus search — avoids keyboard stealing taps on list items.
    state.validate();
  }

  void _selectOption(FormFieldState<T> state, T? value) {
    widget.onChanged(value);
    state.didChange(value);
    setState(() {
      _expanded = false;
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
    state.validate();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FormField<T>(
      initialValue: widget.value,
      validator: widget.validator,
      builder: (state) {
        final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: widget.enabled
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
          );

        final query = _searchController.text.toLowerCase();
        final filtered = query.isEmpty
            ? widget.options
            : widget.options
                .where((o) => o.label.toLowerCase().contains(query))
                .toList();

        Widget collapsedField() {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleExpanded(state),
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: widget.label,
                  filled: true,
                  enabled: widget.enabled,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  errorText: state.errorText,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.displayValue.isEmpty ? 'Select' : widget.displayValue,
                        style: textStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.filter_list, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          );
        }

        Widget expandedPanel() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.outlineVariant.withOpacity(0.7)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search for ${widget.label}',
                          filled: true,
                          fillColor: scheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          suffixIcon: Icon(Icons.filter_list, color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: filtered.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'No matches found',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final option = filtered[index];
                                  final isSelected = option.value == state.value;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: Material(
                                        color: scheme.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => _selectOption(state, option.value),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isSelected
                                                  ? scheme.primary.withOpacity(0.35)
                                                  : Colors.transparent,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  option.label,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight: FontWeight.w700,
                                                        color: scheme.onSurface,
                                                      ),
                                                ),
                                              ),
                                              if (isSelected)
                                                Icon(Icons.check, color: scheme.primary),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.errorText != null) ...[
                const SizedBox(height: 6),
                Text(
                  state.errorText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ],
          );
        }

        return AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded ? expandedPanel() : collapsedField(),
        );
      },
    );
  }
}
