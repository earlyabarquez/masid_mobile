import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MasidApp());
}

class MasidApp extends StatelessWidget {
  const MasidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
