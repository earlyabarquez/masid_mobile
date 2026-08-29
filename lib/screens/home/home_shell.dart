import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../map/map_screen.dart';
import '../reports/reports_screen.dart';
import '../reporting/camera_screen.dart';
import '../alerts/alerts_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/alert_service.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final _alertService = AlertService();
  int _unreadAlerts = 0;
  Timer? _unreadTimer;

  final _screens = const [
    MapScreen(),
    ReportsScreen(),
    SizedBox.shrink(),
    AlertsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _refreshUnread();
    // Poll the unread count every 15s so the badge stays current
    _unreadTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshUnread();
    });
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnread() async {
    try {
      final count = await _alertService.unreadCount();
      if (!mounted) return;
      setState(() => _unreadAlerts = count);
    } catch (_) {
      // keep the last known count on failure
    }
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      ).then((submitted) {
        // If report was submitted, switch to Reports tab
        if (submitted == true) {
          setState(() => _currentIndex = 1);
        }
      });
      return;
    }
    setState(() => _currentIndex = index);
    // Refresh the badge when switching tabs (e.g. after reading alerts)
    _refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map_rounded,
                  label: 'Map',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.description_outlined,
                  activeIcon: Icons.description_rounded,
                  label: 'Reports',
                ),
                _buildFab(),
                _buildNavItem(
                  index: 3,
                  icon: Icons.notifications_outlined,
                  activeIcon: Icons.notifications_rounded,
                  label: 'Alerts',
                  badgeCount: _unreadAlerts,
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int badgeCount = 0,
  }) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: 24,
                  color: isActive ? AppColors.primary : AppColors.label,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -22),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
