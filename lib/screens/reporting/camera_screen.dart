import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import 'report_form_sheet.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Auto-open camera on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
  }

  Future<void> _openCamera() async {
    setState(() => _loading = true);

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80, // Compress for bandwidth
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (photo != null) {
        // Open report form with captured photo
        _showReportForm(photo);
      } else {
        // User cancelled camera — go back
        Navigator.pop(context);
      }
    } catch (e) {
      // Camera not available (e.g., Chrome) — fallback to gallery
      if (!mounted) return;
      setState(() => _loading = false);
      _showFallbackOptions();
    }
  }

  Future<void> _openGallery() async {
    setState(() => _loading = true);

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (photo != null) {
      _showReportForm(photo);
    }
  }

  void _showReportForm(XFile photo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ReportFormSheet(
        photo: photo,
        onSubmitted: () {
          Navigator.pop(context); // Close sheet
          Navigator.pop(context, true); // Go back to home with result
        },
        onCancel: () {
          Navigator.pop(context); // Close sheet
          Navigator.pop(context); // Go back to home
        },
      ),
    );
  }

  void _showFallbackOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Camera not available',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a photo from your gallery instead',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 13,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close this sheet
                    _openGallery();
                  },
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text('Choose from Gallery'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close this sheet
                    Navigator.pop(context); // Go back to home
                  },
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _loading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Opening camera...',
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    size: 48,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _openCamera,
                    icon: const Icon(Icons.camera_alt_rounded, size: 20),
                    label: const Text('Open Camera'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _openGallery,
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      size: 20,
                      color: Colors.white70,
                    ),
                    label: const Text(
                      'Choose from Gallery',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
