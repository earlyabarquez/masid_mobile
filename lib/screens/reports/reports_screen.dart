import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 48, color: AppColors.label),
            SizedBox(height: 12),
            Text(
              'Reports — Step 5',
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
