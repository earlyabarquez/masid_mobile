import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'map_screen.dart';

class HazardDetailSheet extends StatelessWidget {
  final MockHazard hazard;

  const HazardDetailSheet({super.key, required this.hazard});

  @override
  Widget build(BuildContext context) {
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
                        color: hazard.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(hazard.icon, color: hazard.color, size: 22),
                    ),
                    const SizedBox(width: 14),

                    // Type + status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hazard.type,
                            style: const TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.heading,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Reported by ${hazard.reporter} · ${hazard.date}',
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
                    _StatusBadge(status: hazard.status),
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
                      '${hazard.severity}/5',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hazard.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: hazard.severity / 5,
                    minHeight: 6,
                    backgroundColor: AppColors.subtle,
                    valueColor: AlwaysStoppedAnimation<Color>(hazard.color),
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
                  hazard.description,
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
                        '${hazard.lat.toStringAsFixed(4)}, ${hazard.lng.toStringAsFixed(4)}',
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
