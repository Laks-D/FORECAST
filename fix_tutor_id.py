import re

with open('lib/features/calendar/ui/widgets/schedule_sessions_sheet.dart', 'r') as f:
    content = f.read()

content = re.sub(
    r"tutorId: linkedDraft\.first\.clientId, // Wait! tutorId is the authenticated user.*?clientId: _clientId!,",
    "tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',\n        clientId: _clientId!,",
    content,
    flags=re.DOTALL
)

with open('lib/features/calendar/ui/widgets/schedule_sessions_sheet.dart', 'w') as f:
    f.write(content)

