import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Placeholder for the live map used on the Home tab (FR-SPN-01).
///
/// TODO: replace with a real map widget once the routing API from FRD §5.5
/// is chosen (flutter_map + OpenRouteService/Geoapify tiles is the
/// recommended free-tier starting point; google_maps_flutter if the team
/// moves to Google's paid tier later). Keeping this as its own widget means
/// that swap only touches this one file.
class BengMapPlaceholder extends StatelessWidget {
  const BengMapPlaceholder({super.key, this.height = 160});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _PlaceholderMapPainter(),
        child: const Align(
          alignment: Alignment.center,
          child: _YouAreHerePin(),
        ),
      ),
    );
  }
}

class _YouAreHerePin extends StatelessWidget {
  const _YouAreHerePin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'You',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.iconBlue,
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws a loose road/river pattern so the placeholder doesn't read as a
/// blank gray box. Purely decorative — has no relationship to real geography.
class _PlaceholderMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = AppColors.mapBackground;
    canvas.drawRect(Offset.zero & size, bg);

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(size.width * 0.05, size.height * 0.15),
      Offset(size.width * 0.4, size.height * 0.5),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.25, 0),
      Offset(size.width * 0.5, size.height),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.65, size.height * 0.05),
      Offset(size.width * 0.85, size.height * 0.7),
      road,
    );

    final river = Paint()
      ..color = const Color(0xFFCFE0F5)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.7),
      Offset(size.width * 0.6, size.height * 0.2),
      river,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
