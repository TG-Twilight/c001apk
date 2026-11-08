import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../constants/liquid_glass_level.dart';

/// Public backend: ordinary translucent/frosted surfaces and navigation.
/// The official source assembly supplies the same API with its own renderer.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.shader,
    required this.enabled,
    required this.extent,
    required this.depth,
    required this.dispersion,
    required this.tint,
    this.refractionHeight = 0,
    this.depthEffect = false,
    this.blur = 4,
    this.fallbackTint,
    this.level = LiquidGlassLevel.medium,
    this.press = 0,
    this.borderRadius,
    this.shadow = true,
  });

  factory GlassSurface.navigationBase({
    required ui.FragmentShader? shader,
    required bool enabled,
    required Size extent,
    required ThemeData theme,
    required LiquidGlassLevel level,
    BorderRadius? borderRadius,
    bool shadow = true,
    double press = 0,
  }) =>
      GlassSurface(
          shader: shader,
          enabled: enabled,
          extent: extent,
          depth: 0,
          dispersion: 0,
          tint: theme.colorScheme.surfaceContainer,
          level: level,
          borderRadius: borderRadius,
          shadow: shadow,
          press: press);

  factory GlassSurface.navigationLens({
    required ui.FragmentShader? shader,
    required bool enabled,
    required Size extent,
    required ThemeData theme,
    required LiquidGlassLevel level,
    required double progress,
    bool shadow = true,
    Color? tint,
  }) =>
      GlassSurface(
          shader: shader,
          enabled: enabled,
          extent: extent,
          depth: 0,
          dispersion: 0,
          tint: tint ?? theme.colorScheme.primaryContainer,
          level: level,
          depthEffect: true,
          shadow: shadow,
          press: progress);

  final ui.FragmentShader? shader;
  final bool enabled, depthEffect, shadow;
  final Size extent;
  final double depth, dispersion, refractionHeight, blur, press;
  final Color tint;
  final Color? fallbackTint;
  final LiquidGlassLevel level;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(extent.height / 2);
    final solid = !enabled || MediaQuery.highContrastOf(context);
    final content = ColoredBox(
      color: (fallbackTint ?? tint).withValues(alpha: solid ? 1 : .9),
      child: const SizedBox.expand(),
    );
    return ClipRRect(
      borderRadius: radius,
      child: solid || level == LiquidGlassLevel.low
          ? content
          : BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: content),
    );
  }
}

class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel(
      {super.key,
      required this.child,
      required this.enabled,
      required this.level,
      this.borderRadius = const BorderRadius.all(Radius.circular(28))});
  final Widget child;
  final bool enabled;
  final LiquidGlassLevel level;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: borderRadius,
      child: Stack(children: [
        Positioned.fill(
            child: IgnorePointer(
                child: LayoutBuilder(
                    builder: (context, bounds) => GlassSurface(
                        shader: null,
                        enabled: enabled,
                        extent: bounds.biggest,
                        depth: 0,
                        dispersion: 0,
                        tint: Theme.of(context).colorScheme.surfaceContainer,
                        level: level,
                        borderRadius: borderRadius)))),
        child,
      ]));
}

class LiquidGlassButton extends StatelessWidget {
  const LiquidGlassButton(
      {super.key,
      required this.child,
      required this.height,
      required this.level,
      required this.onPressed,
      required this.tooltip,
      this.width,
      this.enabled = true});
  final Widget child;
  final double height;
  final double? width;
  final LiquidGlassLevel level;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        IgnorePointer(
            child: GlassSurface.navigationBase(
                shader: null,
                enabled: enabled,
                extent: Size(width ?? height, height),
                theme: Theme.of(context),
                level: level,
                shadow: false)),
        Tooltip(
            message: tooltip,
            child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                    onTap: onPressed,
                    borderRadius: BorderRadius.circular(height / 2),
                    child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Center(child: child))))),
      ]));
}

class LiquidNavigationBar extends StatefulWidget {
  const LiquidNavigationBar(
      {super.key,
      required this.selectedIndex,
      required this.onDestinationSelected,
      this.program,
      this.refract = true,
      this.direction = Axis.horizontal,
      this.level = LiquidGlassLevel.medium})
      : labels = const ['主页', '关注', '我的'],
        tabs = false;
  const LiquidNavigationBar.tabs(
      {super.key,
      required this.selectedIndex,
      required this.onDestinationSelected,
      required this.labels,
      this.program,
      this.refract = true,
      this.direction = Axis.horizontal,
      this.level = LiquidGlassLevel.medium})
      : tabs = true;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final ui.FragmentProgram? program;
  final bool refract, tabs;
  final Axis direction;
  final LiquidGlassLevel level;
  final List<String> labels;

  @override
  State<LiquidNavigationBar> createState() => _BasicNavigationState();
}

