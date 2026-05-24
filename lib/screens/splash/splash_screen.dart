import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../utils/token_storage.dart';
import '../auth/login_screen.dart';
import '../home/home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final isLoggedIn = await TokenStorage.isLoggedIn();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            isLoggedIn ? const HomeShell() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo placeholder (replace with Image.asset when ready) ──
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 24),

                // ── App Name ──
                Text(
                  AppConstants.appName,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.heading,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 6),

                // ── Full Name ──
                Text(
                  AppConstants.appFullName,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // ── Tagline ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Text(
                    AppConstants.appTagline,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ── Bottom loading bar ──
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(80, 0, 80, 60),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: const LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
    );
  }
}
