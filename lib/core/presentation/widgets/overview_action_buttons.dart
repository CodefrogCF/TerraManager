import 'package:flutter/material.dart';

/// Floating actions follow the surrounding overview's scroll visibility.
class OverviewActionButtons extends StatelessWidget {
  const OverviewActionButtons({
    super.key,
    required this.primary,
    required this.secondary,
  });
  static const bottomPadding = 16.0;
  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    final buttons = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [secondary, const SizedBox(height: 12), primary],
    );
    final visibility = context
        .dependOnInheritedWidgetOfExactType<_OverviewActionVisibility>()
        ?.visible;
    if (visibility == null) return buttons;
    return ValueListenableBuilder<bool>(
      valueListenable: visibility,
      child: buttons,
      builder: (context, visible, child) =>
          visible ? child! : const SizedBox.shrink(),
    );
  }
}

/// Each overview owns its visibility, including when its data or layout changes.
class OverviewScrollScope extends StatefulWidget {
  const OverviewScrollScope({super.key, required this.child});
  final Widget child;

  @override
  State<OverviewScrollScope> createState() => _OverviewScrollScopeState();
}

/// Restores the actions when an overview replaces its scroll view with a message.
class OverviewPlaceholder extends StatelessWidget {
  const OverviewPlaceholder({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    context
        .dependOnInheritedWidgetOfExactType<_OverviewActionVisibility>()
        ?.showActions();
    return Center(child: child);
  }
}

class _OverviewScrollScopeState extends State<OverviewScrollScope> {
  final _visible = ValueNotifier(true);
  bool _pendingVisible = true;
  bool _scheduled = false;

  void _update(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    final scrollable = metrics.maxScrollExtent > metrics.minScrollExtent + 0.5;
    _setVisible(!scrollable || metrics.extentAfter > 0.5);
  }

  void _showActions() => _setVisible(true);

  void _setVisible(bool visible) {
    _pendingVisible = visible;
    if (_scheduled || _pendingVisible == _visible.value) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _visible.value = _pendingVisible;
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _visible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _OverviewActionVisibility(
    visible: _visible,
    showActions: _showActions,
    child: NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _update(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _update(notification.metrics);
          return false;
        },
        child: widget.child,
      ),
    ),
  );
}

class _OverviewActionVisibility extends InheritedWidget {
  const _OverviewActionVisibility({
    required this.visible,
    required this.showActions,
    required super.child,
  });
  final ValueNotifier<bool> visible;
  final VoidCallback showActions;

  @override
  bool updateShouldNotify(_OverviewActionVisibility oldWidget) =>
      visible != oldWidget.visible;
}
