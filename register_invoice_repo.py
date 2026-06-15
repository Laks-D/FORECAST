import re

with open('lib/core/di/service_locator.dart', 'r') as f:
    content = f.read()

import_line = "import '../../features/payment/domain/repositories/invoice_repository.dart';\nimport '../../features/payment/data/firestore_invoice_repository.dart';\n"
if "import '../../features/payment/domain/repositories/invoice_repository.dart';" not in content:
    content = import_line + content

registration_block = """
  sl.registerLazySingleton<InvoiceRepository>(
    () => FirestoreInvoiceRepository(firestore: FirebaseFirestore.instance),
  );
"""

if "sl.registerLazySingleton<InvoiceRepository>" not in content:
    content = content.replace("/* ================= CALENDAR – DATA ================= */", registration_block + "\n/* ================= CALENDAR – DATA ================= */")

with open('lib/core/di/service_locator.dart', 'w') as f:
    f.write(content)

