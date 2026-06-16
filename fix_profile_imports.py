import re

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'r') as f:
    content = f.read()

# Replace all forms of import for client_event.dart with just a clean one.
content = re.sub(r"import '../../domain/entities/client_event\.dart'.*?\n", "", content)

# Prepend the correct imports
correct_imports = "import '../../domain/entities/client_event.dart' as domain;\n"
content = correct_imports + content

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'w') as f:
    f.write(content)

