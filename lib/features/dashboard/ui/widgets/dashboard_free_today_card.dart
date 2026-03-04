import 'package:flutter/material.dart';

class DashboardFreeTodayCard extends StatelessWidget {
  const DashboardFreeTodayCard({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final messageStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            children: [
              const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child: Image.asset(
                    'assets/no_schedule_image-removebg-preview.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Center(
                child: Text(
                  'looks like you free today',
                  style: messageStyle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
