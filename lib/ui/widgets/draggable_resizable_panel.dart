import 'package:flutter/material.dart';

/// A lightweight draggable + resizable panel used for dashboard customization.
///
/// Features:
/// - Long press to start dragging (or set [enableLongPress] false for immediate drag)
/// - Bottom-right resize handle (drag to resize)
/// - Clamps movement & size within given [boundsSize]
/// - Notifies parent through [onUpdate] with new Rect whenever moved or resized.
/// - Optional overlay decoration & header.
class DraggableResizablePanel extends StatefulWidget {
  final Rect rect;
  final Widget child;
  final ValueChanged<Rect> onUpdate;
  final Size boundsSize;
  final double minWidth;
  final double minHeight;
  final bool enableLongPress;
  final String? label;
  final Color? borderColor;
  final double elevation;
  final bool showShadow;
  final bool active; // highlight when selected/customizing
  final bool liveResize; // if false: show ghost outline while resizing; commit on release
  final bool centerDragOnly; // if true: only center region initiates move
  final bool interactive; // if false: static display (no drag / resize UI)

  const DraggableResizablePanel({
    super.key,
    required this.rect,
    required this.child,
    required this.onUpdate,
    required this.boundsSize,
    this.minWidth = 180,
    this.minHeight = 140,
    this.enableLongPress = true,
    this.label,
    this.borderColor,
    this.elevation = 4,
    this.showShadow = true,
    this.active = true,
    this.liveResize = true,
    this.centerDragOnly = false,
    this.interactive = true,
  });

  @override
  State<DraggableResizablePanel> createState() => _DraggableResizablePanelState();
}

class _DraggableResizablePanelState extends State<DraggableResizablePanel> {
  late Rect _rect;
  bool _dragging = false;
  bool _resizing = false;
  Rect? _resizeGhost; // ghost rect when liveResize = false

  @override
  void initState() {
    super.initState();
    _rect = widget.rect;
  }

  void _emit() => widget.onUpdate(_rect);

  void _startDrag(Offset globalPosition, Offset localPos) {
    setState(() => _dragging = true);
  }

  void _updateDrag(DragUpdateDetails d) {
    if (!_dragging) return;
    final dx = d.delta.dx;
    final dy = d.delta.dy;
    final newRect = _rect.shift(Offset(dx, dy));
    _rect = _clampRect(newRect);
    _emit();
    setState(() {});
  }

  void _endDrag() => setState(() => _dragging = false);

  void _startResize() => setState(() => _resizing = true);

  void _updateResize(DragUpdateDetails d) {
    if (!_resizing) return;
    final base = widget.liveResize ? _rect : (_resizeGhost ?? _rect);
    final newW = (base.width + d.delta.dx).clamp(widget.minWidth, widget.boundsSize.width - base.left);
    final newH = (base.height + d.delta.dy).clamp(widget.minHeight, widget.boundsSize.height - base.top);
    final updated = Rect.fromLTWH(base.left, base.top, newW, newH);
    if (widget.liveResize) {
      _rect = updated;
      _emit();
    } else {
      _resizeGhost = updated;
    }
    setState(() {});
  }

  void _endResize() {
    if (!widget.liveResize && _resizeGhost != null) {
      _rect = _resizeGhost!;
      _emit();
    }
    setState(() {
      _resizing = false;
      _resizeGhost = null;
    });
  }

  Rect _clampRect(Rect r) {
  final maxLeft = (widget.boundsSize.width - r.width).clamp(0.0, double.infinity);
  final maxTop = (widget.boundsSize.height - r.height).clamp(0.0, double.infinity);
  final left = r.left.clamp(0.0, maxLeft);
  final top = r.top.clamp(0.0, maxTop);
  return Rect.fromLTWH(left, top, r.width, r.height);
  }

  @override
  void didUpdateWidget(covariant DraggableResizablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rect != widget.rect) {
      _rect = widget.rect; // external rect override
    }
  }

  @override
  Widget build(BuildContext context) {
    // Remove green outline completely - use transparent border
    final borderClr = widget.active && widget.interactive ? 
      Theme.of(context).colorScheme.primary.withOpacity(.3) : 
      Colors.transparent;

    final currentRect = _resizeGhost ?? _rect;
    final panel = Material(
      elevation: widget.showShadow ? widget.elevation : 0,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderClr, width: widget.active && widget.interactive ? 1.0 : 0),
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (widget.label != null)
              Positioned(
                left: 8,
                top: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(widget.label!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            // Resize handle
            if (widget.interactive)
              Positioned(
              right: 4,
              bottom: 4,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => _startResize(),
                onPanUpdate: _updateResize,
                onPanEnd: (_) => _endResize(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: (_resizing ? borderClr : borderClr.withOpacity(.15)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.drag_handle, size: 14),
                ),
              ),
            )
          ],
        ),
      ),
    );

    if (!widget.interactive) {
      return Positioned(
        left: currentRect.left,
        top: currentRect.top,
        width: currentRect.width,
        height: currentRect.height,
        child: panel,
      );
    }

    Widget moveChild = panel;
    if (widget.centerDragOnly) {
      // Add an overlay center handle (40% of width & height area)
      moveChild = Stack(children: [
        Positioned.fill(child: panel),
        Positioned(
          left: currentRect.width * .3 / 2,
          top: currentRect.height * .3 / 2,
          width: currentRect.width * .7,
          height: currentRect.height * .7,
          child: IgnorePointer(
            ignoring: false,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.transparent),
              ),
            ),
          ),
        ),
        if (widget.active)
          Center(
            child: IgnorePointer(
              ignoring: true,
              child: Icon(Icons.open_with, size: 26, color: Theme.of(context).colorScheme.primary.withOpacity(.25)),
            ),
          )
      ]);
    }
    final dragWrapper = widget.enableLongPress
        ? LongPressDraggable<Rect>(
            feedback: Container(), // Remove ghost feedback to prevent duplicate content
            onDragStarted: () => _startDrag(Offset.zero, Offset.zero),
            onDragUpdate: (d) { _updateDrag(DragUpdateDetails(delta: d.delta, globalPosition: d.globalPosition)); },
            onDragEnd: (_) => _endDrag(),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: widget.centerDragOnly ? (d) {
                // only allow if inside center zone
                final local = d.localPosition;
                final cx = currentRect.width / 2;
                final cy = currentRect.height / 2;
                final allow = (local.dx - cx).abs() < currentRect.width * .35 && (local.dy - cy).abs() < currentRect.height * .35;
                if (allow) _startDrag(d.globalPosition, d.localPosition);
              } : (d) => _startDrag(d.globalPosition, d.localPosition),
              onPanUpdate: _updateDrag,
              onPanEnd: (_) => _endDrag(),
              child: moveChild,
            ),
          )
        : GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: widget.centerDragOnly ? (d) {
              final local = d.localPosition;
              final cx = currentRect.width / 2;
              final cy = currentRect.height / 2;
              final allow = (local.dx - cx).abs() < currentRect.width * .35 && (local.dy - cy).abs() < currentRect.height * .35;
              if (!allow) return; // ignore starts outside center
              _startDrag(d.globalPosition, d.localPosition);
            } : (d) => _startDrag(d.globalPosition, d.localPosition),
            onPanUpdate: _updateDrag,
            onPanEnd: (_) => _endDrag(),
            child: moveChild,
          );

    return Positioned(
      left: currentRect.left,
      top: currentRect.top,
      width: currentRect.width,
      height: currentRect.height,
      child: dragWrapper,
    );
  }
}