class _BasicNavigationState extends State<LiquidNavigationBar> {
  int? _dragIndex;
  bool get _vertical => widget.direction == Axis.vertical;

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      bottom: !widget.tabs && !_vertical,
      minimum: widget.tabs || _vertical
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
              constraints: _vertical
                  ? const BoxConstraints(maxHeight: 176, maxWidth: 128)
                  : BoxConstraints(
                      maxWidth: widget.tabs ? double.infinity : 248),
              child: LayoutBuilder(builder: (context, bounds) {
                if (widget.labels.isEmpty || bounds.maxWidth <= 0) {
                  return const SizedBox.shrink();
                }
                final theme = Theme.of(context);
                final textHeight = MediaQuery.textScalerOf(context).scale(14);
                final height = widget.tabs
                    ? math.max(48.0, textHeight + 24)
                    : math.max(64.0, textHeight + 40);
                final length = _vertical ? bounds.maxHeight : bounds.maxWidth;
                final selected = (_dragIndex ?? widget.selectedIndex)
                    .clamp(0, widget.labels.length - 1);
                void drag(Offset point) => setState(() => _dragIndex =
                    ((_vertical ? point.dy : point.dx) /
                            length *
                            widget.labels.length)
                        .floor()
                        .clamp(0, widget.labels.length - 1));
                return _BasicRoundHitRegion(
                    child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(_vertical ? 28 : height / 2),
                        child: GestureDetector(
                          key: ValueKey(widget.tabs
                              ? 'liquid-tabs-surface'
                              : 'liquid-drag-surface'),
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: _vertical
                              ? null
                              : (event) => drag(event.localPosition),
                          onHorizontalDragUpdate: _vertical
                              ? null
                              : (event) => drag(event.localPosition),
                          onHorizontalDragCancel: _vertical
                              ? null
                              : () => setState(() => _dragIndex = null),
                          onHorizontalDragEnd: _vertical
                              ? null
                              : (_) {
                                  final index = _dragIndex;
                                  setState(() => _dragIndex = null);
                                  if (index != null) {
                                    widget.onDestinationSelected(index);
                                  }
                                },
                          onVerticalDragStart: !_vertical
                              ? null
                              : (event) => drag(event.localPosition),
                          onVerticalDragUpdate: !_vertical
                              ? null
                              : (event) => drag(event.localPosition),
                          onVerticalDragCancel: !_vertical
                              ? null
                              : () => setState(() => _dragIndex = null),
                          onVerticalDragEnd: !_vertical
                              ? null
                              : (_) {
                                  final index = _dragIndex;
                                  setState(() => _dragIndex = null);
                                  if (index != null) {
                                    widget.onDestinationSelected(index);
                                  }
                                },
                          child: SizedBox(
                              height: _vertical ? length : height,
                              child: Stack(children: [
                                Positioned.fill(
                                    child: IgnorePointer(
                                        child: GlassSurface.navigationBase(
                                            shader: null,
                                            borderRadius: _vertical
                                                ? BorderRadius.circular(28)
                                                : null,
                                            enabled: widget.refract,
                                            extent: _vertical
                                                ? Size(bounds.maxWidth, length)
                                                : Size(bounds.maxWidth, height),
                                            theme: theme,
                                            level: widget.level,
                                            shadow: false))),
                                Flex(
                                  direction: widget.direction,
                                  children: [
                                    for (var i = 0;
                                        i < widget.labels.length;
                                        i++)
                                      Expanded(
                                          child: Semantics(
                                              label: widget.labels[i],
                                              excludeSemantics: true,
                                              selected: selected == i,
                                              button: true,
                                              inMutuallyExclusiveGroup: true,
                                              child: TextButton(
                                                  onPressed: () => widget
                                                      .onDestinationSelected(i),
                                                  style: TextButton.styleFrom(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 2),
                                                      backgroundColor: selected == i
                                                          ? theme.colorScheme
                                                              .primaryContainer
                                                          : Colors.transparent,
                                                      foregroundColor: selected == i
                                                          ? theme.colorScheme
                                                              .onPrimaryContainer
                                                          : theme.colorScheme
                                                              .onSurface),
                                                  child: widget.tabs
                                                      ? Text(widget.labels[i],
                                                          maxLines: 1)
                                                      : Flex(direction: _vertical ? Axis.horizontal : Axis.vertical, mainAxisSize: MainAxisSize.min, children: [
                                                          Icon([
                                                            Icons.home_outlined,
                                                            Icons.feed_outlined,
                                                            Icons.person_outline
                                                          ][i % 3]),
                                                          if (_vertical)
                                                            const SizedBox(
                                                                width: 10),
                                                          Text(widget.labels[i],
                                                              maxLines: 1),
                                                        ]))))
                                  ],
                                ),
                              ])),
                        )));
              }))));
}

class _BasicRoundHitRegion extends SingleChildRenderObjectWidget {
  const _BasicRoundHitRegion({required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _BasicRoundHitBox();
}

class _BasicRoundHitBox extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      RRect.fromRectAndRadius(
              Offset.zero & size,
              Radius.circular(size.height > size.width ? 28 : size.height / 2))
          .contains(position) &&
      super.hitTest(result, position: position);
}
