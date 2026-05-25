import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../reports/reports_screen.dart';
import '../reports/report_detail_screen.dart';

// ── Alert types ──
enum AlertType { hazard, statusUpdate }

class MockAlert {
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final String time;
  final bool isRead;
  final double? distance;
  final String? direction;
  final String? hazardType;
  final String? reportStatus;
  final MockReport? linkedReport;

  const MockAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    this.isRead = false,
    this.distance,
    this.direction,
    this.hazardType,
    this.reportStatus,
    this.linkedReport,
  });

  IconData get icon {
    if (type == AlertType.statusUpdate) {
      switch (reportStatus) {
        case 'Verified':
          return Icons.check_circle_rounded;
        case 'Rejected':
          return Icons.cancel_rounded;
        default:
          return Icons.info_rounded;
      }
    }
    switch (hazardType) {
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
      case 'Flash Flood':
        return Icons.flood_rounded;
      default:
        return Icons.warning_rounded;
    }
  }

  Color get iconColor {
    if (type == AlertType.statusUpdate) {
      switch (reportStatus) {
        case 'Verified':
          return AppColors.success;
        case 'Rejected':
          return AppColors.error;
        default:
          return AppColors.primary;
      }
    }
    return AppColors.error;
  }

  Color get iconBg {
    return iconColor.withValues(alpha: 0.1);
  }
}

// ── Mock data ──
final List<MockAlert> _initialAlerts = [
  const MockAlert(
    id: '1',
    type: AlertType.hazard,
    title: 'Flood Nearby',
    message:
        'A flood has been reported near your current location. Stay alert and avoid low-lying areas.',
    time: '2 min ago',
    isRead: false,
    distance: 120,
    direction: 'NW',
    hazardType: 'Flood',
  ),
  const MockAlert(
    id: '2',
    type: AlertType.statusUpdate,
    title: 'Report Verified',
    message:
        'Your flood report at Poblacion has been verified by the admin and is now visible on the risk map.',
    time: '15 min ago',
    isRead: false,
    reportStatus: 'Verified',
  ),
  const MockAlert(
    id: '3',
    type: AlertType.hazard,
    title: 'Landslide Alert',
    message:
        'A critical landslide has been reported. Avoid the hillside barangay access road.',
    time: '1 hr ago',
    isRead: false,
    distance: 280,
    direction: 'SE',
    hazardType: 'Landslide',
  ),
  const MockAlert(
    id: '4',
    type: AlertType.statusUpdate,
    title: 'Report Rejected',
    message:
        'Your road accident report was rejected. Reason: Duplicate report already submitted by another responder.',
    time: '3 hrs ago',
    isRead: true,
    reportStatus: 'Rejected',
  ),
  const MockAlert(
    id: '5',
    type: AlertType.hazard,
    title: 'Fire Reported',
    message:
        'A grass fire has been reported near the residential area. Smoke may be visible from your location.',
    time: '5 hrs ago',
    isRead: true,
    distance: 450,
    direction: 'SW',
    hazardType: 'Fire',
  ),
  const MockAlert(
    id: '6',
    type: AlertType.statusUpdate,
    title: 'Report Verified',
    message:
        'Your storm surge report along the coastal barangay has been verified.',
    time: 'Yesterday',
    isRead: true,
    reportStatus: 'Verified',
  ),
];

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late List<MockAlert> _alerts;

  @override
  void initState() {
    super.initState();
    _alerts = List.from(_initialAlerts);
  }

  int get _unreadCount => _alerts.where((a) => !a.isRead).length;

  void _markAsRead(String id) {
    setState(() {
      final index = _alerts.indexWhere((a) => a.id == id);
      if (index != -1) {
        final alert = _alerts[index];
        _alerts[index] = MockAlert(
          id: alert.id,
          type: alert.type,
          title: alert.title,
          message: alert.message,
          time: alert.time,
          isRead: true,
          distance: alert.distance,
          direction: alert.direction,
          hazardType: alert.hazardType,
          reportStatus: alert.reportStatus,
          linkedReport: alert.linkedReport,
        );
      }
    });
  }

  void _markAllAsRead() {
    setState(() {
      _alerts = _alerts
          .map(
            (a) => MockAlert(
              id: a.id,
              type: a.type,
              title: a.title,
              message: a.message,
              time: a.time,
              isRead: true,
              distance: a.distance,
              direction: a.direction,
              hazardType: a.hazardType,
              reportStatus: a.reportStatus,
              linkedReport: a.linkedReport,
            ),
          )
          .toList();
    });
  }

  void _onAlertTapped(MockAlert alert) {
    _markAsRead(alert.id);

    if (alert.type == AlertType.hazard) {
      // TODO: Navigate to Map centered on the hazard location
      // For now, switch to Map tab via callback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Navigating to ${alert.hazardType} location on map...',
            style: const TextStyle(fontFamily: 'Sora'),
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.primary,
        ),
      );
    } else if (alert.type == AlertType.statusUpdate) {
      // Navigate to report detail if linked report exists
      // TODO: Link to actual report from API
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opening ${alert.reportStatus?.toLowerCase()} report details...',
            style: const TextStyle(fontFamily: 'Sora'),
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: alert.reportStatus == 'Verified'
              ? AppColors.success
              : AppColors.error,
        ),
      );
    }
  }

  Future<void> _onRefresh() async {
    // TODO: Fetch from API
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(),

            // ── Alert list ──
            Expanded(
              child: _alerts.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _alerts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _buildAlertCard(_alerts[i]),
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

  // ── Alert card ──
  Widget _buildAlertCard(MockAlert alert) {
    return GestureDetector(
      onTap: () => _onAlertTapped(alert),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !alert.isRead
                ? alert.iconColor.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Left accent bar (unread) ──
              if (!alert.isRead)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: alert.iconColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                  ),
                ),

              // ── Content ──
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
                          color: alert.iconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          alert.icon,
                          color: alert.iconColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + type badge
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
                                    color: alert.type == AlertType.hazard
                                        ? AppColors.error.withValues(
                                            alpha: 0.08,
                                          )
                                        : AppColors.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    alert.type == AlertType.hazard
                                        ? 'HAZARD'
                                        : 'UPDATE',
                                    style: TextStyle(
                                      fontFamily: 'Sora',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: alert.type == AlertType.hazard
                                          ? AppColors.error
                                          : AppColors.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            // Message
                            Text(
                              alert.message,
                              maxLines: 2,
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

                            // Bottom row: time + distance
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: AppColors.label,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  alert.time,
                                  style: const TextStyle(
                                    fontFamily: 'Sora',
                                    fontSize: 11,
                                    color: AppColors.label,
                                  ),
                                ),
                                if (alert.distance != null) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: const BoxDecoration(
                                      color: AppColors.label,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.near_me_rounded,
                                    size: 12,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '~${alert.distance!.toInt()}m ${alert.direction ?? ''}',
                                    style: const TextStyle(
                                      fontFamily: 'Sora',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
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
            'You\'ll be notified of nearby hazards',
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
