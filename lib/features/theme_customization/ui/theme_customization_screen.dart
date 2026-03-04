import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

import '../../../design_system/theme/app_chrome_theme.dart';
import '../bloc/app_theme_cubit.dart';
import '../bloc/app_theme_state.dart';

class ThemeCustomizationScreen extends StatefulWidget {
  const ThemeCustomizationScreen({super.key});

  @override
  State<ThemeCustomizationScreen> createState() => _ThemeCustomizationScreenState();
}

enum _ThemeStyleTab { themes, custom }

class _ThemeCustomizationScreenState extends State<ThemeCustomizationScreen> {
  _ThemeStyleTab _tab = _ThemeStyleTab.themes;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return Scaffold(
      backgroundColor: chrome.frameColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Theme & Style',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _TabPills(
                tab: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: chrome.surfaceColor,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: switch (_tab) {
                        _ThemeStyleTab.themes => const _ThemesTab(key: ValueKey('themes')),
                        _ThemeStyleTab.custom => const _CustomTab(key: ValueKey('custom')),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPills extends StatelessWidget {
  const _TabPills({required this.tab, required this.onChanged});

  final _ThemeStyleTab tab;
  final ValueChanged<_ThemeStyleTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final bg = Colors.black.withOpacity(0.18);
    final sel = chrome.accentBlue;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabPill(
              label: 'Themes',
              icon: Icons.palette_outlined,
              selected: tab == _ThemeStyleTab.themes,
              selectedColor: sel,
              onTap: () => onChanged(_ThemeStyleTab.themes),
            ),
          ),
          Expanded(
            child: _TabPill(
              label: 'Custom',
              icon: Icons.tune,
              selected: tab == _ThemeStyleTab.custom,
              selectedColor: sel,
              onTap: () => onChanged(_ThemeStyleTab.custom),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Material(
        color: selected ? selectedColor.withOpacity(0.30) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.white.withOpacity(selected ? 1 : 0.85)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withOpacity(selected ? 1 : 0.85),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemesTab extends StatelessWidget {
  const _ThemesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final muted = chrome.mutedColor;

    return BlocBuilder<AppThemeCubit, AppThemeState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          children: [
            Text(
              'Choose Your Theme',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick from light or dark themes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            _SectionHeader(icon: Icons.wb_sunny_outlined, title: 'Light Themes'),
            const SizedBox(height: 10),
            _ThemeGrid(
              themes: _ThemePresets.light,
              selectedId: state.activeThemeId,
              onSelected: (preset) => context.read<AppThemeCubit>().applyPreset(preset.state, presetId: preset.id),
            ),
            const SizedBox(height: 16),
            _SectionHeader(icon: Icons.nightlight_round, title: 'Dark Themes'),
            const SizedBox(height: 10),
            _ThemeGrid(
              themes: _ThemePresets.dark,
              selectedId: state.activeThemeId,
              onSelected: (preset) => context.read<AppThemeCubit>().applyPreset(preset.state, presetId: preset.id),
            ),
          ],
        );
      },
    );
  }
}

class _CustomTab extends StatefulWidget {
  const _CustomTab({super.key});

  @override
  State<_CustomTab> createState() => _CustomTabState();
}

class _CustomTabState extends State<_CustomTab> {
  final _nameController = TextEditingController();
  String? _startFrom;
  bool _linkLightAndDark = false;

  final List<AppThemeState> _undoStack = <AppThemeState>[];
  late AppThemeState _draft;

  @override
  void initState() {
    super.initState();
    // Initialize once; do NOT overwrite on every rebuild (it breaks typing).
    final state = context.read<AppThemeCubit>().state;
    _draft = state.copyWith(activeThemeId: 'custom');
    _nameController.text = _draft.customThemeName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    final isDark = _draft.themeMode == ThemeMode.dark;
    final frame = _draft.frameColor;
    final accent = _draft.accentBlue;
    final bg = isDark ? _draft.darkBackground : _draft.lightBackground;
    final surface = isDark ? _draft.darkSurface : _draft.lightSurface;
    final text = isDark ? _draft.darkText : _draft.lightText;
    final muted = isDark ? _draft.darkMuted : _draft.lightMuted;

    void setDraft(AppThemeState next) => setState(() => _draft = next.copyWith(activeThemeId: 'custom'));

    void revertToPrevious() {
      if (_undoStack.isEmpty) return;

      final previous = _undoStack.removeLast();
      final cubit = context.read<AppThemeCubit>();
      cubit.applyPreset(previous, presetId: previous.activeThemeId);

      setState(() {
        _draft = cubit.state.copyWith(activeThemeId: 'custom');
        _nameController.text = _draft.customThemeName;
        _startFrom = null;
      });
    }

    AppThemeState? undoBaseline() {
      if (_undoStack.isEmpty) return null;
      return _undoStack.last;
    }

    void setFrame(Color c) => setDraft(_draft.copyWith(frameColor: c));
    void setAccent(Color c) => setDraft(_draft.copyWith(accentBlue: c));
    void setBackground(Color c) {
      if (_linkLightAndDark) {
        setDraft(_draft.copyWith(lightBackground: c, darkBackground: c));
        return;
      }
      setDraft(isDark ? _draft.copyWith(darkBackground: c) : _draft.copyWith(lightBackground: c));
    }

    void setSurface(Color c) {
      if (_linkLightAndDark) {
        setDraft(_draft.copyWith(lightSurface: c, darkSurface: c));
        return;
      }
      setDraft(isDark ? _draft.copyWith(darkSurface: c) : _draft.copyWith(lightSurface: c));
    }

    void setText(Color c) {
      if (_linkLightAndDark) {
        setDraft(_draft.copyWith(lightText: c, darkText: c));
        return;
      }
      setDraft(isDark ? _draft.copyWith(darkText: c) : _draft.copyWith(lightText: c));
    }

    void setMuted(Color c) {
      if (_linkLightAndDark) {
        setDraft(_draft.copyWith(lightMuted: c, darkMuted: c));
        return;
      }
      setDraft(isDark ? _draft.copyWith(darkMuted: c) : _draft.copyWith(lightMuted: c));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      children: [
            Text(
              'Create Custom Theme',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Design your own unique theme or modify an existing one',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: chrome.mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            _Block(
              title: 'Theme Name',
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                  isDense: true,
                ),
                onChanged: (v) => setDraft(_draft.copyWith(customThemeName: v)),
              ),
            ),
            const SizedBox(height: 12),
            _Block(
              title: 'Start from Existing Theme',
              subtitle: 'Copy colors from a preset theme to customize',
              child: DropdownButtonFormField<String?>(
                value: _startFrom,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Select a theme...')),
                  const DropdownMenuItem<String?>(value: 'current', child: Text('Same as current theme')),
                  ..._ThemePresets.all.map(
                    (p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
                  ),
                ],
                onChanged: (id) {
                  setState(() => _startFrom = id);
                  if (id == null) return;
                  final source = id == 'current' ? context.read<AppThemeCubit>().state : _ThemePresets.byId(id)?.state;
                  if (source == null) return;

                  setState(() {
                    _draft = source.copyWith(
                      activeThemeId: 'custom',
                      customThemeName: _nameController.text.trim().isEmpty ? source.customThemeName : _nameController.text.trim(),
                    );
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            _Block(
              title: 'Same for Light & Dark',
              subtitle: 'Apply your custom colors to both modes',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _linkLightAndDark ? 'Enabled' : 'Disabled',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: chrome.mutedColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Switch(
                    value: _linkLightAndDark,
                    onChanged: (v) => setState(() => _linkLightAndDark = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _undoStack.isEmpty ? null : revertToPrevious,
                child: const Text('Revert to previous'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Theme Colors',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _ColorPickRow(
              title: 'Frame Color',
              color: frame,
              onPick: () => _showColorDialog(
                context,
                title: 'Frame Color',
                initial: frame,
                onApply: setFrame,
              ),
              onReset: () {
                final base = undoBaseline();
                if (base == null) return;
                setFrame(base.frameColor);
              },
            ),
            const SizedBox(height: 10),
            _ColorPickRow(
              title: 'Primary Color',
              color: accent,
              onPick: () => _showColorDialog(
                context,
                title: 'Primary Color',
                initial: accent,
                onApply: setAccent,
              ),
              onReset: () {
                final base = undoBaseline();
                if (base == null) return;
                setAccent(base.accentBlue);
              },
            ),
            const SizedBox(height: 10),
            _ColorPickRow(
              title: 'Background Color',
              color: bg,
              onPick: () => _showColorDialog(
                context,
                title: 'Background Color',
                initial: bg,
                onApply: setBackground,
              ),
              onReset: () {
                final base = undoBaseline();
                if (base == null) return;
                if (_linkLightAndDark) {
                  setDraft(_draft.copyWith(lightBackground: base.lightBackground, darkBackground: base.darkBackground));
                  return;
                }
                setBackground(isDark ? base.darkBackground : base.lightBackground);
              },
            ),
            const SizedBox(height: 10),
            _ColorPickRow(
              title: 'Surface Color',
              color: surface,
              onPick: () => _showColorDialog(
                context,
                title: 'Surface Color',
                initial: surface,
                onApply: setSurface,
              ),
              onReset: () {
                final base = undoBaseline();
                if (base == null) return;
                if (_linkLightAndDark) {
                  setDraft(_draft.copyWith(lightSurface: base.lightSurface, darkSurface: base.darkSurface));
                  return;
                }
                setSurface(isDark ? base.darkSurface : base.lightSurface);
              },
            ),
            const SizedBox(height: 10),
            _ColorPickRow(
              title: 'Text Color',
              color: text,
              onPick: () => _showColorDialog(
                context,
                title: 'Text Color',
                initial: text,
                onApply: setText,
              ),
              onReset: () {
                final base = undoBaseline();
                if (base == null) return;
                if (_linkLightAndDark) {
                  setDraft(_draft.copyWith(lightText: base.lightText, darkText: base.darkText));
                  return;
                }
                setText(isDark ? base.darkText : base.lightText);
              },
            ),
            const SizedBox(height: 10),
            _ColorPickRow(
              title: 'Muted Color',
              color: muted,
              onPick: () => _showColorDialog(
                context,
                title: 'Muted Color',
                initial: muted,
                onApply: setMuted,
              ),
              onReset: () {
                final base = undoBaseline();
                if (base == null) return;
                if (_linkLightAndDark) {
                  setDraft(_draft.copyWith(lightMuted: base.lightMuted, darkMuted: base.darkMuted));
                  return;
                }
                setMuted(isDark ? base.darkMuted : base.lightMuted);
              },
            ),
            const SizedBox(height: 16),
            _ThemePreviewCard(
              primary: accent,
              surface: surface,
              text: text,
              muted: muted,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: chrome.accentBlue),
                onPressed: () {
                  final cubit = context.read<AppThemeCubit>();
                  // Keep up to 3 undo steps (pre-apply snapshots).
                  _undoStack.add(cubit.state);
                  if (_undoStack.length > 3) {
                    _undoStack.removeAt(0);
                  }
                  cubit.applyPreset(_draft.copyWith(activeThemeId: 'custom'), presetId: 'custom');
                  setState(() => _draft = cubit.state.copyWith(activeThemeId: 'custom'));
                },
                child: const Text('Apply Custom Theme'),
              ),
            ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: chrome.mutedColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({required this.themes, required this.selectedId, required this.onSelected});

  final List<_ThemePreset> themes;
  final String selectedId;
  final ValueChanged<_ThemePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = (constraints.maxWidth - 12) / 2;
        final cardH = (cardW * 1.05).clamp(140.0, 200.0);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in themes)
              SizedBox(
                width: cardW,
                height: cardH,
                child: _ThemeCard(
                  preset: t,
                  selected: selectedId == t.id,
                  onTap: () => onSelected(t),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.preset, required this.selected, required this.onTap});

  final _ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final border = selected ? chrome.accentBlue : Colors.black.withOpacity(0.10);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: preset.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: preset.text,
                      ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: preset.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: preset.muted.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: preset.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: preset.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Dot(preset.accent),
                    const SizedBox(width: 6),
                    _Dot(preset.muted),
                    const SizedBox(width: 6),
                    _Dot(preset.text),
                    const Spacer(),
                    Icon(preset.isDark ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                        size: 16, color: preset.muted),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle, size: 16, color: chrome.accentBlue),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withOpacity(0.12)),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: chrome.mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ColorPickRow extends StatelessWidget {
  const _ColorPickRow({required this.title, required this.color, required this.onPick, this.onReset});

  final String title;
  final Color color;
  final VoidCallback onPick;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(hex, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: chrome.mutedColor)),
              ],
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.14)),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 34,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: chrome.accentBlue),
              onPressed: onPick,
              child: const Text('Pick'),
            ),
          ),
          if (onReset != null) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Revert',
              onPressed: onReset,
              icon: Icon(Icons.refresh, color: chrome.mutedColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({required this.primary, required this.surface, required this.text, required this.muted});

  final Color primary;
  final Color surface;
  final Color text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.crop_square, size: 16, color: muted),
              const SizedBox(width: 8),
              Text('Theme Preview', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Text('App Preview', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: text, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Sample Text', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: text, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('This is how your text will look', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: primary),
                    onPressed: () {},
                    child: const Text('Primary Button'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showColorDialog(
  BuildContext context, {
  required String title,
  required Color initial,
  required ValueChanged<Color> onApply,
}) async {
  final chrome = AppChromeTheme.of(context);
  final picked = await showDialog<Color>(
    context: context,
    builder: (context) {
      Color current = initial;
      return AlertDialog(
        title: Text(title),
        backgroundColor: chrome.surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: 420,
              child: ColorPicker(
                color: current,
                onColorChanged: (c) => setState(() => current = c),
                width: 34,
                height: 34,
                borderRadius: 50,
                spacing: 10,
                runSpacing: 10,
                enableOpacity: true,
                showMaterialName: true,
                showColorCode: true,
                colorCodeHasColor: true,
                pickersEnabled: const <ColorPickerType, bool>{
                  ColorPickerType.wheel: true,
                  ColorPickerType.primary: true,
                  ColorPickerType.accent: true,
                },
                copyPasteBehavior: const ColorPickerCopyPasteBehavior(longPressMenu: true),
                customColorSwatchesAndNames: <ColorSwatch<Object>, String>{
                  ColorTools.createPrimarySwatch(chrome.accentBlue): 'On this page',
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: chrome.accentBlue),
            onPressed: () => Navigator.of(context).pop(current),
            child: const Text('Apply'),
          ),
        ],
      );
    },
  );

  if (picked != null) onApply(picked);
}

class _ThemePreset {
  const _ThemePreset({
    required this.id,
    required this.name,
    required this.isDark,
    required this.accent,
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.frame,
  });

  final String id;
  final String name;
  final bool isDark;
  final Color accent;
  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color frame;

  AppThemeState get state {
    if (isDark) {
      return AppThemeState.presetBase.copyWith(
        themeMode: ThemeMode.dark,
        activeThemeId: id,
        frameColor: frame,
        accentBlue: accent,
        darkBackground: background,
        darkSurface: surface,
        darkText: text,
        darkMuted: muted,
      );
    }

    return AppThemeState.presetBase.copyWith(
      themeMode: ThemeMode.light,
      activeThemeId: id,
      frameColor: frame,
      accentBlue: accent,
      lightBackground: background,
      lightSurface: surface,
      lightText: text,
      lightMuted: muted,
    );
  }
}

class _ThemePresets {
  static const light = <_ThemePreset>[
    _ThemePreset(
      id: 'warm_neutral',
      name: 'Warm Neutral',
      isDark: false,
      accent: Color(0xFF72383D),
      background: Color(0xFFEFE9E1),
      surface: Color(0xFFD9D9D9),
      text: Color(0xFF322D29),
      muted: Color(0xFFAC9C8D),
      frame: Color(0xFFD1C7BD),
    ),
    _ThemePreset(
      id: 'matte_ivory',
      name: 'Matte Ivory',
      isDark: false,
      accent: Color(0xFF6D73E6),
      background: Color(0xFFF8FAFC),
      surface: Color(0xFFFFFFFF),
      text: Color(0xFF111827),
      muted: Color(0xFF64748B),
      frame: Color(0xFFF1F5F9),
    ),
    _ThemePreset(
      id: 'fogstone',
      name: 'Fogstone',
      isDark: false,
      accent: Color(0xFF64748B),
      background: Color(0xFFF8FAFC),
      surface: Color(0xFFFFFFFF),
      text: Color(0xFF0F172A),
      muted: Color(0xFF64748B),
      frame: Color(0xFFE2E8F0),
    ),
    _ThemePreset(
      id: 'matte_copper_light',
      name: 'Matte Copper Light',
      isDark: false,
      accent: Color(0xFFB45309),
      background: Color(0xFFFFF7ED),
      surface: Color(0xFFFFFFFF),
      text: Color(0xFF111827),
      muted: Color(0xFF9A3412),
      frame: Color(0xFFFFEDD5),
    ),
    _ThemePreset(
      id: 'slate_mist',
      name: 'Slate Mist',
      isDark: false,
      accent: Color(0xFF3B82F6),
      background: Color(0xFFF8FAFC),
      surface: Color(0xFFFFFFFF),
      text: Color(0xFF0F172A),
      muted: Color(0xFF64748B),
      frame: Color(0xFFE2E8F0),
    ),
    _ThemePreset(
      id: 'rose_linen',
      name: 'Rose Linen',
      isDark: false,
      accent: Color(0xFFF472B6),
      background: Color(0xFFFFF1F2),
      surface: Color(0xFFFFFFFF),
      text: Color(0xFF111827),
      muted: Color(0xFFBE185D),
      frame: Color(0xFFFFE4E6),
    ),
    _ThemePreset(
      id: 'peach_mist',
      name: 'Peach Mist',
      isDark: false,
      accent: Color(0xFFFB923C),
      background: Color(0xFFFFF7ED),
      surface: Color(0xFFFFFFFF),
      text: Color(0xFF111827),
      muted: Color(0xFF9A3412),
      frame: Color(0xFFFFEDD5),
    ),
  ];

  static const dark = <_ThemePreset>[
    _ThemePreset(
      id: 'graphite',
      name: 'Graphite',
      isDark: true,
      accent: Color(0xFF93C5FD),
      background: Color(0xFF0F172A),
      surface: Color(0xFF111827),
      text: Color(0xFFE5E7EB),
      muted: Color(0xFF94A3B8),
      frame: Color(0xFF0B1020),
    ),
    _ThemePreset(
      id: 'obsidian',
      name: 'Obsidian',
      isDark: true,
      accent: Color(0xFF93C5FD),
      background: Color(0xFF0B0B0B),
      surface: Color(0xFF111827),
      text: Color(0xFFE5E7EB),
      muted: Color(0xFF9CA3AF),
      frame: Color(0xFF050505),
    ),
    _ThemePreset(
      id: 'midnight_azure',
      name: 'Midnight Azure',
      isDark: true,
      accent: Color(0xFF38BDF8),
      background: Color(0xFF0B1220),
      surface: Color(0xFF0F172A),
      text: Color(0xFFE0F2FE),
      muted: Color(0xFF7DD3FC),
      frame: Color(0xFF070B14),
    ),
    _ThemePreset(
      id: 'charcoal_rose',
      name: 'Charcoal Rose',
      isDark: true,
      accent: Color(0xFFF472B6),
      background: Color(0xFF1B1420),
      surface: Color(0xFF241A2B),
      text: Color(0xFFFCE7F3),
      muted: Color(0xFFF9A8D4),
      frame: Color(0xFF130F1A),
    ),
    _ThemePreset(
      id: 'copper_dark',
      name: 'Copper Dark',
      isDark: true,
      accent: Color(0xFFFB923C),
      background: Color(0xFF1A120D),
      surface: Color(0xFF241A12),
      text: Color(0xFFFFEDD5),
      muted: Color(0xFFFDBA74),
      frame: Color(0xFF130C09),
    ),
    _ThemePreset(
      id: 'velvet_noir',
      name: 'Velvet Noir',
      isDark: true,
      accent: Color(0xFF8B5CF6),
      background: Color(0xFF130F1A),
      surface: Color(0xFF1C1524),
      text: Color(0xFFEDE9FE),
      muted: Color(0xFFA78BFA),
      frame: Color(0xFF100B16),
    ),
  ];

  static List<_ThemePreset> get all => [...light, ...dark];

  static _ThemePreset? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
