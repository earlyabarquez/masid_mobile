import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: AppColors.success,
            ),
            const SizedBox(height: 16),
            Text(
              'Login Successful',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Home Shell — Step 2.1',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
