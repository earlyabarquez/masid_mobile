import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_constants.dart';

class CloudinaryService {
  static final _cloudinary = CloudinaryPublic(
    AppConstants.cloudinaryCloudName,
    AppConstants.cloudinaryUploadPreset,
    cache: false,
  );

  /// Uploads image to Cloudinary and returns the secure URL.
  /// Throws on failure (no silent placeholder) so the caller can
  /// show a real error instead of saving a fake image.
  static Future<String> uploadImage(XFile file) async {
    try {
      CloudinaryResponse response;

      if (kIsWeb) {
        // Web: read as bytes
        final bytes = await file.readAsBytes();
        response = await _cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            bytes,
            identifier: 'hazard_${DateTime.now().millisecondsSinceEpoch}',
            folder: 'masid/hazards',
          ),
        );
      } else {
        // Mobile: use file path
        response = await _cloudinary.uploadFile(
          CloudinaryFile.fromFile(file.path, folder: 'masid/hazards'),
        );
      }

      debugPrint('Cloudinary URL: ${response.secureUrl}');
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      // Cloudinary-specific error (bad preset, cloud name, etc.)
      debugPrint('Cloudinary error: ${e.message} — ${e.request}');
      throw Exception('Photo upload failed: ${e.message}');
    } catch (e) {
      debugPrint('Cloudinary upload failed: $e');
      throw Exception('Photo upload failed. Check your connection.');
    }
  }
}
