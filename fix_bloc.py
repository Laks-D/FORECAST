import re

with open('lib/features/client/presentation/bloc/client_bloc.dart', 'r') as f:
    content = f.read()

content = content.replace("import '../../domain/entities/client_event.dart';", "import '../../domain/entities/client_event.dart' as domain;")
content = content.replace("final event = ClientEvent(", "final event = domain.ClientEvent(")
content = content.replace("type: ClientEventType.", "type: domain.ClientEventType.")

with open('lib/features/client/presentation/bloc/client_bloc.dart', 'w') as f:
    f.write(content)
