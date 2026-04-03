import 'package:flutter/material.dart';

class LoginTextField extends StatelessWidget {
  const LoginTextField({
    super.key,
    required this.onChanged,
    this.labelText,
    this.hintText,
    this.obscureText = false,
    this.suffix,
  });

  final ValueChanged<String> onChanged;
  final String? labelText;
  final String? hintText;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hintStyle = theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withOpacity(0.45),
          fontWeight: FontWeight.w400,
        );
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurface.withOpacity(0.70),
          fontWeight: FontWeight.w600,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null && labelText!.trim().isNotEmpty) ...[
          Text(labelText!, style: labelStyle),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: 54,
          child: TextField(
            obscureText: obscureText,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: hintStyle,
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.primary, width: 1.2),
              ),
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }
}
