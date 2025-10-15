import 'package:flutter/material.dart';

class DentalIdCard extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final String? age;
  final String? sex;
  final String? address;
  final String? phoneNumber;
  final String? emergencyContactNumber;
  final String? emergencyContactName;
  // Optional target width in logical pixels; card will keep ID-1 aspect ratio.
  final double? width;

  const DentalIdCard({
    super.key,
    this.photoUrl,
    required this.name,
    this.age,
    this.sex,
    this.address,
    this.phoneNumber,
    this.emergencyContactNumber,
    this.emergencyContactName,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    // ID-1: 85.6mm × 53.98mm → aspect ratio ≈ 1.586
    const aspect = 85.6 / 53.98;
    const baseWidth = 320.0; // design reference width
    const baseHeight = baseWidth / aspect;

    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : baseWidth;
      final targetW = (width ?? maxW).clamp(240.0, 360.0);
      final targetH = targetW / aspect;
      return Center(
        child: SizedBox(
          width: targetW,
          height: targetH,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: baseWidth,
              height: baseHeight,
              child: _buildCardBody(context),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCardBody(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: CustomPaint(
                  painter: _ToothPatternPainter(),
                ),
              ),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row with logo and photo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo and practice name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF20B2AA),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: const Icon(
                                    Icons.spa,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Flexible(
                                  child: Text(
                                    'ODONTIST PLUS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF20B2AA),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Staff photo
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF20B2AA), width: 2),
                          color: Colors.grey.shade200,
                        ),
                        child: ClipOval(
                          child: photoUrl != null && photoUrl!.isNotEmpty
                              ? Image.network(
                                  photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _defaultAvatar(),
                                )
                              : _defaultAvatar(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Staff name
                  Text(
                    name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C3E50),
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Staff details
                  if (age != null || sex != null) ...[
                    Row(
                      children: [
                        if (age != null) ...[
                          _detailLabel('AGE:'),
                          const SizedBox(width: 4),
                          _detailValue(age!),
                          const SizedBox(width: 12),
                        ],
                        if (sex != null) ...[
                          _detailLabel('SEX:'),
                          const SizedBox(width: 4),
                          _detailValue(sex!.toUpperCase()),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (address != null && address!.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailLabel('ADDRESS:'),
                        const SizedBox(width: 4),
                        Expanded(child: _detailValue(address!)),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (phoneNumber != null && phoneNumber!.isNotEmpty) ...[
                    Row(
                      children: [
                        _detailLabel('PHONE:'),
                        const SizedBox(width: 4),
                        Expanded(child: _detailValue(phoneNumber!)),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (emergencyContactNumber != null && emergencyContactNumber!.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailLabel('EMERGENCY:'),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _detailValue(
                            emergencyContactName != null && emergencyContactName!.isNotEmpty
                                ? '$emergencyContactNumber ($emergencyContactName)'
                                : emergencyContactNumber!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: Colors.grey.shade300,
      child: const Icon(
        Icons.person,
        size: 28,
        color: Colors.grey,
      ),
    );
  }

  Widget _detailLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: Color(0xFF20B2AA),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _detailValue(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: Color(0xFF2C3E50),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// Custom painter for subtle tooth pattern background
class _ToothPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF20B2AA)
      ..style = PaintingStyle.fill;

    const spacing = 35.0;
    const toothSize = 10.0;

    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        // Simple tooth shape (rounded rectangle)
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: toothSize, height: toothSize * 1.2),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
