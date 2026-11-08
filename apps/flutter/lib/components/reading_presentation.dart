import 'package:flutter/material.dart';

/// Supplies local detail context to the auxiliary pane without another request.
class ReadingSupplement extends Notification {
  ReadingSupplement(this.id, this.child);
  final String id;
  final Widget child;
}

/// Reading typography follows the available pane, including standalone routes.
class ReadingPresentation extends InheritedWidget {
  const ReadingPresentation(
      {super.key, required this.wide, required super.child});

  final bool wide;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReadingPresentation>()?.wide ??
      false;

  @override
  bool updateShouldNotify(ReadingPresentation oldWidget) =>
      wide != oldWidget.wide;
}
