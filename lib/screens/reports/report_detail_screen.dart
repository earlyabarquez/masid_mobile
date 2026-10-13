import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/report_service.dart';
import '../map/map_screen.dart'; // severityColor + hazardIconFor
import 'reports_screen.dart'; // statusBg + statusText + formatReportDate

/// Icon + copy shown in the review status card for each report status.
class _StatusInfo {
  final IconData icon;
  final String title;
  final String message;
  const _StatusInfo(this.icon, this.title, this.message);
}

_StatusInfo _statusInfo(String status) {
  switch (status) {
    case 'Verified':
      return const _StatusInfo(
        Icons.verified_rounded,
        'Report Verified',
        'The MDRRMO has verified your report. It is now visible on the risk map.',
      );
    case 'Rejected':
      return const _StatusInfo(
        Icons.cancel_rounded,
        'Report Rejected',
        'Your report was reviewed but could not be accepted.',
      );
    case 'Resolved':
      return const _StatusInfo(
        Icons.task_alt_rounded,
        'Hazard Resolved',
        'This hazard has been marked as resolved by the MDRRMO.',
      );
    default:
      return const _StatusInfo(
        Icons.schedule_rounded,
        'Awaiting Review',
        'Your report was received and is waiting to be reviewed by the MDRRMO.',
      );
  }
}

String _remarksTitle(String status) {
  switch (status) {
    case 'Rejected':
      return 'Reason for Rejection';
    case 'Resolved':
      return 'Resolution Notes';
    default:
      return 'Admin Remarks';
  }
}

class ReportDetailScreen extends StatelessWidget {
  final Report report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final sevColor = severityColor(report.severity, report.statusName);

    final status = report.statusName;
    final info = _statusInfo(status);
    final accent = statusText(status);
    final notes = (report.adminNotes ?? '').trim();
    final hasNotes = notes.isNotEmpty;
    // Pending reports only show the remarks card if an admin already left a note.
    final showRemarks = status != 'Pending' || hasNotes;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Report Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status + Type header ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: sevColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          hazardIconFor(report.hazardName),
                          color: sevColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.hazardName,
                              style: const TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.heading,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Reported on ${formatReportDate(report.reportDate)}',
                              style: const TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg(status),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Review status ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusBg(status),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(info.icon, size: 22, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.title,
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          info.message,
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 12,
                            height: 1.55,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Admin remarks ──
            if (showRemarks) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _remarksTitle(status),
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasNotes ? notes : 'No remarks were added by the admin.',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 13,
                        height: 1.6,
                        fontStyle: hasNotes
                            ? FontStyle.normal
                            : FontStyle.italic,
                        color: hasNotes ? AppColors.body : AppColors.label,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Photo ──
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.subtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: report.imageURL != null
                    ? Image.network(report.imageURL!, fit: BoxFit.cover)
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 40,
                              color: AppColors.label,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Photo evidence',
                              style: TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 12,
                                color: AppColors.label,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Severity ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Severity Level',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${report.severity}/5',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: sevColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: report.severity / 5,
                      minHeight: 8,
                      backgroundColor: AppColors.subtle,
                      valueColor: AlwaysStoppedAnimation<Color>(sevColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final labels = [
                        'Minimal',
                        'Low',
                        'Moderate',
                        'High',
                        'Critical',
                      ];
                      return Expanded(
                        child: Text(
                          i == report.severity - 1 ? labels[i] : '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: sevColor,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Description ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.description.isEmpty
                        ? 'No description provided.'
                        : report.description,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 13,
                      color: AppColors.body,
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Location ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GPS Location',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        if (report.address != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            report.address!,
                            style: const TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 11,
                              color: AppColors.label,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
