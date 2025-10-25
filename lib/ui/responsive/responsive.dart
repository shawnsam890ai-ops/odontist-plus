import 'package:flutter/material.dart';

/// App-wide responsive helpers and breakpoints.
///
/// Usage:
///   final isPhone = context.isPhone;
///   final gap = context.gap; // 8/12/16 based on screen size
///   final size = context.scale(16); // scales from 0.85x..1.25x based on width
///   final cols = context.gridColumns(); // 1/2/3/4 based on breakpoints
///   ResponsiveBuilder(phone: ..., tablet: ..., desktop: ...)
class AppBreakpoints {
  static const double phone = 0;        // up to < 600
  static const double tablet = 600;     // 600 .. < 1024
  static const double desktop = 1024;   // 1024 .. < 1440
  static const double wide = 1440;      // 1440+
}

extension ResponsiveContext on BuildContext {
  MediaQueryData get _mq => MediaQuery.of(this);
  double get screenWidth => _mq.size.width;
  double get screenHeight => _mq.size.height;

  bool get isPhone => screenWidth < AppBreakpoints.tablet;
  bool get isTablet => screenWidth >= AppBreakpoints.tablet && screenWidth < AppBreakpoints.desktop;
  bool get isDesktop => screenWidth >= AppBreakpoints.desktop && screenWidth < AppBreakpoints.wide;
  bool get isWide => screenWidth >= AppBreakpoints.wide;

  /// Scale a base size according to screen width (clamped for stability).
  double scale(num base, {double min = 0.85, double max = 1.25}) {
    // Reference widths: 375 (phones), 800 (tablets), 1200 (desktop)
    final w = screenWidth.clamp(320.0, 1600.0);
    double f;
    if (w < 600) {
      f = w / 375.0; // phones
    } else if (w < 1024) {
      f = 1.1; // tablets slight up-scale
    } else if (w < 1440) {
      f = 1.15; // desktop
    } else {
      f = 1.2; // wide screens
    }
    f = f.clamp(min, max);
    return base.toDouble() * f;
  }

  /// Adaptive gaps/padding baseline.
  double get gap => isPhone ? 8 : (isTablet ? 12 : 16);
  double get gutter => isPhone ? 12 : (isTablet ? 16 : 24);

  /// Choose grid columns based on breakpoints.
  int gridColumns({int phone = 1, int tablet = 2, int desktop = 3, int wide = 4}) {
    if (isPhone) return phone;
    if (isTablet) return tablet;
    if (isDesktop) return desktop;
    return wide;
  }

  /// Constrain a content width and center it with outer padding.
  Widget responsiveCenter({required Widget child, double maxWidth = 1100, EdgeInsets? padding}) {
    final pad = padding ?? EdgeInsets.symmetric(horizontal: gutter, vertical: gap);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: pad,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Builder that switches widgets based on current breakpoint.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, BoxConstraints) phone;
  final Widget Function(BuildContext, BoxConstraints)? tablet;
  final Widget Function(BuildContext, BoxConstraints)? desktop;
  final Widget Function(BuildContext, BoxConstraints)? wide;
  const ResponsiveBuilder({super.key, required this.phone, this.tablet, this.desktop, this.wide});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      if (w >= AppBreakpoints.wide && wide != null) return wide!(ctx, c);
      if (w >= AppBreakpoints.desktop && desktop != null) return desktop!(ctx, c);
      if (w >= AppBreakpoints.tablet && tablet != null) return tablet!(ctx, c);
      return phone(ctx, c);
    });
  }
}
