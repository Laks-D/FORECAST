import re

with open('lib/core/di/service_locator.dart', 'r') as f:
    content = f.read()

content = content.replace(
"""  sl.registerFactory<SessionsCubit>(
    () => SessionsCubit(
      sl<ScheduleRepository>(),
      dataSource: sl<ScheduleLocalDataSource>(),
    ),
  );""",
"""  sl.registerFactory<SessionsCubit>(
    () => SessionsCubit(
      sl<ScheduleRepository>(),
      recurrenceRepository: sl<RecurrenceRuleRepository>(),
      dataSource: sl<ScheduleLocalDataSource>(),
    ),
  );"""
)

with open('lib/core/di/service_locator.dart', 'w') as f:
    f.write(content)

