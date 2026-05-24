class AppConstants {
  AppConstants._();

  // ── API ──
  // Change this to your Spring Boot server URL
  static const String baseUrl = 'http://10.0.2.2:8080/api';
  // 10.0.2.2 = localhost from Android emulator
  // Use your machine's IP for physical device

  // ── Cloudinary ──
  static const String cloudinaryCloudName = 'YOUR_CLOUD_NAME';
  static const String cloudinaryUploadPreset = 'YOUR_UPLOAD_PRESET';

  // ── App Info ──
  static const String appName = 'M.A.S.I.D';
  static const String appFullName =
      'Municipal Assessment of Spatial Incident Density';
  static const String appTagline = 'See it. Report it. Prevent it.';

  // ── Map ──
  static const double defaultLat = 9.7741; // Balilihan, Bohol center
  static const double defaultLng = 123.9646;
  static const double defaultZoom = 13.0;
  static const double alertRadiusMeters = 300.0;

  // ── Storage Keys ──
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}
