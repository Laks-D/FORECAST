import re

with open('lib/features/client/presentation/pages/client_personal_details_page.dart', 'r') as f:
    content = f.read()

content = content.replace("import '../../domain/entities/client_event.dart';", "import '../../domain/entities/client_event.dart' as domain;")
content = content.replace("List<ClientEvent>", "List<domain.ClientEvent>")

with open('lib/features/client/presentation/pages/client_personal_details_page.dart', 'w') as f:
    f.write(content)
