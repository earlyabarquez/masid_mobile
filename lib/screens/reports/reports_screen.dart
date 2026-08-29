import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/report_service.dart';
import '../map/map_screen.dart'; // reuse severityColor + hazardIconFor helpers
import 'report_detail_screen.dart';

// ── Status → colors (used by both this screen and the detail screen) ──
Color statusColor(String status) {
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

Color statusBg(String status) {
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

Color statusText(String status) {
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

// Format an ISO date string to YYYY-MM-DD (falls back to the raw string)
String formatReportDate(String? iso) {
  if (iso == null) return '';
  try {
    final d = DateTime.parse(iso);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _reportService = ReportService();

  String _activeFilter = 'All';
  List<Report> _reports = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  // Offline queue count — 0 until offline mode (SQLite) is built later.
  final int _pendingSyncCount = 0;

  final _filters = ['All', 'Pending', 'Verified', 'Rejected', 'Critical'];

  @override
  void initState() {
    super.initState();
    _loadReports();
    // Auto-refresh every 30s so status changes (verify/reject) show up
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadReports(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReports({bool silent = false}) async {
    try {
      final reports = await _reportService.getMyReports();
      // Newest first (most recent report at the top)
      reports.sort(
        (a, b) => (b.reportDate ?? '').compareTo(a.reportDate ?? ''),
      );
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (silent) return; // don't disrupt on a background refresh failure
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load your reports. Pull down to retry.';
      });
    }
  }

  List<Report> get _filteredReports {
    if (_activeFilter == 'All') return _reports;
    return _reports.where((r) => r.statusName == _activeFilter).toList();
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

            // ── Sync banner (only when there are unsynced reports) ──
            if (_pendingSyncCount > 0) _buildSyncBanner(),

            // ── Filter chips ──
            _buildFilterChips(),

            const SizedBox(height: 4),

            // ── Report list ──
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () => _loadReports(),
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (_filteredReports.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadReports(),
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            _buildEmptyState(),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadReports(),
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _filteredReports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildReportCard(_filteredReports[i]),
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
              '${_reports.length}',
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

  // ── Sync banner (offline queue — wired for later SQLite offline mode) ──
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
              // TODO: Trigger manual sync once offline mode (SQLite) is built
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
              ? _reports.length
              : _reports.where((r) => r.statusName == filter).length;

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
  Widget _buildReportCard(Report report) {
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
                color: severityColor(
                  report.severity,
                  report.statusName,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hazardIconFor(report.hazardName),
                color: severityColor(report.severity, report.statusName),
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
                          report.hazardName,
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
                          color: statusBg(report.statusName),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          report.statusName,
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusText(report.statusName),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.description.isEmpty
                        ? 'No description'
                        : report.description,
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
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: AppColors.label,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatReportDate(report.reportDate),
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
                                ? severityColor(
                                    report.severity,
                                    report.statusName,
                                  )
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
          const Icon(Icons.inbox_rounded, size: 56, color: AppColors.border),
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
            _activeFilter == 'All'
                ? "You haven't submitted any reports yet"
                : 'No ${_activeFilter.toLowerCase()} reports',
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
