import 'package:flutter/material.dart';

/// Instagram-style pinch-to-zoom: two-finger scale magnifies the child in
/// place, then snaps back when fingers lift.
///
/// Surrounding scrollables (PageView / ListView) should listen to
/// [isPinching] and switch to [NeverScrollableScrollPhysics] while it's true,
/// otherwise their pan recognizer steals the gesture arena before the second
/// pinch finger has landed.
class PinchToZoom extends StatefulWidget {
  /// True whenever at least one [PinchToZoom] currently has 2+ fingers down.
  static final ValueNotifier<bool> isPinching = ValueNotifier<bool>(false);

  final Widget child;
  final double maxScale;

  const PinchToZoom({
    super.key,
    required this.child,
    this.maxScale = 4.0,
  });

  @override
  State<PinchToZoom> createState() => _PinchToZoomState();
}

class _PinchToZoomState extends State<PinchToZoom>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _resetCtrl;
  Animation<Matrix4>? _resetAnim;
  int _activePointers = 0;

  @override
  void initState() {
    super.initState();
    _resetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_resetAnim != null) _controller.value = _resetAnim!.value;
      });
  }

  void _onPointerDown(PointerDownEvent _) {
    _activePointers++;
    if (_activePointers >= 2) PinchToZoom.isPinching.value = true;
  }

  void _onPointerEnd() {
    _activePointers = (_activePointers - 1).clamp(0, 99);
    if (_activePointers < 2) PinchToZoom.isPinching.value = false;
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    if (_controller.value == Matrix4.identity()) return;
    _resetAnim = Matrix4Tween(
      begin: _controller.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: _resetCtrl, curve: Curves.easeOut));
    _resetCtrl
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    // Failsafe: if this widget is torn down mid-pinch, release the flag so
    // surrounding scrollables don't stay locked.
    if (_activePointers > 0) {
      _activePointers = 0;
      PinchToZoom.isPinching.value = false;
    }
    _resetCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: (_) => _onPointerEnd(),
      onPointerCancel: (_) => _onPointerEnd(),
      child: InteractiveViewer(
        transformationController: _controller,
        panEnabled: false,
        scaleEnabled: true,
        minScale: 1.0,
        maxScale: widget.maxScale,
        clipBehavior: Clip.none,
        onInteractionEnd: _onInteractionEnd,
        child: widget.child,
      ),
    );
  }
}
