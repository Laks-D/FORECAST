import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:gendral_app/design_system/theme/app_chrome_theme.dart';

import '../../../calendar/bloc/sessions_cubit.dart';
import '../../domain/entities/client.dart';
import '../bloc/client_bloc.dart';
import '../bloc/client_event.dart';
import '../bloc/client_state.dart';
import 'client_profile_page.dart';
import 'client_registration_page.dart';

/// Common country-code suggestions for the autocomplete (without +, prefix shown in field).
const _quickAddCodes = <String>[
  '91', '1', '44', '971', '61', '65', '966', '974', '965',
  '92', '880', '977', '94', '86', '81', '82', '49', '33',
  '39', '34', '55', '52', '27', '234', '254', '60', '63',
  '66', '62', '7',
];

class ClientPage extends StatefulWidget {
  const ClientPage({super.key, this.embedInDashboard = false});

  final bool embedInDashboard;

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {

  void _showQuickAddClientModal() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final countryCodeController = TextEditingController(text: '91');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Client',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Autocomplete<String>(
                        initialValue: countryCodeController.value,
                        optionsBuilder: (textEditingValue) {
                          final input = textEditingValue.text.trim();
                          if (input.isEmpty) return _quickAddCodes;
                          return _quickAddCodes
                              .where((c) => c.contains(input));
                        },
                        fieldViewBuilder: (context, controller, focusNode,
                            onFieldSubmitted) {
                          controller.addListener(() {
                            countryCodeController.text = controller.text;
                          });
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Code',
                              prefixText: '+',
                            ),
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 14),
                          );
                        },
                        onSelected: (code) {
                          countryCodeController.text = code;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone *'),
                        textInputAction: TextInputAction.done,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!(formKey.currentState?.validate() ?? false)) return;

                      final name = nameController.text.trim();
                      final phone = phoneController.text.trim();
                      final code = countryCodeController.text.trim();

                      context.read<ClientBloc>().add(
                        CreateClient(
                          name: name,
                          primaryContact: phone,
                          countryCode: () {
                            var c = code.replaceAll('+', '');
                            if (c.isEmpty) return '+91';
                            return '+$c';
                          }(),
                        ),
                      );

                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Create Client'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddClientOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.flash_on_outlined),
                title: const Text('Quick add'),
                subtitle: const Text('Name + phone only'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showQuickAddClientModal();
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text('Full registration'),
                subtitle: const Text('Use the registration form'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final clientBloc = context.read<ClientBloc>();
                  final sessionsCubit = context.read<SessionsCubit>();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MultiBlocProvider(
                        providers: [
                          BlocProvider.value(value: clientBloc),
                          BlocProvider.value(value: sessionsCubit),
                        ],
                        child: const ClientRegistrationPage(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);

    return Scaffold(
      backgroundColor: chrome.frameColor,
      body: SafeArea(
        top: !widget.embedInDashboard,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Client',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                    child: IconButton(
                      tooltip: 'Add Client',
                      onPressed: _showAddClientOptions,
                      icon: const Icon(Icons.add),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SearchPill(
                hintText: 'Search customer / phone / program',
                onChanged: (value) {
                  final sessions = context.read<SessionsCubit>().state.sessions;
                  context.read<ClientBloc>().add(SearchClients(value, sessions: sessions));
                },
              ),
              const SizedBox(height: 14),
              Expanded(
                child: BlocBuilder<ClientBloc, ClientState>(
                  builder: (context, state) {
                    if (state is ClientLoading || state is ClientInitial) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    if (state is ClientLoaded) {
                      if (state.entities.isEmpty) {
                        return Center(
                          child: _EmptyCard(
                            message: 'No clients found',
                            surfaceColor: scheme.surface,
                            mutedColor: chrome.mutedColor,
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: state.entities.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final entity = state.entities[index];

                          return _ClientCard(
                            entity: entity,
                            scheme: scheme,
                            chrome: chrome,
                            onTap: () {
                              final clientBloc = context.read<ClientBloc>();
                              final sessionsCubit = context.read<SessionsCubit>();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MultiBlocProvider(
                                    providers: [
                                      BlocProvider.value(value: clientBloc),
                                      BlocProvider.value(value: sessionsCubit),
                                    ],
                                    child: ClientProfilePage(entity: entity),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    }

                    if (state is ClientError) {
                      return Center(
                        child: _EmptyCard(
                          message: state.message,
                          surfaceColor: scheme.surface,
                          mutedColor: chrome.mutedColor,
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const _SearchPill({
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          prefixIconColor: chrome.mutedColor,
          hintStyle: TextStyle(color: chrome.mutedColor),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Client entity;
  final ColorScheme scheme;
  final AppChromeTheme chrome;
  final VoidCallback onTap;

  const _ClientCard({
    required this.entity,
    required this.scheme,
    required this.chrome,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  entity.name.isEmpty ? '?' : entity.name.characters.first,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entity.formattedPhone,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: chrome.mutedColor,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _clientStatusBg(entity.status),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      entity.status,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _clientStatusFg(entity.status),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _clientStatusBg(String status) {
  final s = status.trim().toLowerCase();
  if (s == 'active') return Colors.green.withOpacity(0.12);
  if (s == 'overdue') return Colors.orange.withOpacity(0.12);
  return Colors.blue.withOpacity(0.12);
}

Color _clientStatusFg(String status) {
  final s = status.trim().toLowerCase();
  if (s == 'active') return Colors.green.shade700;
  if (s == 'overdue') return Colors.orange.shade800;
  return Colors.blue.shade700;
}

class _EmptyCard extends StatelessWidget {
  final String message;
  final Color surfaceColor;
  final Color mutedColor;

  const _EmptyCard({
    required this.message,
    required this.surfaceColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: mutedColor,
              ),
        ),
      ),
    );
  }
}
