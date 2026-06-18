import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../design_system/theme/app_chrome_theme.dart';
import '../bloc/widget_customization_cubit.dart';
import '../bloc/widget_customization_state.dart';

class WidgetCustomizationScreen extends StatelessWidget {
  const WidgetCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final onFrame = ThemeData.estimateBrightnessForColor(chrome.frameColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Scaffold(
      backgroundColor: chrome.frameColor,
      appBar: AppBar(
        backgroundColor: chrome.frameColor,
        foregroundColor: onFrame,
        elevation: 0,
        title: const Text('Widget customization'),
        actions: [
          TextButton(
            onPressed: () => context.read<WidgetCustomizationCubit>().resetDefaults(),
            style: TextButton.styleFrom(foregroundColor: onFrame),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                children: [
                  _SectionTitle(title: 'Calendar'),
                  const SizedBox(height: 8),
                  _OptionCard(
                    title: 'Selection color',
                    child: BlocBuilder<WidgetCustomizationCubit, WidgetCustomizationState>(
                      buildWhen: (p, n) => p.calendarSelectionStyle != n.calendarSelectionStyle,
                      builder: (context, state) {
                        return _ChoiceRow<CalendarSelectionStyle>(
                          value: state.calendarSelectionStyle,
                          items: const [
                            _ChoiceItem(value: CalendarSelectionStyle.neutral, label: 'Neutral'),
                            _ChoiceItem(value: CalendarSelectionStyle.accent, label: 'Accent'),
                          ],
                          onChanged: (v) => context.read<WidgetCustomizationCubit>().setCalendarSelectionStyle(v),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle(title: 'Dashboard meter'),
                  const SizedBox(height: 8),
                  _OptionCard(
                    title: 'Ring thickness',
                    child: BlocBuilder<WidgetCustomizationCubit, WidgetCustomizationState>(
                      buildWhen: (p, n) => p.meterStyle != n.meterStyle,
                      builder: (context, state) {
                        return _ChoiceRow<MeterStyle>(
                          value: state.meterStyle,
                          items: const [
                            _ChoiceItem(value: MeterStyle.slim, label: 'Slim'),
                            _ChoiceItem(value: MeterStyle.bold, label: 'Bold'),
                          ],
                          onChanged: (v) => context.read<WidgetCustomizationCubit>().setMeterStyle(v),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _OptionCard(
                    title: 'Ring color',
                    child: BlocBuilder<WidgetCustomizationCubit, WidgetCustomizationState>(
                      buildWhen: (p, n) => p.meterColorStyle != n.meterColorStyle,
                      builder: (context, state) {
                        return _ChoiceRow<MeterColorStyle>(
                          value: state.meterColorStyle,
                          items: const [
                            _ChoiceItem(value: MeterColorStyle.teal, label: 'Teal'),
                            _ChoiceItem(value: MeterColorStyle.accent, label: 'Accent'),
                          ],
                          onChanged: (v) => context.read<WidgetCustomizationCubit>().setMeterColorStyle(v),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChoiceItem<T> {
  const _ChoiceItem({required this.value, required this.label});
  final T value;
  final String label;
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({required this.value, required this.items, required this.onChanged});

  final T value;
  final List<_ChoiceItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          ChoiceChip(
            label: Text(item.label),
            selected: item.value == value,
            onSelected: (_) => onChanged(item.value),
          ),
      ],
    );
  }
}
