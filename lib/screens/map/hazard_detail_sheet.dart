import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/report_service.dart';
import 'map_screen.dart'; // for severityColor + hazardIconFor helpers

class HazardDetailSheet extends StatelessWidget {
  final Report report;

  const HazardDetailSheet({super.key, required this.report});

  String get _dateLabel {
    if (report.reportDate == null) return '';
    try {
      final d = DateTime.parse(report.reportDate!);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return report.reportDate!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = severityColor(report.severity, report.statusName);
    final icon = hazardIconFor(report.hazardName);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ──
                Row(
                  children: [
                    // Type icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),

                    // Type + reporter
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.hazardName,
                            style: const TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.heading,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Reported by ${report.reporterName ?? "—"} · $_dateLabel',
                            style: const TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status badge
                    _StatusBadge(status: report.statusName),
                  ],
                ),

                const SizedBox(height: 18),

                // ── Severity bar ──
                Row(
                  children: [
                    const Text(
                      'Severity',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${report.severity}/5',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: report.severity / 5,
                    minHeight: 6,
                    backgroundColor: AppColors.subtle,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),

                const SizedBox(height: 18),

                // ── Description ──
                const Text(
                  'Description',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  report.description.isEmpty
                      ? 'No description provided.'
                      : report.description,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 13,
                    color: AppColors.body,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 18),

                // ── Location info ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.body,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    switch (status) {
      case 'Critical':
        bg = AppColors.criticalBg;
        text = AppColors.criticalText;
        break;
      case 'Verified':
        bg = AppColors.verifiedBg;
        text = AppColors.verifiedText;
        break;
      case 'Rejected':
        bg = AppColors.rejectedBg;
        text = AppColors.rejectedText;
        break;
      default:
        bg = AppColors.pendingBg;
        text = AppColors.pendingText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontFamily: 'Sora',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}
