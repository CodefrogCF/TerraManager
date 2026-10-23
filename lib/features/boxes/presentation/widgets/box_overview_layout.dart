import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/overview_action_buttons.dart';
import '../../../../l10n/app_localizations_context.dart';

/// Keeps section headings outside grid cells and navigation record indexes.
class BoxOverviewLayout extends StatelessWidget {
  const BoxOverviewLayout({
    super.key,
    required this.scrollKey,
    required this.bigPictures,
    required this.itemCount,
    required this.itemBuilder,
    this.firstEmptyIndex = -1,
    this.controller,
    this.listPadding = const EdgeInsets.only(
      bottom: OverviewActionButtons.bottomPadding,
    ),
  }) : assert(firstEmptyIndex >= -1 && firstEmptyIndex < itemCount);

  final PageStorageKey<String> scrollKey;
  final bool bigPictures;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int firstEmptyIndex;
  final ScrollController? controller;
  final EdgeInsetsGeometry listPadding;

  @override
  Widget build(BuildContext context) {
    if (!bigPictures) {
      return ListView.builder(
        key: scrollKey,
        controller: controller,
        padding: listPadding,
        itemCount: itemCount + (firstEmptyIndex >= 0 ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == firstEmptyIndex) return const _EmptyBoxesHeading();
          return itemBuilder(
            context,
            index - (firstEmptyIndex >= 0 && index > firstEmptyIndex ? 1 : 0),
          );
        },
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (constraints.maxWidth) {
          >= 1000 => 3,
          >= 600 => 2,
          _ => 1,
        };
        final delegate = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 1.45 : 1.15,
        );
        if (firstEmptyIndex < 0) {
          return GridView.builder(
            key: scrollKey,
            controller: controller,
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              OverviewActionButtons.bottomPadding,
            ),
            gridDelegate: delegate,
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          );
        }
        Widget grid(int start, int end, {required double bottom}) =>
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, bottom),
              sliver: SliverGrid(
                gridDelegate: delegate,
                delegate: SliverChildBuilderDelegate(
                  (context, index) => itemBuilder(context, start + index),
                  childCount: end - start,
                ),
              ),
            );
        return CustomScrollView(
          key: scrollKey,
          controller: controller,
          slivers: [
            if (firstEmptyIndex > 0) grid(0, firstEmptyIndex, bottom: 12),
            const SliverToBoxAdapter(child: _EmptyBoxesHeading()),
            grid(
              firstEmptyIndex,
              itemCount,
              bottom: OverviewActionButtons.bottomPadding,
            ),
          ],
        );
      },
    );
  }
}

class _EmptyBoxesHeading extends StatelessWidget {
  const _EmptyBoxesHeading();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('empty-boxes-heading'),
    header: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            context.l10n.emptyBoxes,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    ),
  );
}
