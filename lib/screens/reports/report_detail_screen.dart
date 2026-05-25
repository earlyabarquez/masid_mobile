import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'reports_screen.dart';

class ReportDetailScreen extends StatelessWidget {
  final MockReport report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
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
                          color: report.severityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          report.typeIcon,
                          color: report.severityColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.type,
                              style: const TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.heading,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Reported on ${report.date}',
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
                          color: report.statusBg,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          report.status,
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: report.statusText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

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
                child: report.imageUrl != null
                    ? Image.network(report.imageUrl!, fit: BoxFit.cover)
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
                          color: report.severityColor,
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        report.severityColor,
                      ),
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
                            color: report.severityColor,
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
                    report.description,
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
                          '${report.lat.toStringAsFixed(4)}, ${report.lng.toStringAsFixed(4)}',
                          style: const TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Admin rejection notes ──
            if (report.status == 'Rejected' && report.adminNotes != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.rejectedBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Rejection Reason',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.rejectedText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.adminNotes!,
                      style: const TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 13,
                        color: AppColors.rejectedText,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
