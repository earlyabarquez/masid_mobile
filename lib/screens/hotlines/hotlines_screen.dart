import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../services/hotline_service.dart';

class HotlinesScreen extends StatefulWidget {
  const HotlinesScreen({super.key});

  @override
  State<HotlinesScreen> createState() => _HotlinesScreenState();
}

class _HotlinesScreenState extends State<HotlinesScreen> {
  final _service = HotlineService();
  List<Hotline> _hotlines = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.getHotlines();
      if (!mounted) return;
      setState(() {
        _hotlines = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load hotlines. Pull down to retry.';
      });
    }
  }

  // Open the phone dialer with the number pre-filled
  Future<void> _call(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the dialer')),
      );
    }
  }

  // Copy the number to the clipboard
  Future<void> _copy(String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Number copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Medical':
        return Icons.local_hospital_rounded;
      case 'Fire':
        return Icons.local_fire_department_rounded;
      case 'Police':
        return Icons.local_police_rounded;
      case 'Rescue':
        return Icons.health_and_safety_rounded;
      case 'Disaster':
        return Icons.warning_rounded;
      default:
        return Icons.phone_rounded;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Medical':
        return AppColors.error;
      case 'Fire':
        return const Color(0xFFEA580C);
      case 'Police':
        return AppColors.primary;
      case 'Rescue':
        return AppColors.success;
      case 'Disaster':
        return AppColors.warning;
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Emergency Hotlines'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Sora',
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_hotlines.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.phone_disabled_rounded,
                    size: 52,
                    color: AppColors.border,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No hotlines available',
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _hotlines.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildCard(_hotlines[i]),
      ),
    );
  }

  Widget _buildCard(Hotline h) {
    final color = _categoryColor(h.category);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Logo or category icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: h.imageUrl != null && h.imageUrl!.isNotEmpty
                ? Image.network(
                    h.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(_categoryIcon(h.category), color: color, size: 24),
                  )
                : Icon(_categoryIcon(h.category), color: color, size: 24),
          ),
          const SizedBox(width: 12),

          // Name + number + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.name,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  h.number,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (h.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    h.description,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Copy + Call buttons
          Row(
            children: [
              _actionBtn(
                icon: Icons.copy_rounded,
                color: AppColors.secondary,
                bg: AppColors.background,
                onTap: () => _copy(h.number),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Icons.call_rounded,
                color: Colors.white,
                bg: AppColors.success,
                onTap: () => _call(h.number),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
    );
  }
}
