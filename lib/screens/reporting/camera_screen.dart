import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Capture Hazard',
          style: TextStyle(fontFamily: 'Sora', fontSize: 16),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_rounded, size: 48, color: Colors.white54),
            SizedBox(height: 12),
            Text(
              'Camera — Step 4',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
