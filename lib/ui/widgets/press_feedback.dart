import 'package:flutter/material.dart';

class PressFeedback extends StatefulWidget {
  const PressFeedback({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant PressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pressed = false;
  }

  void _setPressed(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
    onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
    onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
    child: AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}
