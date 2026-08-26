import 'package:flutter/material.dart';

/// Keeps page content readable on desktop without constraining compact screens.
class ResponsivePageBody extends StatelessWidget {
  const ResponsivePageBody({
    required this.child,
    this.maxWidth = 920,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding, child: child),
    ),
  );
}
