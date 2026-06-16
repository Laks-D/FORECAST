import re

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'r') as f:
    content = f.read()

content = content.replace("import '../../domain/entities/client_event.dart';", "import '../../domain/entities/client_event.dart' hide ClientEvent;\nimport '../../domain/entities/client_event.dart' as domain show ClientEvent;")

# We need to change the usages of ClientEvent to domain.ClientEvent, except where it's already domain.ClientEvent
# But wait, in client_profile_page.dart, ClientEvent is used as the entity in StreamBuilder<List<ClientEvent>>
# So we can just use `import '../../domain/entities/client_event.dart' as domain;` and prefix usages.

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'w') as f:
    f.write(content.replace("import '../../domain/entities/client_event.dart';", "import '../../domain/entities/client_event.dart' as domain;").replace("List<ClientEvent>", "List<domain.ClientEvent>").replace("(ClientEvent e", "(domain.ClientEvent e"))
