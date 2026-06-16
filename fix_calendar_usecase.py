import re

with open('lib/features/calendar/ui/widgets/calendar_page_body.dart', 'r') as f:
    content = f.read()

# I will replace sl<GetClientsUseCase>().execute() with context.read<ClientBloc>().state is ClientLoaded ? (context.read<ClientBloc>().state as ClientLoaded).entities : []
# But since it's used so much, I'll define a local function `List<Client> _getClients() { final state = context.read<ClientBloc>().state; return state is ClientLoaded ? state.entities : []; }`
# Wait, let's just do inline replacement since it's easy in Dart.
inline_get = "(context.read<ClientBloc>().state is ClientLoaded ? (context.read<ClientBloc>().state as ClientLoaded).entities : <Client>[])"

content = content.replace("sl<GetClientsUseCase>().execute()", inline_get)

with open('lib/features/calendar/ui/widgets/calendar_page_body.dart', 'w') as f:
    f.write(content)

with open('lib/features/calendar/ui/widgets/schedule_sessions_sheet.dart', 'r') as f:
    content = f.read()

content = content.replace("import '../../../client/domain/usecases/get_clients_usecase.dart';", "")
content = content.replace("sl<GetClientsUseCase>().execute()", inline_get)

with open('lib/features/calendar/ui/widgets/schedule_sessions_sheet.dart', 'w') as f:
    f.write(content)

