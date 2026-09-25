import 'package:flutter/material.dart';

import '../features/settings/animal_name_order.dart';
import '../features/settings/animal_sort_order.dart';
import '../features/settings/box_sort_order.dart';
import 'shared_text.dart';

enum SharedDetailSource { boxes, animals, boxAnimals }

/// Browser-only context for one detail route. Record data remains on the server.
final class SharedDetailNavigationContext {
  SharedDetailNavigationContext._({
    required this.source,
    required this.recordIds,
    required this.currentRecordId,
    required this.archived,
    this.sourceBoxId,
    this.boxSortOrder,
    this.animalSortOrder,
    this.animalNameOrder,
    this.groupCategories = false,
  }) {
    if (recordIds.isEmpty ||
        recordIds.toSet().length != recordIds.length ||
        !recordIds.contains(currentRecordId)) {
      throw ArgumentError(
        'Detail context requires distinct IDs and a current record.',
      );
    }
  }

  factory SharedDetailNavigationContext.boxes({
    required Iterable<int> recordIds,
    required int currentRecordId,
    required bool archived,
    required BoxSortOrder sortOrder,
  }) => SharedDetailNavigationContext._(
    source: SharedDetailSource.boxes,
    recordIds: List<int>.unmodifiable(recordIds),
    currentRecordId: currentRecordId,
    archived: archived,
    boxSortOrder: sortOrder,
  );

  factory SharedDetailNavigationContext.animals({
    required Iterable<int> recordIds,
    required int currentRecordId,
    required bool archived,
    required AnimalSortOrder sortOrder,
    required AnimalNameOrder nameOrder,
    required bool groupCategories,
  }) => SharedDetailNavigationContext._(
    source: SharedDetailSource.animals,
    recordIds: List<int>.unmodifiable(recordIds),
    currentRecordId: currentRecordId,
    archived: archived,
    animalSortOrder: sortOrder,
    animalNameOrder: nameOrder,
    groupCategories: groupCategories,
  );

  factory SharedDetailNavigationContext.boxAnimals({
    required Iterable<int> recordIds,
    required int currentRecordId,
    required int boxId,
    required AnimalNameOrder nameOrder,
  }) => SharedDetailNavigationContext._(
    source: SharedDetailSource.boxAnimals,
    recordIds: List<int>.unmodifiable(recordIds),
    currentRecordId: currentRecordId,
    archived: false,
    sourceBoxId: boxId,
    animalNameOrder: nameOrder,
  );

  final SharedDetailSource source;
  final List<int> recordIds;
  final int currentRecordId;
  final bool archived;
  final int? sourceBoxId;
  final BoxSortOrder? boxSortOrder;
  final AnimalSortOrder? animalSortOrder;
  final AnimalNameOrder? animalNameOrder;
  final bool groupCategories;

  int? get previousRecordId {
    final index = recordIds.indexOf(currentRecordId);
    return index > 0 ? recordIds[index - 1] : null;
  }

  int? get nextRecordId {
    final index = recordIds.indexOf(currentRecordId);
    return index >= 0 && index < recordIds.length - 1
        ? recordIds[index + 1]
        : null;
  }

  SharedDetailNavigationContext? withRecords(
    Iterable<int> ids, {
    int? selectedId,
  }) {
    final values = List<int>.unmodifiable(ids);
    final current = selectedId ?? currentRecordId;
    if (!values.contains(current)) return null;
    return SharedDetailNavigationContext._(
      source: source,
      recordIds: values,
      currentRecordId: current,
      archived: archived,
      sourceBoxId: sourceBoxId,
      boxSortOrder: boxSortOrder,
      animalSortOrder: animalSortOrder,
      animalNameOrder: animalNameOrder,
      groupCategories: groupCategories,
    );
  }
}

class SharedDetailNavigationBar extends StatelessWidget {
  const SharedDetailNavigationBar({
    super.key,
    required this.contextData,
    required this.onPrevious,
    required this.onNext,
    this.busy = false,
  });

  final SharedDetailNavigationContext contextData;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final box = contextData.source == SharedDetailSource.boxes;
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            key: const Key('shared-detail-previous'),
            tooltip: box
                ? sharedText(context, 'Previous Box', 'Vorherige Box')
                : sharedText(context, 'Previous Animal', 'Vorheriges Tier'),
            onPressed: busy || contextData.previousRecordId == null
                ? null
                : onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${contextData.recordIds.indexOf(contextData.currentRecordId) + 1} '
            '/ ${contextData.recordIds.length}',
            key: const Key('shared-detail-position'),
          ),
          IconButton(
            key: const Key('shared-detail-next'),
            tooltip: box
                ? sharedText(context, 'Next Box', 'Nächste Box')
                : sharedText(context, 'Next Animal', 'Nächstes Tier'),
            onPressed: busy || contextData.nextRecordId == null ? null : onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class SharedDetailSwipeRegion extends StatefulWidget {
  const SharedDetailSwipeRegion({
    super.key,
    required this.child,
    required this.enabled,
    required this.onPrevious,
    required this.onNext,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  State<SharedDetailSwipeRegion> createState() =>
      _SharedDetailSwipeRegionState();
}

class _SharedDetailSwipeRegionState extends State<SharedDetailSwipeRegion> {
  static const _threshold = 72.0;
  double _distance = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('shared-detail-swipe-area'),
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: widget.enabled ? (_) => _distance = 0 : null,
    onHorizontalDragUpdate: widget.enabled
        ? (details) => _distance += details.primaryDelta ?? 0
        : null,
    onHorizontalDragEnd: widget.enabled
        ? (_) {
            final distance = _distance;
            _distance = 0;
            if (distance <= -_threshold) widget.onNext();
            if (distance >= _threshold) widget.onPrevious();
          }
        : null,
    onHorizontalDragCancel: widget.enabled ? () => _distance = 0 : null,
    child: widget.child,
  );
}
