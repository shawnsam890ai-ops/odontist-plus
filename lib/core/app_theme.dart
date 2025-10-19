import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Default light theme (green) preserved for callers that still use AppTheme.light()
  static ThemeData light() => lightFrom(primary: const Color(0xFF28A745));

  static ThemeData lightFrom({required Color primary, Color? primaryContainer}) {
    // Palette
    const scaffoldBg = Color(0xFFF5F7FA);
    const textPrimary = Color(0xFF333333);
    const textSecondary = Color(0xFF757575);
    const dividerColor = Color(0xFFEEEEEE);

    final seed = primary;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light).copyWith(
        primary: primary,
        primaryContainer: primaryContainer ?? HSLColor.fromColor(primary).withLightness(0.9).toColor(),
        surface: Colors.white,
        onSurface: textPrimary,
        outlineVariant: dividerColor,
      ),
      scaffoldBackgroundColor: scaffoldBg,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineLarge: GoogleFonts.poppinsTextTheme(textTheme).headlineLarge?.copyWith(fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: textPrimary),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.05),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: const DialogTheme(backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      dividerTheme: const DividerThemeData(color: dividerColor, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: dividerColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: dividerColor)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primary)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primary,
        secondarySelectedColor: primary,
        labelStyle: const TextStyle(color: textSecondary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: const BorderSide(color: dividerColor),
        iconTheme: IconThemeData(color: primary),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: (primaryContainer ?? HSLColor.fromColor(primary).withLightness(0.9).toColor()).withOpacity(0.6),
        selectionHandleColor: primary,
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      listTileTheme: const ListTileThemeData(iconColor: textSecondary, textColor: textPrimary),
      popupMenuTheme: const PopupMenuThemeData(color: Colors.white, surfaceTintColor: Colors.white, textStyle: TextStyle(color: textPrimary)),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: const MenuStyle(backgroundColor: WidgetStatePropertyAll(Colors.white), surfaceTintColor: WidgetStatePropertyAll(Colors.white)),
        textStyle: const TextStyle(color: textPrimary),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: const TextStyle(color: textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: dividerColor)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        headerHeadlineStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        dayOverlayColor: const WidgetStatePropertyAll(Colors.transparent),
        todayBackgroundColor: WidgetStatePropertyAll(primary.withOpacity(0.1)),
        rangePickerBackgroundColor: Colors.white,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: Colors.white,
        hourMinuteTextColor: textPrimary,
        dialTextColor: textPrimary,
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primary)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: textPrimary, side: const BorderSide(color: dividerColor))),
      scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStateProperty.all(Colors.black.withOpacity(0.12))),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: primary.withOpacity(0.1)),
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
    return darkFrom(primary: const Color(0xFF28A745));
  }

  static ThemeData darkFrom({required Color primary}) {
    // Keep a complementary dark theme without strict palette enforcement
    final base = ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark));
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
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
