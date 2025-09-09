import 'package:flutter/material.dart';

/// Виджет для создания адаптивной разметки, которая центрируется и
/// ограничивается по ширине на больших экранах.
class ResponsiveLayout extends StatelessWidget {
  /// Дочерний виджет, который будет отображаться внутри контейнера.
  final Widget child;

  /// Максимальная ширина контента. По умолчанию 1200.
  final double maxWidth;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.maxWidth = 600.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
