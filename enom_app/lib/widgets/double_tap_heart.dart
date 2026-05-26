import 'package:flutter/material.dart';

/// Wraps [child] and shows an Instagram-style heart pop animation on
/// double-tap, while invoking [onDoubleTap] to perform the like.
///
/// - [onTap] is forwarded to the underlying [GestureDetector] so callers can
///   keep their existing single-tap behavior (open reels, play/pause, etc.).
/// - The heart always animates on double-tap, even if the post is already
///   liked (matches Instagram behavior — the animation is purely affordance).
/// - Triggering the like is the caller's responsibility inside [onDoubleTap];
///   typically callers only call their `_toggleReaction` when the post is not
///   already liked, so a double-tap never un-likes.
class DoubleTapHeart extends StatefulWidget {
  final Widget child;
  final VoidCallback onDoubleTap;
  final VoidCallback? onTap;

  /// Size of the heart icon at full scale.
  final double heartSize;

  /// Color of the heart icon.
  final Color heartColor;

  const DoubleTapHeart({
    super.key,
    required this.child,
    required this.onDoubleTap,
    this.onTap,
    this.heartSize = 110,
    this.heartColor = Colors.white,
  });

  @override
  State<DoubleTapHeart> createState() => _DoubleTapHeartState();
}

class _DoubleTapHeartState extends State<DoubleTapHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.6)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    widget.onDoubleTap();
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: _handleDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                if (_controller.isDismissed) {
                  return const SizedBox.shrink();
                }
                return Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Icon(
                      Icons.favorite,
                      size: widget.heartSize,
                      color: widget.heartColor,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 24,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
