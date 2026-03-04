import 'package:flutter/material.dart';

import '../../../core/storage/program_catalog_storage.dart';
import '../../../design_system/theme/app_chrome_theme.dart';
import 'add_program_screen.dart';

class ProgramManagementScreen extends StatefulWidget {
  const ProgramManagementScreen({super.key});

  @override
  State<ProgramManagementScreen> createState() => _ProgramManagementScreenState();
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
              status: 'Active',
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
    final result = await Navigator.of(context).push<ProgramFormResult>(
      MaterialPageRoute<ProgramFormResult>(
        builder: (_) => const AddProgramScreen(),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _programs.insert(
        0,
        _ProgramItem(
          name: result.name,
          status: 'Active',
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
    await ProgramCatalogStorage.saveRegisteredPrograms(
      _programs
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
          .toList(growable: false),
    );
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
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text('Description: ${item.description.isEmpty ? '-' : item.description}'),
                const SizedBox(height: 6),
                Text('Frequency: ${item.frequency.isEmpty ? '-' : item.frequency}'),
                const SizedBox(height: 6),
                Text('Count: ${item.numberOfClasses > 0 ? item.numberOfClasses : '-'}'),
                const SizedBox(height: 6),
                Text('Duration: ${item.classDuration.isEmpty ? '-' : item.classDuration}'),
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
                        onPressed: () => Navigator.of(sheetContext).pop('delete'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
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
      setState(() => _programs.removeAt(index));
      await _persistPrograms();
      return;
    }

    if (action == 'edit') {
      final updated = await Navigator.of(context).push<ProgramFormResult>(
        MaterialPageRoute<ProgramFormResult>(
          builder: (_) => AddProgramScreen(
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
          ),
        ),
      );

      if (!mounted || updated == null) return;

      setState(() {
        _programs[index] = _ProgramItem(
          name: updated.name,
          status: item.status,
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

  List<_ProgramItem> get _filteredPrograms {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _programs;

    return _programs
      .where(
        (p) => p.name.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query) ||
          p.frequency.toLowerCase().contains(query),
      )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filteredPrograms;

    return Scaffold(
      backgroundColor: chrome.frameColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.white,
                  ),
                  Expanded(
                    child: Text(
                      'Program Management',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SearchPill(
                hintText: 'Search program',
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.isEmpty ? 1 : filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (filtered.isEmpty) {
                      return Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            child: Text(
                              'No programs found',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: chrome.mutedColor,
                                ),
                            ),
                          ),
                        ),
                      );
                    }

                    final item = filtered[index];
                    return _ProgramCard(
                      name: item.name,
                      status: item.status,
                      onTap: () => _onProgramTap(item),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _openAddProgram,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.surface,
                    foregroundColor: chrome.textColor.withOpacity(0.78),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Add New Program'),
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
    required this.status,
    this.description = '',
    this.classDuration = '',
    this.numberOfClasses = 0,
    this.frequency = '',
    this.customDays = 1,
  });

  final String name;
  final String status;
  final String description;
  final String classDuration;
  final int numberOfClasses;
  final String frequency;
  final int customDays;
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({
    required this.hintText,
    required this.onChanged,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          prefixIconColor: chrome.mutedColor,
          hintStyle: TextStyle(color: chrome.mutedColor),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.name,
    required this.status,
    required this.onTap,
  });

  final String name;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? '?' : name.characters.first,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                status,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: chrome.mutedColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
