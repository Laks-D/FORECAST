import re

with open('lib/core/di/service_locator.dart', 'r') as f:
    content = f.read()

content = content.replace(
    "() => SessionsCubit(sl<ScheduleRepository>()),",
    "() => SessionsCubit(sl<ScheduleRepository>(), recurrenceRepository: sl<RecurrenceRuleRepository>()),"
)

with open('lib/core/di/service_locator.dart', 'w') as f:
    f.write(content)

