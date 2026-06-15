import re

with open('lib/features/client/data/firestore_client_repository.dart', 'r') as f:
    content = f.read()

content = content.replace(
    "Client.fromJson(Map<String, dynamic>.from(d.data()), id: d.id)",
    "Client.fromJson(<String, dynamic>{...d.data(), 'id': d.id})"
)

with open('lib/features/client/data/firestore_client_repository.dart', 'w') as f:
    f.write(content)

