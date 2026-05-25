import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'report_detail_screen.dart';

// Mock report data (replace with API + offline DB later)
class MockReport {
  final String id;
  final String type;
  final String description;
  final int severity;
  final double lat;
  final double lng;
  final String status;
  final String date;
  final String? imageUrl;
  final String? adminNotes;

  const MockReport({
    required this.id,
    required this.type,
    required this.description,
    required this.severity,
    required this.lat,
    required this.lng,
    required this.status,
    required this.date,
    this.imageUrl,
    this.adminNotes,
  });

  Color get statusColor {
    switch (status) {
      case 'Verified':
        return AppColors.success;
      case 'Rejected':
        return AppColors.error;
      case 'Critical':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Color get statusBg {
    switch (status) {
      case 'Verified':
        return AppColors.verifiedBg;
      case 'Rejected':
        return AppColors.rejectedBg;
      case 'Critical':
        return AppColors.criticalBg;
      default:
        return AppColors.pendingBg;
    }
  }

  Color get statusText {
    switch (status) {
      case 'Verified':
        return AppColors.verifiedText;
      case 'Rejected':
        return AppColors.rejectedText;
      case 'Critical':
        return AppColors.criticalText;
      default:
        return AppColors.pendingText;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'Flood':
        return Icons.water_rounded;
      case 'Landslide':
        return Icons.landscape_rounded;
      case 'Fire':
        return Icons.local_fire_department_rounded;
      case 'Earthquake':
        return Icons.vibration_rounded;
      case 'Road Accident':
        return Icons.car_crash_rounded;
      case 'Storm Surge':
        return Icons.waves_rounded;
      case 'Typhoon':
        return Icons.thunderstorm_rounded;
      case 'Flash Flood':
        return Icons.flood_rounded;
      default:
        return Icons.warning_rounded;
    }
  }

  Color get severityColor {
    switch (severity) {
      case 5:
        return const Color(0xFFDC2626);
      case 4:
        return const Color(0xFFEA580C);
      case 3:
        return const Color(0xFFF59E0B);
      case 2:
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF16A34A);
    }
  }
}

final List<MockReport> _mockReports = [
  const MockReport(
    id: '1',
    type: 'Flood',
    description:
        'Knee-deep flooding along the main road near the public market.',
    severity: 4,
    lat: 9.7745,
    lng: 123.9640,
    status: 'Verified',
    date: '2026-05-23',
  ),
  const MockReport(
    id: '2',
    type: 'Landslide',
    description:
        'Soil erosion and partial road blockage on the hillside access road.',
    severity: 5,
    lat: 9.7790,
    lng: 123.9580,
    status: 'Critical',
    date: '2026-05-24',
  ),
  const MockReport(
    id: '3',
    type: 'Road Accident',
    description:
        'Motorcycle collision at the intersection near the barangay hall.',
    severity: 3,
    lat: 9.7710,
    lng: 123.9700,
    status: 'Rejected',
    date: '2026-05-22',
    adminNotes:
        'Duplicate report. This incident was already reported by another responder.',
  ),
  const MockReport(
    id: '4',
    type: 'Fire',
    description: 'Grass fire spreading near residential area.',
    severity: 4,
    lat: 9.7680,
    lng: 123.9620,
    status: 'Pending',
    date: '2026-05-24',
  ),
  const MockReport(
    id: '5',
    type: 'Flash Flood',
    description: 'Flash flood warning in low-lying area near the river.',
    severity: 5,
    lat: 9.7720,
    lng: 123.9560,
    status: 'Critical',
    date: '2026-05-24',
  ),
  const MockReport(
    id: '6',
    type: 'Storm Surge',
    description: 'Strong waves along the coastal barangay.',
    severity: 3,
    lat: 9.7760,
    lng: 123.9720,
    status: 'Verified',
    date: '2026-05-21',
  ),
];

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _activeFilter = 'All';
  bool _isRefreshing = false;
  final int _pendingSyncCount = 2; // Mock offline queue count

  final _filters = ['All', 'Pending', 'Verified', 'Rejected', 'Critical'];

  List<MockReport> get _filteredReports {
    if (_activeFilter == 'All') return _mockReports;
    return _mockReports.where((r) => r.status == _activeFilter).toList();
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    // TODO: Fetch from Spring Boot API
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            _buildHeader(),

            // ── Sync banner ──
            if (_pendingSyncCount > 0) _buildSyncBanner(),

            // ── Filter chips ──
            _buildFilterChips(),

            const SizedBox(height: 4),

            // ── Report list ──
            Expanded(
              child: _filteredReports.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _filteredReports.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _buildReportCard(_filteredReports[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Reports',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.heading,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Track your submitted hazard reports',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          // Report count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Text(
              '${_mockReports.length}',
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sync banner ──
  Widget _buildSyncBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$_pendingSyncCount report${_pendingSyncCount > 1 ? 's' : ''} waiting to sync',
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.pendingText,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              // TODO: Trigger manual sync
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Syncing reports...',
                    style: TextStyle(fontFamily: 'Sora'),
                  ),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Sync Now',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips ──
  Widget _buildFilterChips() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final filter = _filters[i];
          final isActive = _activeFilter == filter;
          final count = filter == 'All'
              ? _mockReports.length
              : _mockReports.where((r) => r.status == filter).length;

          return GestureDetector(
            onTap: () => setState(() => _activeFilter = filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.subtle,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Report card ──
  Widget _buildReportCard(MockReport report) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReportDetailScreen(report: report)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: report.severityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                report.typeIcon,
                color: report.severityColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.type,
                          style: const TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.heading,
                          ),
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: report.statusBg,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          report.status,
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: report.statusText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: AppColors.label,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        report.date,
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 11,
                          color: AppColors.label,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Severity dots
                      ...List.generate(5, (i) {
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < report.severity
                                ? report.severityColor
                                : AppColors.border,
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.label,
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          const Text(
            'No reports found',
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No ${_activeFilter.toLowerCase()} reports yet',
            style: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
