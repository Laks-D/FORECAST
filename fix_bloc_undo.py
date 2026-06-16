import re

with open('lib/features/client/presentation/bloc/client_bloc.dart', 'r') as f:
    content = f.read()

content = content.replace("domain.ClientEvent(", "ClientEvent(")
content = content.replace("domain.ClientEventType.", "ClientEventType.")

with open('lib/features/client/presentation/bloc/client_bloc.dart', 'w') as f:
    f.write(content)
