import re
import sys

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'r') as f:
    content = f.read()

content = content.replace("import 'client_payments_page.dart';", "import '../../../payment/presentation/pages/client_transactions_page.dart';")

old_push = """                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<ClientBloc>(),
                                child: ClientPaymentsPage(entity: current),
                              ),
                            ),
                          );"""

new_push = """                          final clientBloc = context.read<ClientBloc>();
                          final sessionsCubit = context.read<SessionsCubit>();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MultiBlocProvider(
                                providers: [
                                  BlocProvider.value(value: clientBloc),
                                  BlocProvider.value(value: sessionsCubit),
                                ],
                                child: ClientTransactionsPage(clientId: current.id),
                              ),
                            ),
                          );"""

content = content.replace(old_push, new_push)

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'w') as f:
    f.write(content)
