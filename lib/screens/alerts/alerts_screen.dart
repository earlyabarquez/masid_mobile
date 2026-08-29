import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/alert_service.dart';
import '../map/map_screen.dart'; // reuse hazardIconFor for hazard alerts

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _alertService = AlertService();

  List<AppAlert> _alerts = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    // Auto-refresh every 15s so new alerts appear
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadAlerts(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAlerts({bool silent = false}) async {
    try {
      final alerts = await _alertService.getMyAlerts();
      // Newest first
      alerts.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (silent) return;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load alerts. Pull down to retry.';
      });
    }
  }

  int get _unreadCount => _alerts.where((a) => !a.isRead).length;

  Future<void> _markAsRead(AppAlert alert) async {
    if (alert.isRead) return;
    setState(() => alert.isRead = true); // optimistic
    try {
      await _alertService.markAsRead(alert.alertID);
    } catch (_) {
      // revert on failure
      if (mounted) setState(() => alert.isRead = false);
    }
  }

  Future<void> _markAllAsRead() async {
    final previous = _alerts.map((a) => a.isRead).toList();
    setState(() {
      for (final a in _alerts) {
        a.isRead = true;
      }
    });
    try {
      await _alertService.markAllAsRead();
    } catch (_) {
      // revert on failure
      if (mounted) {
        setState(() {
          for (int i = 0; i < _alerts.length; i++) {
            _alerts[i].isRead = previous[i];
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
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
        onRefresh: () => _loadAlerts(),
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Padding(
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
            ),
          ],
        ),
      );
    }
    if (_alerts.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadAlerts(),
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
            _buildEmptyState(),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadAlerts(),
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildAlertCard(_alerts[i]),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alerts',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _unreadCount > 0
                      ? '$_unreadCount unread notification${_unreadCount > 1 ? 's' : ''}'
                      : 'All caught up',
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (_unreadCount > 0)
            GestureDetector(
              onTap: _markAllAsRead,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.done_all_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Read all',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Known hazard type names (match the map's hazard-type selection)
  static const List<String> _hazardTypes = [
    'Flood',
    'Landslide',
    'Earthquake',
    'Fire',
    'Typhoon',
    'Storm Surge',
    'Drought',
    'Sinkhole',
    'Road Accident',
    'Structural Collapse',
    'Flash Flood',
    'Soil Erosion',
    'Power Outage',
    'Water Contamination',
    'Fallen Tree',
    'Animal Hazard',
    'Other',
  ];

  // Detect which hazard type an alert refers to, from its title/message
  String? _hazardTypeOf(AppAlert a) {
    final text = '${a.title} ${a.message}';
    // Check longer names first so "Flash Flood" wins over "Flood"
    final sorted = [..._hazardTypes]
      ..sort((x, y) => y.length.compareTo(x.length));
    for (final t in sorted) {
      if (text.contains(t)) return t;
    }
    return null;
  }

  // Icon + color per alert
  IconData _alertIcon(AppAlert a) {
    if (a.type == 'statusUpdate') {
      if (a.title.contains('Verified')) return Icons.check_circle_rounded;
      if (a.title.contains('Rejected')) return Icons.cancel_rounded;
      return Icons.info_rounded;
    }
    // hazard alert — use the same icon as the map's hazard-type selection
    final type = _hazardTypeOf(a);
    return type != null ? hazardIconFor(type) : Icons.warning_rounded;
  }

  Color _alertColor(AppAlert a) {
    if (a.type == 'statusUpdate') {
      if (a.title.contains('Verified')) return AppColors.success;
      if (a.title.contains('Rejected')) return AppColors.error;
      return AppColors.primary;
    }
    return AppColors.error; // hazard
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final then = DateTime.parse(iso);
      final diff = DateTime.now().difference(then);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hr ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays} days ago';
    } catch (_) {
      return '';
    }
  }

  // ── Alert card ──
  Widget _buildAlertCard(AppAlert alert) {
    final color = _alertColor(alert);
    final isHazard = alert.type == 'hazard';

    return GestureDetector(
      onTap: () => _markAsRead(alert),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !alert.isRead
                ? color.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar (unread)
              if (!alert.isRead)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    !alert.isRead ? 12 : 16,
                    14,
                    14,
                    14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_alertIcon(alert), color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    alert.title,
                                    style: TextStyle(
                                      fontFamily: 'Sora',
                                      fontSize: 13,
                                      fontWeight: !alert.isRead
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: AppColors.heading,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isHazard
                                        ? AppColors.error.withValues(
                                            alpha: 0.08,
                                          )
                                        : AppColors.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    isHazard ? 'HAZARD' : 'UPDATE',
                                    style: TextStyle(
                                      fontFamily: 'Sora',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: isHazard
                                          ? AppColors.error
                                          : AppColors.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alert.message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 12,
                                color: !alert.isRead
                                    ? AppColors.body
                                    : AppColors.muted,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: AppColors.label,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _timeAgo(alert.createdAt),
                                  style: const TextStyle(
                                    fontFamily: 'Sora',
                                    fontSize: 11,
                                    color: AppColors.label,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 56,
            color: AppColors.border,
          ),
          SizedBox(height: 14),
          Text(
            'No alerts yet',
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "You'll be notified of nearby hazards and report updates",
            textAlign: TextAlign.center,
            style: TextStyle(
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
