import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../widgets/pulsing_marker.dart';
import 'hazard_detail_sheet.dart';

// ── Mock hazard data (replace with API later) ──
class MockHazard {
  final String id;
  final String type;
  final String description;
  final int severity;
  final double lat;
  final double lng;
  final String status;
  final String date;
  final String reporter;
  final String? imageUrl;

  const MockHazard({
    required this.id,
    required this.type,
    required this.description,
    required this.severity,
    required this.lat,
    required this.lng,
    required this.status,
    required this.date,
    required this.reporter,
    this.imageUrl,
  });

  Color get color {
    if (status == 'Critical') return AppColors.error;
    switch (severity) {
      case 5:
        return const Color(0xFFDC2626);
      case 4:
        return const Color(0xFFEA580C);
      case 3:
        return const Color(0xFFF59E0B);
      case 2:
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF16A34A);
    }
  }

  IconData get icon {
    switch (type) {
      case 'Flood':
        return Icons.water_rounded;
      case 'Landslide':
        return Icons.landscape_rounded;
      case 'Fire':
        return Icons.local_fire_department_rounded;
      case 'Accident':
        return Icons.car_crash_rounded;
      case 'Storm Surge':
        return Icons.thunderstorm_rounded;
      case 'Earthquake':
        return Icons.vibration_rounded;
      default:
        return Icons.warning_rounded;
    }
  }
}

final List<MockHazard> _mockHazards = [
  const MockHazard(
    id: '1',
    type: 'Flood',
    description:
        'Knee-deep flooding along the main road near the public market. Water rising steadily.',
    severity: 4,
    lat: 9.7745,
    lng: 123.9640,
    status: 'Verified',
    date: '2026-05-23',
    reporter: 'Juan D.',
  ),
  const MockHazard(
    id: '2',
    type: 'Landslide',
    description:
        'Soil erosion and partial road blockage on the hillside barangay access road.',
    severity: 5,
    lat: 9.7790,
    lng: 123.9580,
    status: 'Critical',
    date: '2026-05-24',
    reporter: 'Maria S.',
  ),
  const MockHazard(
    id: '3',
    type: 'Accident',
    description:
        'Motorcycle collision at the intersection near the barangay hall.',
    severity: 3,
    lat: 9.7710,
    lng: 123.9700,
    status: 'Verified',
    date: '2026-05-22',
    reporter: 'Pedro C.',
  ),
  const MockHazard(
    id: '4',
    type: 'Fire',
    description:
        'Grass fire spreading near residential area. Smoke visible from the highway.',
    severity: 4,
    lat: 9.7680,
    lng: 123.9620,
    status: 'Pending',
    date: '2026-05-24',
    reporter: 'Ana R.',
  ),
  const MockHazard(
    id: '5',
    type: 'Storm Surge',
    description:
        'Strong waves reported along the coastal barangay. Fishermen advised not to go out.',
    severity: 3,
    lat: 9.7760,
    lng: 123.9720,
    status: 'Verified',
    date: '2026-05-21',
    reporter: 'Carlo M.',
  ),
  const MockHazard(
    id: '6',
    type: 'Flood',
    description: 'Flash flood warning in low-lying area near the river.',
    severity: 5,
    lat: 9.7720,
    lng: 123.9560,
    status: 'Critical',
    date: '2026-05-24',
    reporter: 'Elena T.',
  ),
];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _isSatellite = false;
  bool _showLegend = true;

  // User location (default to Balilihan center)
  final LatLng _userLocation = const LatLng(
    AppConstants.defaultLat,
    AppConstants.defaultLng,
  );

  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  void _onHazardTapped(MockHazard hazard) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HazardDetailSheet(hazard: hazard),
    );
  }

  void _centerOnUser() {
    _mapController.move(_userLocation, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: AppConstants.defaultZoom,
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate: _isSatellite ? _satelliteTileUrl : _osmTileUrl,
                userAgentPackageName: 'com.balilihan.masid',
              ),

              // Hazard markers
              MarkerLayer(
                markers: _mockHazards.map((h) {
                  return Marker(
                    point: LatLng(h.lat, h.lng),
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () => _onHazardTapped(h),
                      child: PulsingMarker(color: h.color, icon: h.icon),
                    ),
                  );
                }).toList(),
              ),

              // User location marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLocation,
                    width: 36,
                    height: 36,
                    child: const _UserLocationDot(),
                  ),
                ],
              ),
            ],
          ),

          // ── Top bar ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Search bar
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 14),
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppColors.label,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Search barangay or hazard...',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 13,
                            color: AppColors.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Satellite toggle
                GestureDetector(
                  onTap: () => setState(() => _isSatellite = !_isSatellite),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isSatellite
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isSatellite
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.satellite_alt_rounded,
                      size: 20,
                      color: _isSatellite ? Colors.white : AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── My location button ──
          Positioned(
            bottom: 24,
            right: 16,
            child: GestureDetector(
              onTap: _centerOnUser,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          // ── Legend ──
          if (_showLegend)
            Positioned(
              bottom: 24,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Severity',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.heading,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setState(() => _showLegend = false),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppColors.label,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _legendRow(const Color(0xFFDC2626), 'Critical / 5'),
                    _legendRow(const Color(0xFFEA580C), 'High / 4'),
                    _legendRow(const Color(0xFFF59E0B), 'Moderate / 3'),
                    _legendRow(const Color(0xFF2563EB), 'Low / 2'),
                    _legendRow(const Color(0xFF16A34A), 'Minimal / 1'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 11,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── User location blue dot ──
class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
