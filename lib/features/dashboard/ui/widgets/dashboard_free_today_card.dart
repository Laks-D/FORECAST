import 'package:flutter/material.dart';

import '../../../../design_system/theme/app_chrome_theme.dart';

class DashboardFreeTodayCard extends StatelessWidget {
  const DashboardFreeTodayCard({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    const cardBgColor = Color(0xFF111214);

    final messageStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: chrome.textColor,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: chrome.mutedColor.withOpacity(0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VibrantColors.softBlue.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/no_schedule_image-removebg-preview.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Relax, you are free today!',
                style: messageStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'No sessions scheduled for now',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: chrome.mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
