import 'package:equatable/equatable.dart';

enum CalendarSelectionStyle { neutral, accent }

enum MeterStyle { slim, bold }

enum MeterColorStyle { teal, accent }

final class WidgetCustomizationState extends Equatable {
  const WidgetCustomizationState({
    required this.calendarSelectionStyle,
    required this.meterStyle,
    required this.meterColorStyle,
    this.isLoaded = false,
  });

  factory WidgetCustomizationState.defaults() {
    return const WidgetCustomizationState(
      calendarSelectionStyle: CalendarSelectionStyle.neutral,
      meterStyle: MeterStyle.slim,
      meterColorStyle: MeterColorStyle.teal,
      isLoaded: false,
    );
  }

  final CalendarSelectionStyle calendarSelectionStyle;
  final MeterStyle meterStyle;
  final MeterColorStyle meterColorStyle;

  final bool isLoaded;

  WidgetCustomizationState copyWith({
    CalendarSelectionStyle? calendarSelectionStyle,
    MeterStyle? meterStyle,
    MeterColorStyle? meterColorStyle,
    bool? isLoaded,
  }) {
    return WidgetCustomizationState(
      calendarSelectionStyle: calendarSelectionStyle ?? this.calendarSelectionStyle,
      meterStyle: meterStyle ?? this.meterStyle,
      meterColorStyle: meterColorStyle ?? this.meterColorStyle,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  @override
  List<Object?> get props => [calendarSelectionStyle, meterStyle, meterColorStyle, isLoaded];
}
