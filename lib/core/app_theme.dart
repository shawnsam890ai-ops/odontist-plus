import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    // Palette
    const scaffoldBg = Color(0xFFF5F7FA);
    const primaryGreen = Color(0xFF28A745);
    const textPrimary = Color(0xFF333333);
    const textSecondary = Color(0xFF757575);
    const dividerColor = Color(0xFFEEEEEE);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen, brightness: Brightness.light).copyWith(
        primary: primaryGreen,
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
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: primaryGreen)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primaryGreen,
        secondarySelectedColor: primaryGreen,
        labelStyle: const TextStyle(color: textSecondary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: const BorderSide(color: dividerColor),
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
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        headerHeadlineStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        dayOverlayColor: WidgetStatePropertyAll(Colors.transparent),
        todayBackgroundColor: WidgetStatePropertyAll(Color(0x1A28A745)),
        rangePickerBackgroundColor: Colors.white,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: Colors.white,
        hourMinuteTextColor: textPrimary,
        dialTextColor: textPrimary,
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primaryGreen)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: textPrimary, side: const BorderSide(color: dividerColor))),
      scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStateProperty.all(Colors.black.withOpacity(0.12))),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: Color(0x1A28A745)),
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
    // Keep a complementary dark theme without strict palette enforcement
    final base = ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF28A745), brightness: Brightness.dark));
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
