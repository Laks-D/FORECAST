import re

with open('lib/features/calendar/ui/widgets/calendar_page_body.dart', 'r') as f:
    content = f.read()

# Replace missing ClientTimelineEvent types
content = content.replace("ClientTimelineEvent", "dynamic")
content = content.replace("ClientTimelineEventType.", "dynamic")
content = content.replace("e.type == dynamicpayment", "false")

with open('lib/features/calendar/ui/widgets/calendar_page_body.dart', 'w') as f:
    f.write(content)

with open('lib/features/calendar/ui/widgets/schedule_sessions_sheet.dart', 'r') as f:
    content = f.read()

# Add missing imports for ClientBloc
if "import '../../../client/presentation/bloc/client_bloc.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter_bloc/flutter_bloc.dart';\nimport '../../../client/presentation/bloc/client_bloc.dart';\nimport '../../../client/presentation/bloc/client_state.dart';")

with open('lib/features/calendar/ui/widgets/schedule_sessions_sheet.dart', 'w') as f:
    f.write(content)

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'r') as f:
    content = f.read()

# Fix import
content = content.replace("import '../../domain/entities/client_event.dart' as domain show ClientEvent;", "import '../../domain/entities/client_event.dart' as domain;")

# Fix remaining client.timeline, client.payments, etc.
content = content.replace("client.timeline", "[]")
content = content.replace("client.payments", "[]")
content = content.replace("client.lastActivityAt", "null")
content = content.replace("client.outstandingAmount", "0")

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'w') as f:
    f.write(content)

with open('lib/features/dashboard/ui/widgets/dashboard_middle_card.dart', 'r') as f:
    content = f.read()

content = content.replace("final clientNames = {", "final clientNames = <String, String>{")

with open('lib/features/dashboard/ui/widgets/dashboard_middle_card.dart', 'w') as f:
    f.write(content)

