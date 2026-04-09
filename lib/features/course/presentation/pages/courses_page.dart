import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../../design_system/theme/app_visual_style.dart';
import '../../../../design_system/widgets/app_empty_state.dart';
import '../../../../design_system/widgets/app_loading.dart';
import '../../../../design_system/widgets/app_search_field.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/app/app_mode.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import '../../../client/presentation/bloc/client_bloc.dart';
import '../../../client/presentation/bloc/client_state.dart';
import '../../../client/domain/entities/client.dart';
import 'course_profile_page.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({
    super.key,
    this.embedInDashboard = false,
  });

  final bool embedInDashboard;

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  static const _pinnedPrefsKey = 'pinned_courses_v1';
  Set<String> _pinnedCourseKeys = <String>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadPinnedCourses();
  }

  Future<void> _loadPinnedCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_pinnedPrefsKey) ?? const <String>[];
      if (!mounted) return;
      setState(() => _pinnedCourseKeys = list.toSet());
    } catch (_) {
      // Ignore load failures.
    }
  }

  Future<void> _persistPinnedCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _pinnedPrefsKey,
        _pinnedCourseKeys.toList(growable: false),
      );
    } catch (_) {
      // Ignore persistence failures.
    }
  }

  Future<void> _togglePin(_CourseSummary entity) async {
    final messenger = ScaffoldMessenger.of(context);
    final isPinned = _pinnedCourseKeys.contains(entity.key);

    setState(() {
      if (isPinned) {
        _pinnedCourseKeys.remove(entity.key);
      } else {
        _pinnedCourseKeys.add(entity.key);
      }
    });

    await _persistPinnedCourses();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(isPinned ? 'Course unpinned.' : 'Course pinned.'),
      ),
    );
  }

  List<_CourseSummary> _orderedItems(List<_CourseSummary> input) {
    if (_pinnedCourseKeys.isEmpty) return input;
    final pinned = <_CourseSummary>[];
    final rest = <_CourseSummary>[];
    for (final c in input) {
      if (_pinnedCourseKeys.contains(c.key)) {
        pinned.add(c);
      } else {
        rest.add(c);
      }
    }
    return [...pinned, ...rest];
  }

  void _showViewOnlySnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 1),
        content: Text('Client app: view-only.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final onSurface = scheme.onSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        top: !widget.embedInDashboard,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Courses',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: onSurface,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SearchPill(
                  hintText: 'Search course',
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: BlocBuilder<SessionsCubit, SessionsState>(
                  builder: (context, sessionsState) {
                    if (sessionsState.isLoading) {
                      return AppLoading(color: onSurface);
                    }
                    if (sessionsState.error != null) {
                      return Center(
                        child: AppEmptyState(
                          message: sessionsState.error!,
                          icon: Icons.error_outline,
                        ),
                      );
                    }

                    return BlocBuilder<ClientBloc, ClientState>(
                      builder: (context, clientState) {
                        final clients = switch (clientState) {
                          ClientLoaded(:final entities) => entities,
                          _ => const <Client>[],
                        };

                        // Client perspective requires a linked profile.
                        if (AppModeConfig.isClient && clients.isEmpty) {
                          return const Center(
                            child: AppEmptyState(
                              message: 'No profile linked to this account',
                              icon: Icons.person_outline,
                            ),
                          );
                        }

                        final clientById = {for (final c in clients) c.id: c};

                        final itemsByKey = <String, _CourseSummary>{};
                        for (final s in sessionsState.sessions) {
                          if (AppModeConfig.isClient && !clientById.containsKey(s.clientId)) {
                            continue;
                          }
                          final rawName = (s.courseName ?? '').trim();
                          if (rawName.isEmpty) continue;
                          final key = '${s.clientId}::$rawName';

                          final existing = itemsByKey[key];
                          if (existing == null) {
                            final clientName = clientById[s.clientId]?.displayName ?? 'Client';
                            itemsByKey[key] = _CourseSummary(
                              key: key,
                              clientId: s.clientId,
                              courseName: rawName,
                              clientName: clientName,
                              latestDateStr: s.date,
                            );
                          } else {
                            // Keep a best-effort latest date for sorting/preview.
                            if (s.date.compareTo(existing.latestDateStr) > 0) {
                              itemsByKey[key] = existing.copyWith(latestDateStr: s.date);
                            }
                          }
                        }

                        var items = itemsByKey.values.toList(growable: false);

                        final q = _query.toLowerCase();
                        if (q.isNotEmpty) {
                          items = items
                              .where((c) {
                                return c.courseName.toLowerCase().contains(q);
                              })
                              .toList(growable: false);
                        }

                        items.sort((a, b) {
                          // Pinned first, then alphabetical like Clients.
                          final ap = _pinnedCourseKeys.contains(a.key);
                          final bp = _pinnedCourseKeys.contains(b.key);
                          if (ap != bp) return ap ? -1 : 1;
                          final d = a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase());
                          if (d != 0) return d;
                          return a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
                        });

                        items = _orderedItems(items);

                        if (items.isEmpty) {
                          return const Center(
                            child: AppEmptyState(
                              message: 'No courses found',
                              icon: Icons.menu_book_outlined,
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final entity = items[index];
                            final isPinned = _pinnedCourseKeys.contains(entity.key);

                            return _CourseCard(
                              entity: entity,
                              scheme: scheme,
                              chrome: chrome,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => CourseProfilePage(
                                      clientId: entity.clientId,
                                      courseName: entity.courseName,
                                    ),
                                  ),
                                );
                              },
                              pinned: isPinned,
                              onPinToggle: () => _togglePin(entity),
                              onDelete: _showViewOnlySnack,
                            );
                          },
                        );
                      },
                    );
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
    return AppSearchField(
      hintText: hintText,
      onChanged: onChanged,
    );
  }
}

