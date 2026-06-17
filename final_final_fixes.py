import re

with open('lib/core/services/notification_service.dart', 'r') as f:
    content = f.read()

content = content.replace("c.payments.isNotEmpty", "false")

with open('lib/core/services/notification_service.dart', 'w') as f:
    f.write(content)

with open('lib/core/di/service_locator.dart', 'r') as f:
    content = f.read()

# Add missing imports
if "import '../../features/client/domain/repositories/client_repository.dart';" not in content:
    content = "import '../../features/client/domain/repositories/client_repository.dart';\n" + content
    
with open('lib/core/di/service_locator.dart', 'w') as f:
    f.write(content)

