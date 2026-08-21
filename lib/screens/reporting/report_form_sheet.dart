import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../services/cloudinary_service.dart';
import '../../services/hazard_service.dart';
import '../../services/barangay_service.dart';
import '../../services/report_service.dart';

// Icon mapping for hazard names (fetched hazards use these icons by name)
const Map<String, IconData> hazardIcons = {
  'Flood': Icons.water_rounded,
  'Landslide': Icons.landscape_rounded,
  'Earthquake': Icons.vibration_rounded,
  'Fire': Icons.local_fire_department_rounded,
  'Typhoon': Icons.thunderstorm_rounded,
  'Storm Surge': Icons.waves_rounded,
  'Drought': Icons.wb_sunny_rounded,
  'Sinkhole': Icons.circle_outlined,
  'Road Accident': Icons.car_crash_rounded,
  'Structural Collapse': Icons.domain_disabled_rounded,
  'Flash Flood': Icons.flood_rounded,
  'Soil Erosion': Icons.terrain_rounded,
  'Power Outage': Icons.power_off_rounded,
  'Water Contamination': Icons.water_drop_rounded,
  'Fallen Tree': Icons.park_rounded,
  'Animal Hazard': Icons.pets_rounded,
  'Other': Icons.warning_rounded,
};

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

  final _hazardService = HazardService();
  final _barangayService = BarangayService();
  final _reportService = ReportService();

  List<HazardType> _hazards = [];
  List<Barangay> _barangays = [];

  int? _selectedHazardID;
  int? _selectedBrgyID;
  int _severity = 3;

  bool _loadingData = true; // fetching hazards + barangays
  bool _loading = false; // submitting
  String? _errorMessage;

  // Mock location (replace with real GPS later)
  final double _lat = AppConstants.defaultLat;
  final double _lng = AppConstants.defaultLng;

  bool get _isCritical => _severity == 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // Fetch hazard types + barangays from the backend
  Future<void> _loadData() async {
    try {
      final hazards = await _hazardService.getHazardTypes();
      final barangays = await _barangayService.getBarangays();
      if (!mounted) return;
      setState(() {
        _hazards = hazards;
        _barangays = barangays;
        _loadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingData = false;
        _errorMessage = 'Failed to load form data. Check your connection.';
      });
    }
  }

  Future<void> _handleSubmit() async {
    // Validation
    if (_selectedHazardID == null) {
      setState(() => _errorMessage = 'Please select a hazard type');
      return;
    }
    if (_selectedBrgyID == null) {
      setState(() => _errorMessage = 'Please select a barangay');
      return;
    }
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
      // 1. Upload photo to Cloudinary
      final imageUrl = await CloudinaryService.uploadImage(widget.photo);

      // 2. Submit the report to the backend
      await _reportService.submitReport(
        hazardID: _selectedHazardID!,
        brgyID: _selectedBrgyID!,
        severity: _severity,
        description: _descCtrl.text.trim(),
        latitude: _lat,
        longitude: _lng,
        imageURL: imageUrl,
      );

      if (!mounted) return;
      setState(() => _loading = false);

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
                      ? 'Critical report submitted'
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
        _errorMessage = 'Failed to submit: ${e.toString()}';
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
          _buildHeader(),

          // While fetching hazard types + barangays, show a loader
          if (_loadingData)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPhotoPreview(),
                      const SizedBox(height: 20),

                      // ── Hazard type ──
                      _buildSectionLabel('Hazard Type', required: true),
                      const SizedBox(height: 8),
                      _buildHazardTypeGrid(),
                      const SizedBox(height: 20),

                      // ── Barangay ──
                      _buildSectionLabel('Barangay', required: true),
                      const SizedBox(height: 8),
                      _buildBarangayDropdown(),
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

  // ── Header ──
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
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                widget.onCancel();
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

  // ── Hazard type grid (fetched from backend, stores hazardID) ──
  Widget _buildHazardTypeGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _hazards.map((hazard) {
        final isSelected = _selectedHazardID == hazard.hazardID;
        final icon = hazardIcons[hazard.hazardName] ?? Icons.warning_rounded;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedHazardID = hazard.hazardID;
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
                  icon,
                  size: 16,
                  color: isSelected ? AppColors.primary : AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  hazard.hazardName,
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

  // ── Barangay dropdown (fetched from backend, stores brgyID) ──
  Widget _buildBarangayDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedBrgyID,
          isExpanded: true,
          hint: const Text(
            'Select barangay',
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 13,
              color: AppColors.label,
            ),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: _barangays.map((b) {
            return DropdownMenuItem<int>(
              value: b.brgyID,
              child: Text(
                b.brgyName,
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 13,
                  color: AppColors.body,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() {
            _selectedBrgyID = val;
            _errorMessage = null;
          }),
        ),
      ),
    );
  }

  // ── Severity selector ──
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
