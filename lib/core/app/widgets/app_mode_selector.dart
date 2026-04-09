import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../design_system/theme/app_chrome_theme.dart';
import '../app_mode.dart';
import '../app_mode_cubit.dart';

class AppModeSelector extends StatelessWidget {
  const AppModeSelector({
    super.key,
    this.padding,
  });

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return BlocBuilder<AppModeCubit, AppModeState>(
      buildWhen: (p, n) => p.mode != n.mode || p.forced != n.forced,
      builder: (context, state) {
        final mode = state.mode ?? AppMode.admin;
        final isClient = mode == AppMode.client;
        final disabled = state.forced;

        final outer = BoxDecoration(
          color: chrome.mutedColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: chrome.mutedColor.withOpacity(0.18),
            width: 1,
          ),
        );

        final selected = BoxDecoration(
          color: chrome.textColor,
          borderRadius: BorderRadius.circular(999),
        );

        final unselectedTextColor = scheme.onSurface.withOpacity(0.78);
        final selectedTextColor = chrome.surfaceColor;

        return Padding(
          padding: padding ?? EdgeInsets.zero,
          child: Container(
            height: 44,
            decoration: outer,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      alignment:
                          isClient ? Alignment.centerRight : Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        heightFactor: 1,
                        child: DecoratedBox(decoration: selected),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _ModeChip(
                        label: 'Tutor',
                        selected: !isClient,
                        disabled: disabled,
                        selectedTextColor: selectedTextColor,
                        unselectedTextColor: unselectedTextColor,
                        onTap: () => context.read<AppModeCubit>().setMode(
                              AppMode.admin,
                            ),
                      ),
                    ),
                    Expanded(
                      child: _ModeChip(
                        label: 'Student',
                        selected: isClient,
                        disabled: disabled,
                        selectedTextColor: selectedTextColor,
                        unselectedTextColor: unselectedTextColor,
                        onTap: () => context.read<AppModeCubit>().setMode(
                              AppMode.client,
                            ),
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
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.selectedTextColor,
    required this.unselectedTextColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = disabled ? null : onTap;
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: selected ? selectedTextColor : unselectedTextColor,
        );

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: disabled ? 0.55 : 1,
            child: Text(label, style: textStyle),
          ),
        ),
      ),
    );
  }
}
