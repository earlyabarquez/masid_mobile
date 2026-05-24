import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 48,
              color: AppColors.label,
            ),
            SizedBox(height: 12),
            Text(
              'Profile — Step 7',
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
