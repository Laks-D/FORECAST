import re

with open('lib/features/calendar/domain/services/schedule_generator.dart', 'r') as f:
    content = f.read()

content = content.replace(
"""    int customDays = 1,
    SessionDuration? duration,
    String? courseName,
    String? programEnrollmentId,
  }) {""",
"""    int customDays = 1,
    SessionDuration? duration,
    String? courseName,
    String? programEnrollmentId,
    String? recurrenceId,
  }) {""")

content = content.replace(
"""          courseName: courseName,
          programEnrollmentId: programEnrollmentId,
        ),""",
"""          courseName: courseName,
          programEnrollmentId: programEnrollmentId,
          recurrenceId: recurrenceId,
        ),""")

with open('lib/features/calendar/domain/services/schedule_generator.dart', 'w') as f:
    f.write(content)

