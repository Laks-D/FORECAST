import re

with open('lib/features/calendar/ui/widgets/calendar_page_body.dart', 'r') as f:
    content = f.read()

content = content.replace("dynamicType.payment", "null")
content = content.replace("dynamicType.statusChanged", "null")
content = content.replace("dynamicType", "null")

with open('lib/features/calendar/ui/widgets/calendar_page_body.dart', 'w') as f:
    f.write(content)

with open('lib/core/services/notification_service.dart', 'r') as f:
    content = f.read()

content = content.replace("client.payments", "[]")

with open('lib/core/services/notification_service.dart', 'w') as f:
    f.write(content)

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'r') as f:
    content = f.read()

content = content.replace("current.timeline", "[]")
content = content.replace("current.payments", "[]")
content = content.replace("current.lastActivityAt", "null")
content = content.replace("current.outstandingAmount", "0")

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'w') as f:
    f.write(content)

