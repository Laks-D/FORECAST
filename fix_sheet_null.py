import re

with open('lib/features/calendar/ui/widgets/schedule_sessions_sheet.dart', 'r') as f:
    content = f.read()

content = content.replace(
    "byWeekday: _frequency == 'Weekly' ? [_weeklyDay] : null,",
    "byWeekday: _frequency == 'Weekly' ? [_weeklyDay] : const [],"
)

with open('lib/features/calendar/ui/widgets/schedule_sessions_sheet.dart', 'w') as f:
    f.write(content)

