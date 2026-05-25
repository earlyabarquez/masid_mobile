import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../utils/token_storage.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Mock user data (replace with Provider/API later)
  final String _firstName = 'Juan';
  final String _middleInitial = 'S.';
  final String _lastName = 'Dela Cruz';
  final String _email = 'juan.delacruz@email.com';
  final String _phone = '0917 123 4567';

  // Mock stats
  final int _totalReports = 24;
  final int _verified = 18;
  final int _rejected = 3;
  final int _pending = 2;
  final int _critical = 1;
  final int _reportsThisMonth = 6;
  final String _topHazard = 'Flood';

  double get _accuracyRate {
    if (_totalReports == 0) return 0;
    return (_verified / _totalReports) * 100;
  }

  String get _fullName => '$_firstName $_middleInitial $_lastName';

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.heading,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout? You will need to sign in again to submit reports.',
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: 13,
            color: AppColors.muted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await TokenStorage.clearAll();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              // ── Profile header card ──
              _buildProfileCard(),
              const SizedBox(height: 16),

              // ── Stats grid ──
              _buildStatsGrid(),
              const SizedBox(height: 12),

              // ── Extra stats ──
              _buildExtraStats(),
              const SizedBox(height: 16),

              // ── Settings list ──
              _buildSettingsList(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile card ──
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${_firstName[0]}${_lastName[0]}',
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Name + role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName,
                      style: const TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: const Text(
                        'MDRRMO RESPONDER',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Edit button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Contact info
          Row(
            children: [
              const Icon(
                Icons.mail_outline_rounded,
                size: 16,
                color: AppColors.label,
              ),
              const SizedBox(width: 8),
              Text(
                _email,
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.phone_outlined,
                size: 16,
                color: AppColors.label,
              ),
              const SizedBox(width: 8),
              Text(
                _phone,
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stats grid ──
  Widget _buildStatsGrid() {
    return Column(
      children: [
        // Top row
        Row(
          children: [
            _buildStatCard(
              value: '$_totalReports',
              label: 'Total Reports',
              icon: Icons.description_rounded,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            _buildStatCard(
              value: '$_verified',
              label: 'Verified',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
            ),
            const SizedBox(width: 10),
            _buildStatCard(
              value: '${_accuracyRate.toStringAsFixed(0)}%',
              label: 'Accuracy',
              icon: Icons.trending_up_rounded,
              color: _accuracyRate >= 70
                  ? AppColors.success
                  : _accuracyRate >= 40
                  ? AppColors.warning
                  : AppColors.error,
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Bottom row
        Row(
          children: [
            _buildStatCard(
              value: '$_pending',
              label: 'Pending',
              icon: Icons.schedule_rounded,
              color: AppColors.warning,
            ),
            const SizedBox(width: 10),
            _buildStatCard(
              value: '$_rejected',
              label: 'Rejected',
              icon: Icons.cancel_rounded,
              color: AppColors.error,
            ),
            const SizedBox(width: 10),
            _buildStatCard(
              value: '$_critical',
              label: 'Critical',
              icon: Icons.warning_rounded,
              color: const Color(0xFF7C3AED),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Extra stats ──
  Widget _buildExtraStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Reports this month
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_reportsThisMonth',
                      style: const TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading,
                      ),
                    ),
                    const Text(
                      'This month',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(width: 1, height: 36, color: AppColors.border),

          // Top hazard type
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.water_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _topHazard,
                      style: const TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                    ),
                    const Text(
                      'Most reported',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings list ──
  Widget _buildSettingsList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            icon: Icons.person_outline_rounded,
            label: 'Edit Profile',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          const Divider(height: 1, indent: 52),
          _buildSettingsItem(
            icon: Icons.lock_outline_rounded,
            label: 'Change Password',
            onTap: () {
              // TODO: Navigate to change password screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Change password — coming soon',
                    style: TextStyle(fontFamily: 'Sora'),
                  ),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 52),
          _buildSettingsItem(
            icon: Icons.info_outline_rounded,
            label: 'About M.A.S.I.D',
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontWeight: FontWeight.w800,
                      color: AppColors.heading,
                    ),
                  ),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appFullName,
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.body,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'A Kernel Density-Based GIS System for Hazard Risk Assessment and Spatial Analysis in Balilihan, Bohol.',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.6,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 11,
                          color: AppColors.label,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 52),
          _buildSettingsItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            isDestructive: true,
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? AppColors.error : AppColors.secondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? AppColors.error : AppColors.body,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDestructive
                  ? AppColors.error.withValues(alpha: 0.5)
                  : AppColors.label,
            ),
          ],
        ),
      ),
    );
  }
}
