import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/patient_provider.dart';

/// A responsive patients overview card that scales with available width/height.
/// Shows a patient avatar image, total patient count, and optional subtitle.
class PatientOverviewCard extends StatefulWidget {
  final ImageProvider? avatar;
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final double minWidth;
  final double maxWidth;
  final double aspectRatio; // width / height target
  final Color? background;
  final Color? accentColor;

  const PatientOverviewCard({
    super.key,
    this.avatar,
    this.title = 'Patients',
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 12),
  this.minHeight = 110,
  this.minWidth = 110,
  this.maxWidth = 180,
  this.aspectRatio = 1.1,
    this.background,
    this.accentColor,
  });  @override
  State<PatientOverviewCard> createState() => _PatientOverviewCardState();
}

class _PatientOverviewCardState extends State<PatientOverviewCard> {
  ImageProvider? _effectiveAvatar;
  bool _assetExists = true;

  @override
  void initState() {
    super.initState();
    _checkAsset();
  }

  Future<void> _checkAsset() async {
    if (widget.avatar is AssetImage) {
      final assetImage = widget.avatar as AssetImage;
      try {
        await rootBundle.load(assetImage.assetName);
        if (mounted) {
          setState(() {
            _effectiveAvatar = widget.avatar;
            _assetExists = true;
          });
        }
      } catch (e) {
        // Asset doesn't exist, use fallback (Icon wrapped as image)
        if (mounted) {
          setState(() {
            _assetExists = false;
          });
        }
      }
    } else {
      _effectiveAvatar = widget.avatar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<PatientProvider>();
    final total = patientProvider.patients.length;
    final cs = Theme.of(context).colorScheme;
    final bg = widget.background ?? cs.surface;
    final accent = widget.accentColor ?? cs.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine target width based on incoming constraints but clamp.
        final availableW = constraints.maxWidth.isFinite ? constraints.maxWidth : widget.maxWidth;
        final targetW = availableW.clamp(widget.minWidth, widget.maxWidth);
        final targetH = (targetW / widget.aspectRatio).clamp(widget.minHeight, 400);
        return ConstrainedBox(
          constraints: BoxConstraints(minWidth: widget.minWidth, maxWidth: targetW, minHeight: widget.minHeight),
          child: _CardBody(
            width: targetW.toDouble(),
            height: targetH.toDouble(),
            avatar: _effectiveAvatar,
            useIconFallback: !_assetExists && widget.avatar is AssetImage,
            bg: bg,
            accent: accent,
            padding: widget.padding,
            total: total,
            title: widget.title,
            subtitle: widget.subtitle,
          ),
        );
      },
    );
  }
}

class _CardBody extends StatelessWidget {
  final double width;
  final double height;
  final ImageProvider? avatar;
  final bool useIconFallback;
  final Color bg;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final int total;
  final String title;
  final String? subtitle;

  const _CardBody({
    required this.width,
    required this.height,
    this.avatar,
    this.useIconFallback = false,
    required this.bg,
    required this.accent,
    required this.padding,
    required this.total,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [bg, bg.withOpacity(.95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: accent.withOpacity(.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: height * 0.62,
              height: height * 0.62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: useIconFallback || avatar == null
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withOpacity(.1),
                      ),
                      child: Icon(Icons.person, color: accent, size: height * 0.28),
                    )
                  : ClipOval(
                      child: Image(
                        image: avatar!,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: height * 0.10,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      total.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                        fontSize: height * 0.24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
