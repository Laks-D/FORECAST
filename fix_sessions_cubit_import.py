import re

with open('lib/features/calendar/bloc/sessions_cubit.dart', 'r') as f:
    content = f.read()

content = content.replace(
    "import '../domain/repositories/recurrence_rule_repository.dart';",
    "import '../data/recurrence_rule_repository.dart';"
)

with open('lib/features/calendar/bloc/sessions_cubit.dart', 'w') as f:
    f.write(content)

