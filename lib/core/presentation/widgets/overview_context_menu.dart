import 'package:flutter/material.dart';

typedef OverviewContextMenuBuilder = Widget Function(
  BuildContext context,
  Widget menuButton,
);

class OverviewContextMenu<T> extends StatefulWidget {
  final Key menuButtonKey;
  final String tooltip;
  final PopupMenuItemBuilder<T> itemBuilder;
  final ValueChanged<T> onSelected;
  final OverviewContextMenuBuilder builder;

  const OverviewContextMenu({
    super.key,
    required this.menuButtonKey,
    required this.tooltip,
    required this.itemBuilder,
    required this.onSelected,
    required this.builder,
  });

  @override
  State<OverviewContextMenu<T>> createState() => _OverviewContextMenuState<T>();
}

class _OverviewContextMenuState<T> extends State<OverviewContextMenu<T>> {
  final GlobalKey<PopupMenuButtonState<T>> _popupMenuKey =
      GlobalKey<PopupMenuButtonState<T>>();

  void _openMenu() {
    _popupMenuKey.currentState?.showButtonMenu();
  }

  @override
  Widget build(BuildContext context) {
    final menuButton = KeyedSubtree(
      key: widget.menuButtonKey,
      child: PopupMenuButton<T>(
        key: _popupMenuKey,
        tooltip: widget.tooltip,
        onSelected: widget.onSelected,
        itemBuilder: widget.itemBuilder,
        icon: const Icon(Icons.more_vert),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onLongPress: _openMenu,
      onSecondaryTap: _openMenu,
      child: widget.builder(context, menuButton),
    );
  }
}
