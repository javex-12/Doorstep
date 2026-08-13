import 'dart:async';

import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:flutter/material.dart';

class DoorstepCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;

  const DoorstepCard({
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    super.key,
  });

  @override
  State<DoorstepCard> createState() => _DoorstepCardState();
}

class _DoorstepCardState extends State<DoorstepCard> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      unawaited(_animController.forward());
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      unawaited(_animController.reverse());
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      unawaited(_animController.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(24);
    final primary = DoorstepTheme.primaryOf(context);
    final cardWidget = Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? DoorstepTheme.surfaceOf(context),
        borderRadius: borderRadius,
        border: Border.all(
          color: widget.borderColor ?? DoorstepTheme.borderOf(context),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: widget.onTap,
          splashColor: primary.withValues(alpha: 0.08),
          highlightColor: primary.withValues(alpha: 0.04),
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.all(18),
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.onTap == null) {
      return cardWidget;
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: cardWidget,
      ),
    );
  }
}
