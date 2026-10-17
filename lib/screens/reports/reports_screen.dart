import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/report_service.dart';
import '../../services/offline_report_service.dart';
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

  // Reports saved on the phone while offline, waiting to be sent.
  List<PendingReport> _pending = [];
  bool _fromCache = false; // showing the saved copy (no connection)
  bool _syncing = false;
  int get _pendingSyncCount => _pending.length;

  final _filters = ['All', 'Pending', 'Verified', 'Rejected', 'Critical'];

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadPending();
    // Reload the "waiting to send" list whenever the offline queue changes.
    OfflineReportService.instance.pendingCount.addListener(_onQueueChanged);
    OfflineReportService.instance.failedCount.addListener(_onQueueChanged);
    // Auto-refresh every 30s so status changes (verify/reject) show up
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadReports(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    OfflineReportService.instance.pendingCount.removeListener(_onQueueChanged);
    OfflineReportService.instance.failedCount.removeListener(_onQueueChanged);
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
        _fromCache = _reportService.lastLoadFromCache;
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

  void _onQueueChanged() {
    _loadPending();
    // A report that just finished sending now exists on the server — refresh the list.
    _loadReports(silent: true);
  }

  Future<void> _loadPending() async {
    final list = await OfflineReportService.instance.loadPending();
    if (!mounted) return;
    setState(() => _pending = list);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Sora')),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // "Sync Now" / retry: send everything saved on the phone right away.
  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final offline = await OfflineReportService.instance.isOffline();
    var sent = 0;
    if (!offline) {
      sent = await OfflineReportService.instance.syncPending(retryFailed: true);
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    await _loadPending();
    if (sent > 0) _loadReports(silent: true);
    _toast(
      offline
          ? 'No connection. Saved reports will be sent automatically when you’re back online.'
          : sent > 0
          ? '$sent report${sent > 1 ? 's' : ''} sent.'
          : 'Could not send right now. We’ll keep trying.',
    );
  }

  Future<void> _confirmDiscard(PendingReport p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete saved report?'),
        content: const Text(
          'This report was never sent. Deleting it removes it from your phone for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await OfflineReportService.instance.discard(p.id);
      await _loadPending();
    }
  }

  // Saved-on-phone reports show under "All" and "Pending".
  List<PendingReport> get _visiblePending =>
      (_activeFilter == 'All' || _activeFilter == 'Pending') ? _pending : [];

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

            // ── Offline notice (showing the saved copy of your reports) ──
            if (_fromCache) _buildOfflineNotice(),

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
    if (_error != null && _pending.isEmpty) {
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
    if (_filteredReports.isEmpty && _visiblePending.isEmpty) {
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
        itemCount: _visiblePending.length + _filteredReports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final pending = _visiblePending;
          if (i < pending.length) return _buildPendingCard(pending[i]);
          return _buildReportCard(_filteredReports[i - pending.length]);
        },
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
              '${_reports.length + _pending.length}',
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
            onTap: _syncing ? null : _syncNow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                _syncing ? 'Sending…' : 'Sync Now',
                style: const TextStyle(
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

  // ── Offline notice ──
  Widget _buildOfflineNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You’re offline. Showing your saved reports.',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card for a report saved on the phone (not on the server yet) ──
  Widget _buildPendingCard(PendingReport p) {
    final color = p.failed ? AppColors.error : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              p.failed ? Icons.cloud_off_rounded : Icons.cloud_upload_outlined,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.hazardName,
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        p.failed ? 'Not sent' : 'Waiting to send',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  p.description.isEmpty ? 'No description' : p.description,
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
                      formatReportDate(p.createdAt),
                      style: const TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 11,
                        color: AppColors.label,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ...List.generate(5, (i) {
                      return Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < p.severity
                              ? severityColor(p.severity, 'Pending')
                              : AppColors.border,
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          if (p.failed) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: _syncing ? null : _syncNow,
              visualDensity: VisualDensity.compact,
              tooltip: 'Try again',
              icon: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            IconButton(
              onPressed: () => _confirmDiscard(p),
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete',
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppColors.error,
              ),
            ),
          ],
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
          final count =
              (filter == 'All'
                  ? _reports.length
                  : _reports.where((r) => r.statusName == filter).length) +
              ((filter == 'All' || filter == 'Pending') ? _pending.length : 0);

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