class _CourseSummary {
  const _CourseSummary({
    required this.key,
    required this.clientId,
    required this.courseName,
    required this.clientName,
    required this.latestDateStr,
  });

  final String key;
  final String clientId;
  final String courseName;
  final String clientName;
  final String latestDateStr;

  _CourseSummary copyWith({String? latestDateStr}) {
    return _CourseSummary(
      key: key,
      clientId: clientId,
      courseName: courseName,
      clientName: clientName,
      latestDateStr: latestDateStr ?? this.latestDateStr,
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.entity,
    required this.scheme,
    required this.chrome,
    required this.onTap,
    required this.pinned,
    this.onPinToggle,
    this.onDelete,
  });

  final _CourseSummary entity;
  final ColorScheme scheme;
  final AppChromeTheme chrome;
  final VoidCallback onTap;
  final bool pinned;
  final VoidCallback? onPinToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final visual = AppVisualStyle.of(context);
    const statusColor = VibrantColors.pastelGreen;

    final cardColor = visual.neumorphism ? scheme.surface : chrome.surfaceColor;
    final shadows = visual.neumorphism
        ? AppVisualStyle.neumorphicShadows(
            context,
            blurRadius: 22,
            offset: const Offset(7, 7),
          )
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ];

    final subtitle = entity.clientName;
    final dateLabel = () {
      try {
        return AppDateUtils.displayDateStr(entity.latestDateStr);
      } catch (_) {
        return entity.latestDateStr;
      }
    }();

    Widget cardBody = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: chrome.mutedColor.withOpacity(0.12)),
        boxShadow: shadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    entity.courseName.isEmpty ? '?' : entity.courseName.characters.first,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entity.courseName,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: chrome.textColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (pinned)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.push_pin,
                                size: 16,
                                color: chrome.accentBlue,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: chrome.mutedColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$subtitle • $dateLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: chrome.mutedColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onDelete == null && onPinToggle == null) return cardBody;
    final pinLabel = pinned ? 'Unpin' : 'Pin';
    final pinIcon = pinned ? Icons.push_pin_outlined : Icons.push_pin;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Slidable(
        key: ValueKey('course_${entity.key}'),
        startActionPane: onPinToggle == null
            ? null
            : ActionPane(
                motion: const BehindMotion(),
                extentRatio: 0.28,
                children: [
                  CustomSlidableAction(
                    onPressed: (ctx) {
                      Slidable.of(ctx)?.close();
                      onPinToggle?.call();
                    },
                    padding: EdgeInsets.zero,
                    child: SizedBox.expand(
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(28),
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(pinIcon, color: scheme.onPrimary),
                              const SizedBox(height: 6),
                              Text(
                                pinLabel,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: scheme.onPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        endActionPane: onDelete == null
            ? null
            : ActionPane(
                motion: const BehindMotion(),
                extentRatio: 0.28,
                children: [
                  CustomSlidableAction(
                    onPressed: (ctx) {
                      Slidable.of(ctx)?.close();
                      onDelete?.call();
                    },
                    padding: EdgeInsets.zero,
                    child: SizedBox.expand(
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.error,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(28),
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline, color: scheme.onError),
                              const SizedBox(height: 6),
                              Text(
                                'Delete',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: scheme.onError,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        child: cardBody,
      ),
    );
  }
}
