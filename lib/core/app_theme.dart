import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2DD4BF)),
      useMaterial3: true,
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.poppinsTextTheme(base.textTheme).headlineLarge?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: base.colorScheme.surface,
        foregroundColor: base.colorScheme.onSurface,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: base.colorScheme.onSurface),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      }),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2DD4BF), brightness: Brightness.dark),
      useMaterial3: true,
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: base.colorScheme.surface,
        foregroundColor: base.colorScheme.onSurface,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: base.colorScheme.onSurface),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      }),
    );
  }
}
