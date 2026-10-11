import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// ExpressiveMotion.kt port — exact Compose spring constants
/// (Compose spring(dampingRatio, stiffness) == mass 1.0).
class LwMotion {
  LwMotion._();

  static const int quickMs = 160;
  static const int standardMs = 300;
  static const int emphasizedMs = 440;

  // Compose Spring stiffness constants.
  static const double stiffnessVeryLow = 50;
  static const double stiffnessLow = 200;
  static const double stiffnessMediumLow = 400;
  static const double stiffnessMedium = 1500;

  /// Compose spring(dampingRatio, stiffness) with mass 1.
  static SpringDescription spring(double dampingRatio, double stiffness) =>
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: stiffness,
        ratio: dampingRatio,
      );

  // Spatial: overshoot/bounce for layout + scale.
  static SpringDescription spatialFast() => spring(0.5, stiffnessMediumLow);
  static SpringDescription spatialDefault() => spring(0.65, stiffnessLow);
  static SpringDescription spatialSlow() => spring(0.7, stiffnessVeryLow);

  // Effects: no overshoot (alpha, color).
  static SpringDescription effectsFast() => spring(1, stiffnessMedium);
  static SpringDescription effectsDefault() => spring(1, stiffnessLow);
  static SpringDescription effectsSlow() => spring(1, stiffnessVeryLow);
}

/// Drives a spring through an AnimationController with a real
/// SpringSimulation (no fixed duration; controller stops when the
/// simulation settles).
class LwSpring {
  LwSpring._();

  static TickerFuture animate(
      AnimationController controller,
      double target,
      SpringDescription spec,
      ) =>
      controller.animateWith(
        SpringSimulation(spec, controller.value, target, 0),
      );
}

/// Curve wrapper sampling a SpringSimulation across a normalized window.
/// Used where a Curve is required (page transitions). ⚠️ The window maps
/// 0..1 to 1s of simulated time — a good match for stiffnessLow, slightly
/// early for VeryLow; acceptable until transition internals take
/// controllers directly.
class LwSpringCurve extends Curve {
  const LwSpringCurve(this.dampingRatio, this.stiffness, {this.window = 1.0});
  final double dampingRatio;
  final double stiffness;
  final double window;

  @override
  double transformInternal(double t) {
    final sim = SpringSimulation(
      LwMotion.spring(dampingRatio, stiffness), 0, 1, 0,
    );
    return sim.x(t * window).clamp(0.0, 1.5);
  }
}

/// forwardEnter / forwardExit / backEnter / backExit ports.
class LwTransitions {
  LwTransitions._();

  static PageRouteBuilder<T> push<T>(Widget page) => PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 440),
    reverseTransitionDuration: const Duration(milliseconds: 440),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, secondary, child) {
      // The incoming page: forwardEnter on push, backEnter on pop.
      final enter = _enterSpec(animation, forward: _isPush(animation, secondary));
      // The underlying page: forwardExit on push, backExit on pop.
      final exit = _exitSpec(secondary, forward: _isPush(animation, secondary));
      return enter.build(child);
    },
  );

  /// Compose NavHost semantics: the enter animation runs forward on push
  /// and reverses on pop; the secondary (underlying page) runs its exit
  /// forward on push and reverses on pop.
  static bool _isPush(Animation<double> animation, Animation<double> secondary) {
    final primaryReverse =
        animation.status == AnimationStatus.reverse;
    final secondaryForward =
        secondary.status == AnimationStatus.forward ||
            secondary.status == AnimationStatus.completed;
    return primaryReverse ? false : secondaryForward;
  }

  static _EnterSpec _enterSpec(
      Animation<double> a, {
        required bool forward,
      }) {
    if (a.status == AnimationStatus.dismissed) {
      // Still-animated identity wrapper: never null, no mixed types.
      return _EnterSpec(
        slide: null,
        scale: const AlwaysStoppedAnimation(1.0),
        opacity: const AlwaysStoppedAnimation(1.0),
      );
    }
    final slideFrom = forward ? 10.0 : -12.0;
    return _EnterSpec(
      slide: Tween<Offset>(begin: Offset(slideFrom / 100, 0), end: Offset.zero)
          .chain(CurveTween(curve: const LwSpringCurve(0.65, 200)))
          .animate(a),
      scale: Tween<double>(begin: 0.96, end: 1.0)
          .chain(CurveTween(curve: const LwSpringCurve(0.5, 400)))
          .animate(a),
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
    );
  }

  static _ExitSpec _exitSpec(
      Animation<double> a, {
        required bool forward,
      }) {
    final slideTo = forward ? 0.0 : 12.0 / 100;
    return _ExitSpec(
      slide: forward
          ? null
          : Tween<Offset>(begin: Offset.zero, end: Offset(slideTo, 0))
          .chain(CurveTween(curve: const LwSpringCurve(0.65, 200)))
          .animate(a),
      scale: Tween<double>(begin: 1.0, end: 0.985)
          .chain(CurveTween(curve: const LwSpringCurve(0.65, 200)))
          .animate(a),
      opacity: CurvedAnimation(parent: a, curve: Curves.easeIn),
    );
  }
}

/// Typed wrappers so every composite widget returns exactly one type.
class _EnterSpec {
  const _EnterSpec({
    required this.slide,
    required this.scale,
    required this.opacity,
  });

  final Animation<Offset>? slide;
  final Animation<double> scale;
  final Animation<double> opacity;

  Widget build(Widget child) {
    Widget w = ScaleTransition(scale: scale, child: child);
    final slide = this.slide;
    if (slide != null) w = SlideTransition(position: slide, child: w);
    return FadeTransition(opacity: opacity, child: w);
  }
}

class _ExitSpec {
  const _ExitSpec({
    required this.slide,
    required this.scale,
    required this.opacity,
  });

  final Animation<Offset>? slide;
  final Animation<double> scale;
  final Animation<double> opacity;

  Widget build(Widget child) {
    Widget w = ScaleTransition(scale: scale, child: FadeTransition(
      opacity: opacity,
      child: child,
    ));
    final slide = this.slide;
    if (slide != null) w = SlideTransition(position: slide, child: w);
    return w;
  }
}

/// expressivePressScale port: squish to [targetScale] while held, spring
/// back on release (spatialFast).
class LwPressScale extends StatefulWidget {
  const LwPressScale({
    super.key,
    required this.child,
    this.targetScale = 0.96,
    this.enabled = true,
  });

  final Widget child;
  final double targetScale;
  final bool enabled;

  @override
  State<LwPressScale> createState() => _LwPressScaleState();
}

class _LwPressScaleState extends State<LwPressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this)
    ..value = 1;

  void _to(double target) {
    if (!widget.enabled) return;
    LwSpring.animate(_c, target, LwMotion.spatialFast());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _to(widget.targetScale),
      onPointerUp: (_) => _to(1),
      onPointerCancel: (_) => _to(1),
      child: ScaleTransition(scale: _c, child: widget.child),
    );
  }
}