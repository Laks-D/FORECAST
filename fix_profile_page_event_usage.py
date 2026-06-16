import re

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'r') as f:
    content = f.read()

# Fix ClientEventType missing prefix
content = content.replace("ClientEventType.", "domain.ClientEventType.")

# Fix e.metadata
old_metadata = """        final oldStatus = e.metadata?['oldStatus'];
        final newStatus = e.metadata?['newStatus'];"""
new_metadata = """        final oldStatus = null;
        final newStatus = e.status;"""
content = content.replace(old_metadata, new_metadata)

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'w') as f:
    f.write(content)

