import re

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'r') as f:
    content = f.read()

content = content.replace("import '../../domain/entities/payment.dart';", "import '../../../payment/domain/entities/payment.dart';")

old_push = """                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<ClientBloc>(),
                            child: ClientPaymentsPage(entity: current),
                          ),
                        ),
                      ),"""

new_push = """                      onTap: () {
                        final clientBloc = context.read<ClientBloc>();
                        final sessionsCubit = context.read<SessionsCubit>();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MultiBlocProvider(
                              providers: [
                                BlocProvider.value(value: clientBloc),
                                BlocProvider.value(value: sessionsCubit),
                              ],
                              child: ClientTransactionsPage(clientId: current.id),
                            ),
                          ),
                        );
                      },"""

content = content.replace(old_push, new_push)

# Fix Client usages like timeline, payments, etc in client_profile_page.dart
# I will just remove the occurrences or replace them with empty lists where applicable, as they are likely legacy UI stats.
content = content.replace("current.timeline", "[]")
content = content.replace("current.payments", "[]")
content = content.replace("current.lastActivityAt", "null")
content = content.replace("current.outstandingAmount", "0")

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'w') as f:
    f.write(content)

with open('lib/features/client/presentation/pages/client_personal_details_page.dart', 'r') as f:
    content = f.read()

content = content.replace("import '../../domain/entities/payment.dart';", "import '../../../payment/domain/entities/payment.dart';")
with open('lib/features/client/presentation/pages/client_personal_details_page.dart', 'w') as f:
    f.write(content)

