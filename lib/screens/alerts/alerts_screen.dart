import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 48,
              color: AppColors.label,
            ),
            SizedBox(height: 12),
            Text(
              'Alerts — Step 6',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 14,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
