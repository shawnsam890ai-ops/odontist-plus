import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Minimal brand logo: gradient circular badge with OP monogram.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withOpacity(0.9),
            cs.primaryContainer.withOpacity(0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(color: cs.primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Center(
        child: Text(
          'OP',
          style: GoogleFonts.cinzel(
            fontWeight: FontWeight.w800,
            color: cs.onPrimary,
            fontSize: size * 0.45,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
