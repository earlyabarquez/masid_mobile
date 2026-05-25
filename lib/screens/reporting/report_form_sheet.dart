import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../services/cloudinary_service.dart';

// 19 Bohol-specific hazard types
const List<Map<String, dynamic>> hazardTypes = [
  {'name': 'Flood', 'icon': Icons.water_rounded},
  {'name': 'Landslide', 'icon': Icons.landscape_rounded},
  {'name': 'Earthquake', 'icon': Icons.vibration_rounded},
  {'name': 'Fire', 'icon': Icons.local_fire_department_rounded},
  {'name': 'Typhoon', 'icon': Icons.thunderstorm_rounded},
  {'name': 'Storm Surge', 'icon': Icons.waves_rounded},
  {'name': 'Volcanic Activity', 'icon': Icons.volcano_rounded},
  {'name': 'Drought', 'icon': Icons.wb_sunny_rounded},
  {'name': 'Sinkhole', 'icon': Icons.circle_outlined},
  {'name': 'Road Accident', 'icon': Icons.car_crash_rounded},
  {'name': 'Structural Collapse', 'icon': Icons.domain_disabled_rounded},
  {'name': 'Coastal Erosion', 'icon': Icons.water_damage_rounded},
  {'name': 'Flash Flood', 'icon': Icons.flood_rounded},
  {'name': 'Soil Erosion', 'icon': Icons.terrain_rounded},
  {'name': 'Power Outage', 'icon': Icons.power_off_rounded},
  {'name': 'Water Contamination', 'icon': Icons.water_drop_rounded},
  {'name': 'Fallen Tree', 'icon': Icons.park_rounded},
  {'name': 'Animal Hazard', 'icon': Icons.pets_rounded},
  {'name': 'Other', 'icon': Icons.warning_rounded},
];

class ReportFormSheet extends StatefulWidget {
  final XFile photo;
  final VoidCallback onSubmitted;
  final VoidCallback onCancel;

  const ReportFormSheet({
    super.key,
    required this.photo,
    required this.onSubmitted,
    required this.onCancel,
  });

  @override
  State<ReportFormSheet> createState() => _ReportFormSheetState();
}

class _ReportFormSheetState extends State<ReportFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();

  String? _selectedType;
  int _severity = 3;
  bool _loading = false;
  String? _errorMessage;

  // Mock location (replace with real GPS later)
  final double _lat = AppConstants.defaultLat;
  final double _lng = AppConstants.defaultLng;

  bool get _isCritical => _severity == 5;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    // Validate type selection
    if (_selectedType == null) {
      setState(() => _errorMessage = 'Please select a hazard type');
      return;
    }

    // Validate description (required for severity 1-4)
    if (!_isCritical && _descCtrl.text.trim().isEmpty) {
      setState(
        () =>
            _errorMessage = 'Description is required for non-critical reports',
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Upload photo to Cloudinary
      final imageUrl = await CloudinaryService.uploadImage(widget.photo);

      // Build report payload
      final payload = {
        'hazardType': _selectedType,
        'severity': _severity,
        'description': _descCtrl.text.trim(),
        'latitude': _lat,
        'longitude': _lng,
        'imageUrl': imageUrl,
        'status': _isCritical ? 'Critical' : 'Pending',
        // TODO: Add reporter info from auth
      };

      // TODO: Send to Spring Boot API
      // final response = await ApiService.post('/hazards', payload);
      await Future.delayed(const Duration(seconds: 1)); // Mock delay

      debugPrint('Report payload: $payload');

      if (!mounted) return;
      setState(() => _loading = false);

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isCritical
                      ? 'Critical report auto-posted to map'
                      : 'Report submitted for verification',
                  style: const TextStyle(fontFamily: 'Sora'),
                ),
              ),
            ],
          ),
          backgroundColor: _isCritical ? AppColors.error : AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );

      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to submit. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Header ──
          _buildHeader(),

          // ── Form ──
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Photo preview ──
                    _buildPhotoPreview(),
                    const SizedBox(height: 20),

                    // ── Hazard type ──
                    _buildSectionLabel('Hazard Type', required: true),
                    const SizedBox(height: 8),
                    _buildHazardTypeGrid(),
                    const SizedBox(height: 20),

                    // ── Severity ──
                    _buildSectionLabel('Severity Level', required: true),
                    const SizedBox(height: 8),
                    _buildSeveritySelector(),
                    const SizedBox(height: 20),

                    // ── Description ──
                    _buildSectionLabel(
                      'Description',
                      required: !_isCritical,
                      optional: _isCritical,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: _isCritical
                            ? 'Add details if possible (optional)'
                            : 'Describe the hazard situation...',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Location ──
                    _buildSectionLabel('Location', required: false),
                    const SizedBox(height: 8),
                    _buildLocationCard(),
                    const SizedBox(height: 24),

                    // ── Error message ──
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.rejectedBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 12,
                                  color: AppColors.rejectedText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Submit button ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCritical
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isCritical
                                        ? Icons.warning_rounded
                                        : Icons.send_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isCritical
                                        ? 'Submit Critical Report'
                                        : 'Submit Report',
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header with drag handle + close ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
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
              Icons.edit_note_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Hazard Report',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading,
                  ),
                ),
                Text(
                  'Fill in the details below',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : widget.onCancel,
            icon: const Icon(Icons.close_rounded, color: AppColors.label),
          ),
        ],
      ),
    );
  }

  // ── Photo preview ──
  Widget _buildPhotoPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: 180,
            child: kIsWeb
                ? Image.network(widget.photo.path, fit: BoxFit.cover)
                : Image.file(File(widget.photo.path), fit: BoxFit.cover),
          ),
          // Retake button
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                widget.onCancel(); // Go back to retake
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Retake',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hazard type grid ──
  Widget _buildHazardTypeGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: hazardTypes.map((type) {
        final isSelected = _selectedType == type['name'];
        return GestureDetector(
          onTap: () => setState(() {
            _selectedType = type['name'];
            _errorMessage = null;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : AppColors.surface,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type['icon'] as IconData,
                  size: 16,
                  color: isSelected ? AppColors.primary : AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  type['name'] as String,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Severity selector (tappable circles) ──
  Widget _buildSeveritySelector() {
    final labels = ['Minimal', 'Low', 'Moderate', 'High', 'Critical'];
    final colors = [
      const Color(0xFF16A34A),
      const Color(0xFF2563EB),
      const Color(0xFFF59E0B),
      const Color(0xFFEA580C),
      const Color(0xFFDC2626),
    ];

    return Column(
      children: [
        Row(
          children: List.generate(5, (i) {
            final level = i + 1;
            final isSelected = _severity == level;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _severity = level),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors[i]
                            : colors[i].withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? colors[i]
                              : colors[i].withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$level',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : colors[i],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? colors[i] : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),

        // Critical warning banner
        if (_isCritical) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Critical reports are auto-posted to the map without admin verification.',
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.rejectedText,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Location card ──
  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
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
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GPS Coordinates',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.verifiedBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 12,
                  color: AppColors.success,
                ),
                SizedBox(width: 4),
                Text(
                  'Auto',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.verifiedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ──
  Widget _buildSectionLabel(
    String text, {
    bool required = false,
    bool optional = false,
  }) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.body,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
        if (optional)
          const Text(
            '  (optional)',
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 11,
              color: AppColors.label,
            ),
          ),
      ],
    );
  }
}
