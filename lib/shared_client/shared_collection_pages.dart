import 'package:flutter/material.dart';

import '../core/database/enums/animal_category.dart';
import '../core/presentation/widgets/overview_context_menu.dart';
import '../core/sorting/natural_string_comparator.dart';
import '../features/settings/animal_sort_order.dart';
import '../features/settings/animal_name_order.dart';
import '../features/settings/app_accent.dart';
import '../features/settings/app_language.dart';
import '../features/settings/app_settings_controller.dart';
import '../features/settings/box_sort_order.dart';
import '../l10n/app_localizations_context.dart';
import '../l10n/app_localizations_labels.dart';
import 'shared_api_client.dart';
import 'shared_detail_pages.dart';
import 'shared_forms.dart';
import 'shared_history_page.dart';
import 'shared_text.dart';

typedef SharedChange = Future<bool> Function(Future<void> Function() operation);

int recordId(Map<String, dynamic> record) => record['id'] as int;

String boxLabel(Map<String, dynamic> box) {
  final name = (box['name'] as String?)?.trim();
  return name == null || name.isEmpty
      ? 'Box ${recordId(box)}'
      : '$name · Box ${recordId(box)}';
}

String animalLabel(
  Map<String, dynamic> animal, {
  AnimalNameOrder order = AnimalNameOrder.commonNameFirst,
}) {
  final common = (animal['commonName'] as String?)?.trim() ?? '';
  final latin = (animal['latinName'] as String?)?.trim() ?? '';
  if (order == AnimalNameOrder.latinNameFirst) {
    return latin.isNotEmpty ? latin : common;
  }
  return common.isNotEmpty ? common : latin;
}

enum _BoxAction { rename, edit, duplicate, archive }

enum _AnimalAction { feeding, rename, edit, archive, duplicate }

PopupMenuItem<T> _menuItem<T>(T value, IconData icon, String label) =>
    PopupMenuItem<T>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(label)),
        ],
      ),
    );

String? _boxDimensions(Map<String, dynamic> box) {
  final values = [box['widthCm'], box['heightCm'], box['depthCm']];
  if (values.every((value) => value == null)) return null;
  return '${values.map((value) => value?.toString() ?? '–').join(' × ')} cm';
}

Map<String, dynamic> _animalUpdateValues(
  Map<String, dynamic> animal,
  String commonName,
) => {
  for (final key in const [
    'boxId',
    'latinName',
    'category',
    'subcategory',
    'sex',
    'birthDate',
    'birthDateAccuracy',
    'tempMin',
    'tempMax',
    'nighttimeTemperatureMin',
    'nighttimeTemperatureMax',
    'humidityMin',
    'humidityMax',
    'originHabitat',
    'restOrDormancyPeriods',
    'notes',
    'pictureMediaId',
    'feedingReminderIntervalDays',
    'feedingReminderBaseline',
    'showWeightOnDetail',
    'showSheddingOnDetail',
  ])
    key: animal[key],
  'commonName': commonName,
};

Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String initial,
}) => showDialog<String>(
  context: context,
  builder: (_) => _NameDialog(title: title, initial: initial),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 200,
      decoration: InputDecoration(
        labelText: sharedText(context, 'Name', 'Name'),
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(sharedText(context, 'Save', 'Speichern')),
      ),
    ],
  );
}

void _showChangeFailure(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        sharedText(
          context,
          'Could not save. Reload and check the server state.',
          'Speichern fehlgeschlagen. Neu laden und Serverstand prüfen.',
        ),
      ),
    ),
  );
}

class SharedBoxesPage extends StatefulWidget {
  const SharedBoxesPage({
    super.key,
    required this.api,
    required this.boxes,
    required this.animals,
    required this.connected,
    required this.change,
    required this.onReload,
  });

  final SharedApiClient api;
  final List<Map<String, dynamic>> boxes;
  final List<Map<String, dynamic>> animals;
  final bool connected;
  final SharedChange change;
  final Future<void> Function() onReload;

  @override
  State<SharedBoxesPage> createState() => _SharedBoxesPageState();
}

class _SharedBoxesPageState extends State<SharedBoxesPage> {
  bool _archived = false;

  Future<void> _openBox(Map<String, dynamic> box) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SharedBoxDetailPage(
          api: widget.api,
          id: recordId(box),
          boxes: widget.boxes,
          animals: widget.animals,
          connected: widget.connected,
          change: widget.change,
        ),
      ),
    );
  }

  Future<void> _boxAction(_BoxAction action, Map<String, dynamic> box) async {
    if (!widget.connected || !widget.api.connected) return;
    final id = recordId(box);
    switch (action) {
      case _BoxAction.rename:
        final name = await _askName(
          context,
          title: context.l10n.renameBox,
          initial: (box['name'] as String?) ?? '',
        );
        if (name == null) return;
        final saved = await widget.change(() async {
          await widget.api.updateBox(id, {'name': name});
        });
        if (!saved && mounted) _showChangeFailure(context);
      case _BoxAction.edit:
        try {
          final current = await widget.api.box(id);
          if (!mounted) return;
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => SharedBoxForm(
                api: widget.api,
                change: widget.change,
                initial: current,
              ),
            ),
          );
        } catch (_) {
          if (mounted) _showChangeFailure(context);
        }
      case _BoxAction.duplicate:
        final name = await _askName(
          context,
          title: context.l10n.duplicateBox,
          initial: (box['name'] as String?) ?? '',
        );
        if (name == null) return;
        final saved = await widget.change(() async {
          await widget.api.duplicateBox(id, name);
        });
        if (!saved && mounted) _showChangeFailure(context);
      case _BoxAction.archive:
        final choice = await showArchiveDialog(
          context,
          reasons: const ['sold', 'replaced', 'damaged', 'other'],
        );
        if (choice == null) return;
        final saved = await widget.change(() async {
          await widget.api.archiveBox(id, choice.$1, choice.$2);
        });
        if (!saved && mounted) _showChangeFailure(context);
    }
  }

  List<PopupMenuEntry<_BoxAction>> _boxMenu(BuildContext context) => [
    _menuItem(
      _BoxAction.rename,
      Icons.drive_file_rename_outline,
      context.l10n.renameBox,
    ),
    _menuItem(_BoxAction.edit, Icons.edit_outlined, context.l10n.editBox),
    _menuItem(
      _BoxAction.duplicate,
      Icons.copy_outlined,
      context.l10n.duplicateBox,
    ),
    _menuItem(
      _BoxAction.archive,
      Icons.archive_outlined,
      context.l10n.archiveBox,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final values = widget.boxes
        .where((box) => (box['status'] == 'archived') == _archived)
        .toList();
    values.sort((a, b) {
      final order = settings.boxSortOrder;
      final aId = recordId(a);
      final bId = recordId(b);
      if (order == BoxSortOrder.labelAscending) return aId.compareTo(bId);
      if (order == BoxSortOrder.labelDescending) return bId.compareTo(aId);
      if (order == BoxSortOrder.nameAscending ||
          order == BoxSortOrder.nameDescending) {
        final aName = ((a['name'] as String?) ?? '').trim();
        final bName = ((b['name'] as String?) ?? '').trim();
        if (aName.isEmpty && bName.isNotEmpty) return 1;
        if (bName.isEmpty && aName.isNotEmpty) return -1;
        final result = compareNaturalStrings(aName, bName);
        return order == BoxSortOrder.nameDescending ? -result : result;
      }
      double volume(Map<String, dynamic> box) =>
          ((box['widthCm'] as num?)?.toDouble() ?? 0) *
          ((box['heightCm'] as num?)?.toDouble() ?? 0) *
          ((box['depthCm'] as num?)?.toDouble() ?? 0);
      final result = volume(a).compareTo(volume(b));
      return order == BoxSortOrder.volumeDescending ? -result : result;
    });

    return Scaffold(
      appBar: AppBar(
        leading: _archived
            ? IconButton(
                tooltip: sharedText(context, 'Back', 'Zurück'),
                onPressed: () => setState(() => _archived = false),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(
          _archived ? context.l10n.archivedBoxes : context.l10n.navigationBoxes,
        ),
        actions: [
          PopupMenuButton<BoxSortCriterion>(
            key: const Key('box-sort-button'),
            initialValue: settings.boxSortOrder.criterion,
            tooltip: context.l10n.sortBoxes,
            icon: const Icon(Icons.sort),
            onSelected: (criterion) {
              final current = settings.boxSortOrder;
              settings.setBoxSortOrder(
                criterion == current.criterion
                    ? current.reversed
                    : criterion.defaultOrder,
              );
            },
            itemBuilder: (context) => [
              for (final criterion in BoxSortCriterion.values)
                CheckedPopupMenuItem<BoxSortCriterion>(
                  key: Key('box-sort-option-${criterion.name}'),
                  value: criterion,
                  checked: criterion == settings.boxSortOrder.criterion,
                  child: Text(
                    context.l10n.boxSortCriterionMenuLabel(
                      criterion,
                      activeOrder: criterion == settings.boxSortOrder.criterion
                          ? settings.boxSortOrder
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          if (!_archived)
            IconButton(
              key: const Key('box-archive-button'),
              tooltip: context.l10n.archivedBoxes,
              onPressed: () => setState(() => _archived = true),
              icon: const Icon(Icons.inventory_2_outlined),
            ),
          IconButton(
            key: const Key('shared-refresh'),
            tooltip: sharedText(context, 'Reload', 'Neu laden'),
            onPressed: widget.onReload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _archived
          ? null
          : FloatingActionButton(
              key: const Key('add-box-button'),
              heroTag: 'shared-box-add',
              tooltip: context.l10n.addBox,
              onPressed: widget.connected
                  ? () => Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => SharedBoxForm(
                          api: widget.api,
                          change: widget.change,
                        ),
                      ),
                    )
                  : null,
              child: const Icon(Icons.add),
            ),
      body: values.isEmpty
          ? Center(
              child: Text(
                _archived
                    ? sharedText(
                        context,
                        'No archived Boxes',
                        'Keine archivierten Boxen',
                      )
                    : context.l10n.noBoxesAvailable,
              ),
            )
          : ListView.builder(
              key: PageStorageKey<String>(
                _archived ? 'shared-boxes-archive' : 'shared-boxes-overview',
              ),
              itemCount: values.length,
              itemBuilder: (context, index) {
                final box = values[index];
                final id = recordId(box);
                final name = (box['name'] as String?)?.trim();
                final hasName = name != null && name.isNotEmpty;
                final dimensions = _boxDimensions(box);
                Widget tile(Widget? menuButton) => ListTile(
                  key: Key('box-list-item-$id'),
                  leading: SharedThumbnail(
                    api: widget.api,
                    mediaId: box['pictureMediaId'] as int?,
                    fallback: Icons.inventory_2_outlined,
                  ),
                  title: Text(hasName ? name : 'Box $id'),
                  subtitle: hasName
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Box $id'),
                            if (dimensions != null) Text(dimensions),
                          ],
                        )
                      : dimensions == null
                      ? null
                      : Text(dimensions),
                  isThreeLine: hasName && dimensions != null,
                  trailing: menuButton,
                  onTap: () => _openBox(box),
                );
                if (_archived) return tile(const Icon(Icons.chevron_right));
                return OverviewContextMenu<_BoxAction>(
                  key: Key('box-context-menu-region-$id'),
                  menuButtonKey: Key('box-context-menu-button-$id'),
                  tooltip: context.l10n.boxActions(hasName ? name : 'Box $id'),
                  onSelected: (action) => _boxAction(action, box),
                  itemBuilder: _boxMenu,
                  builder: (context, button) => tile(button),
                );
              },
            ),
    );
  }
}

class SharedAnimalsPage extends StatefulWidget {
  const SharedAnimalsPage({
    super.key,
    required this.api,
    required this.boxes,
    required this.animals,
    required this.connected,
    required this.change,
    required this.onReload,
  });

  final SharedApiClient api;
  final List<Map<String, dynamic>> boxes;
  final List<Map<String, dynamic>> animals;
  final bool connected;
  final SharedChange change;
  final Future<void> Function() onReload;

  @override
  State<SharedAnimalsPage> createState() => _SharedAnimalsPageState();
}

class _SharedAnimalsPageState extends State<SharedAnimalsPage> {
  bool _archived = false;

  Future<void> _openAnimal(Map<String, dynamic> animal) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SharedAnimalDetailPage(
          api: widget.api,
          id: recordId(animal),
          boxes: widget.boxes,
          connected: widget.connected,
          change: widget.change,
        ),
      ),
    );
  }

  Future<void> _animalAction(
    _AnimalAction action,
    Map<String, dynamic> animal,
  ) async {
    if (!widget.connected || !widget.api.connected) return;
    final id = recordId(animal);
    switch (action) {
      case _AnimalAction.feeding:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SharedHistoryPage(
              api: widget.api,
              animalId: id,
              kind: SharedHistoryKind.feedings,
              active: true,
              change: widget.change,
              createOnOpen: true,
            ),
          ),
        );
      case _AnimalAction.rename:
        final name = await _askName(
          context,
          title: context.l10n.renameAnimal,
          initial: (animal['commonName'] as String?) ?? '',
        );
        if (name == null) return;
        final saved = await widget.change(() async {
          // PUT accepts a complete Animal command. Preserve every editable
          // field while changing only the common name.
          final current = await widget.api.animal(id);
          await widget.api.updateAnimal(id, _animalUpdateValues(current, name));
        });
        if (!saved && mounted) _showChangeFailure(context);
      case _AnimalAction.edit:
        try {
          final current = await widget.api.animal(id);
          if (!mounted) return;
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => SharedAnimalForm(
                api: widget.api,
                boxes: widget.boxes,
                change: widget.change,
                initial: current,
              ),
            ),
          );
        } catch (_) {
          if (mounted) _showChangeFailure(context);
        }
      case _AnimalAction.archive:
        final choice = await showArchiveDialog(
          context,
          reasons: const ['sold', 'traded', 'deceased', 'rehomed', 'other'],
        );
        if (choice == null) return;
        final saved = await widget.change(() async {
          await widget.api.archiveAnimal(id, choice.$1, choice.$2);
        });
        if (!saved && mounted) _showChangeFailure(context);
      case _AnimalAction.duplicate:
        final destination = await selectActiveBox(context, widget.boxes);
        if (destination == null || !mounted) return;
        final name = await _askName(
          context,
          title: context.l10n.duplicateAnimal,
          initial: (animal['commonName'] as String?) ?? '',
        );
        if (name == null) return;
        final saved = await widget.change(() async {
          await widget.api.duplicateAnimal(id, destination, name);
        });
        if (!saved && mounted) _showChangeFailure(context);
    }
  }

  List<PopupMenuEntry<_AnimalAction>> _animalMenu(BuildContext context) => [
    _menuItem(
      _AnimalAction.feeding,
      Icons.restaurant_outlined,
      context.l10n.createFeeding,
    ),
    _menuItem(
      _AnimalAction.rename,
      Icons.drive_file_rename_outline,
      context.l10n.renameAnimal,
    ),
    _menuItem(_AnimalAction.edit, Icons.edit_outlined, context.l10n.editAnimal),
    _menuItem(
      _AnimalAction.archive,
      Icons.archive_outlined,
      context.l10n.archiveAnimal,
    ),
    _menuItem(
      _AnimalAction.duplicate,
      Icons.copy_outlined,
      context.l10n.duplicateAnimal,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final values = widget.animals
        .where((animal) => (animal['status'] == 'archived') == _archived)
        .toList();
    values.sort((a, b) {
      final order = settings.animalSortOrder;
      final aId = recordId(a);
      final bId = recordId(b);
      if (order == AnimalSortOrder.createdOldestFirst) {
        return aId.compareTo(bId);
      }
      if (order == AnimalSortOrder.createdNewestFirst) {
        return bId.compareTo(aId);
      }
      if (order == AnimalSortOrder.ageOldestFirst ||
          order == AnimalSortOrder.ageYoungestFirst) {
        final aDate = DateTime.tryParse(a['birthDate'] as String? ?? '');
        final bDate = DateTime.tryParse(b['birthDate'] as String? ?? '');
        if (aDate == null && bDate != null) return 1;
        if (bDate == null && aDate != null) return -1;
        final comparison = (aDate ?? DateTime(1900)).compareTo(
          bDate ?? DateTime(1900),
        );
        return order == AnimalSortOrder.ageYoungestFirst
            ? -comparison
            : comparison;
      }
      final result = compareNaturalStrings(
        animalLabel(a, order: settings.animalNameOrder),
        animalLabel(b, order: settings.animalNameOrder),
      );
      return order == AnimalSortOrder.displayNameDescending ? -result : result;
    });
    final rows = <Object>[];
    if (settings.animalCategoryViewEnabled) {
      for (final category in AnimalCategory.values) {
        final categoryAnimals = values
            .where((animal) => animal['category'] == category.name)
            .toList();
        if (categoryAnimals.isEmpty) continue;
        rows.add(context.l10n.animalCategoryPluralLabel(category));
        for (final subcategory in category.subcategories) {
          final subcategoryAnimals = categoryAnimals
              .where((animal) => animal['subcategory'] == subcategory.name)
              .toList();
          if (subcategoryAnimals.isEmpty) continue;
          rows.add(context.l10n.animalSubcategoryPluralLabel(subcategory));
          rows.addAll(subcategoryAnimals);
        }
        rows.addAll(
          categoryAnimals.where(
            (animal) =>
                animal['subcategory'] == null ||
                !category.subcategories.any(
                  (value) => value.name == animal['subcategory'],
                ),
          ),
        );
      }
    } else {
      rows.addAll(values);
    }
    return Scaffold(
      appBar: AppBar(
        leading: _archived
            ? IconButton(
                tooltip: sharedText(context, 'Back', 'Zurück'),
                onPressed: () => setState(() => _archived = false),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(
          _archived
              ? context.l10n.animalHistory
              : context.l10n.navigationAnimals,
        ),
        actions: [
          if (!_archived)
            IconButton(
              key: const Key('animal-category-view-toggle'),
              isSelected: settings.animalCategoryViewEnabled,
              onPressed: () => settings.setAnimalCategoryViewEnabled(
                !settings.animalCategoryViewEnabled,
              ),
              icon: const Icon(Icons.toggle_on_outlined),
              selectedIcon: const Icon(Icons.toggle_off_outlined),
              tooltip: settings.animalCategoryViewEnabled
                  ? context.l10n.hideAnimalCategoryGroups
                  : context.l10n.showAnimalCategoryGroups,
            ),
          PopupMenuButton<AnimalSortCriterion>(
            key: const Key('animal-sort-button'),
            initialValue: settings.animalSortOrder.criterion,
            tooltip: context.l10n.sortAnimals,
            icon: const Icon(Icons.sort),
            onSelected: (criterion) {
              final current = settings.animalSortOrder.normalized;
              settings.setAnimalSortOrder(
                criterion == current.criterion
                    ? current.reversed
                    : criterion.defaultOrder,
              );
            },
            itemBuilder: (context) => [
              for (final criterion in const [
                AnimalSortCriterion.created,
                AnimalSortCriterion.displayName,
                AnimalSortCriterion.age,
              ])
                CheckedPopupMenuItem<AnimalSortCriterion>(
                  key: Key('animal-sort-option-${criterion.name}'),
                  value: criterion,
                  checked: criterion == settings.animalSortOrder.criterion,
                  child: Text(
                    context.l10n.animalSortCriterionMenuLabel(
                      criterion,
                      activeOrder:
                          criterion == settings.animalSortOrder.criterion
                          ? settings.animalSortOrder
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          if (!_archived)
            IconButton(
              key: const Key('animal-history-button'),
              tooltip: context.l10n.animalHistory,
              onPressed: () => setState(() => _archived = true),
              icon: const Icon(Icons.history),
            ),
          IconButton(
            key: const Key('shared-refresh'),
            tooltip: sharedText(context, 'Reload', 'Neu laden'),
            onPressed: widget.onReload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _archived
          ? null
          : FloatingActionButton(
              key: const Key('add-animal-button'),
              heroTag: 'shared-animal-add',
              tooltip: context.l10n.addAnimal,
              onPressed:
                  widget.connected &&
                      widget.boxes.any((box) => box['status'] == 'active')
                  ? () => Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => SharedAnimalForm(
                          api: widget.api,
                          boxes: widget.boxes,
                          change: widget.change,
                        ),
                      ),
                    )
                  : null,
              child: const Icon(Icons.add),
            ),
      body: values.isEmpty
          ? Center(
              child: Text(
                _archived
                    ? context.l10n.noArchivedAnimals
                    : context.l10n.noAnimalsAvailable,
              ),
            )
          : ListView.builder(
              key: PageStorageKey<String>(
                _archived
                    ? 'shared-animals-archive'
                    : 'shared-animals-overview',
              ),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                if (row is String) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      row,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }
                final animal = row as Map<String, dynamic>;
                final id = recordId(animal);
                final primary = animalLabel(
                  animal,
                  order: settings.animalNameOrder,
                );
                final common = (animal['commonName'] as String?)?.trim() ?? '';
                final latin = (animal['latinName'] as String?)?.trim() ?? '';
                final secondary =
                    settings.animalNameOrder == AnimalNameOrder.commonNameFirst
                    ? latin
                    : common;
                final box = widget.boxes
                    .where((entry) => entry['id'] == animal['boxId'])
                    .firstOrNull;
                Widget tile(Widget? menuButton) => ListTile(
                  key: Key('animal-list-item-$id'),
                  leading: SharedThumbnail(
                    api: widget.api,
                    mediaId: animal['pictureMediaId'] as int?,
                    fallback: Icons.emoji_nature_outlined,
                  ),
                  title: Text(primary),
                  subtitle: Text(
                    [
                      if (secondary.isNotEmpty && secondary != primary)
                        secondary,
                      if (box != null) boxLabel(box),
                    ].join(' · '),
                  ),
                  trailing: menuButton,
                  onTap: () => _openAnimal(animal),
                );
                if (_archived) return tile(const Icon(Icons.chevron_right));
                return OverviewContextMenu<_AnimalAction>(
                  key: Key('animal-context-menu-region-$id'),
                  menuButtonKey: Key('animal-context-menu-button-$id'),
                  tooltip: context.l10n.animalActions(primary),
                  onSelected: (action) => _animalAction(action, animal),
                  itemBuilder: _animalMenu,
                  builder: (context, button) => tile(button),
                );
              },
            ),
    );
  }
}

class SharedThumbnail extends StatelessWidget {
  const SharedThumbnail({
    super.key,
    required this.api,
    required this.mediaId,
    required this.fallback,
  });
  final SharedApiClient api;
  final int? mediaId;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(fallback),
    );
    if (mediaId == null) return placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        api.mediaUrl(mediaId!).toString(),
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder(),
      ),
    );
  }
}

class SharedSettingsPage extends StatelessWidget {
  const SharedSettingsPage({
    super.key,
    required this.api,
    required this.username,
    required this.role,
    required this.connected,
    required this.onLogout,
  });

  final SharedApiClient api;
  final String username;
  final String role;
  final bool connected;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: Text(
            sharedText(context, 'Shared server', 'Gemeinsamer Server'),
          ),
          subtitle: Text(
            '${Uri.base.origin} · $username · ${connected ? sharedText(context, 'Connected', 'Verbunden') : sharedText(context, 'Offline', 'Offline')}',
          ),
        ),
        const Divider(),
        if (role == 'administrator') ...[
          SharedAccountsSection(api: api),
          const Divider(),
        ],
        DropdownButtonFormField<AppLanguage>(
          initialValue: settings.language,
          decoration: InputDecoration(
            labelText: sharedText(context, 'Language', 'Sprache'),
          ),
          items: [
            for (final value in AppLanguage.values)
              DropdownMenuItem(
                value: value,
                child: Text(switch (value) {
                  AppLanguage.system => sharedText(context, 'System', 'System'),
                  AppLanguage.english => 'English',
                  AppLanguage.german => 'Deutsch',
                }),
              ),
          ],
          onChanged: (value) {
            if (value != null) settings.setLanguage(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ThemeMode>(
          initialValue: settings.themeMode,
          decoration: InputDecoration(
            labelText: sharedText(context, 'Appearance', 'Darstellung'),
          ),
          items: [
            for (final value in ThemeMode.values)
              DropdownMenuItem(
                value: value,
                child: Text(switch (value) {
                  ThemeMode.system => sharedText(context, 'System', 'System'),
                  ThemeMode.light => sharedText(context, 'Light', 'Hell'),
                  ThemeMode.dark => sharedText(context, 'Dark', 'Dunkel'),
                }),
              ),
          ],
          onChanged: (value) {
            if (value != null) settings.setThemeMode(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<AppAccent>(
          initialValue: settings.accent,
          decoration: InputDecoration(
            labelText: sharedText(context, 'Accent color', 'Akzentfarbe'),
          ),
          items: [
            for (final value in AppAccent.values)
              DropdownMenuItem(value: value, child: Text(value.name)),
          ],
          onChanged: (value) {
            if (value != null) settings.setAccent(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<BoxSortOrder>(
          initialValue: settings.boxSortOrder,
          decoration: InputDecoration(
            labelText: sharedText(context, 'Box sorting', 'Box-Sortierung'),
          ),
          items: [
            for (final value in BoxSortOrder.values)
              DropdownMenuItem(
                value: value,
                child: Text(context.l10n.boxSortOrderLabel(value)),
              ),
          ],
          onChanged: (value) {
            if (value != null) settings.setBoxSortOrder(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<AnimalSortOrder>(
          initialValue:
              const [
                AnimalSortOrder.createdOldestFirst,
                AnimalSortOrder.createdNewestFirst,
                AnimalSortOrder.displayNameAscending,
                AnimalSortOrder.displayNameDescending,
                AnimalSortOrder.ageOldestFirst,
                AnimalSortOrder.ageYoungestFirst,
              ].contains(settings.animalSortOrder)
              ? settings.animalSortOrder
              : AnimalSortOrder.createdOldestFirst,
          decoration: InputDecoration(
            labelText: sharedText(context, 'Animal sorting', 'Tier-Sortierung'),
          ),
          items: [
            for (final value in const [
              AnimalSortOrder.createdOldestFirst,
              AnimalSortOrder.createdNewestFirst,
              AnimalSortOrder.displayNameAscending,
              AnimalSortOrder.displayNameDescending,
              AnimalSortOrder.ageOldestFirst,
              AnimalSortOrder.ageYoungestFirst,
            ])
              DropdownMenuItem(
                value: value,
                child: Text(context.l10n.animalSortOrderLabel(value)),
              ),
          ],
          onChanged: (value) {
            if (value != null) settings.setAnimalSortOrder(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<AnimalNameOrder>(
          initialValue: settings.animalNameOrder,
          decoration: InputDecoration(
            labelText: sharedText(
              context,
              'Animal name order',
              'Reihenfolge der Tiernamen',
            ),
          ),
          items: [
            for (final value in AnimalNameOrder.values)
              DropdownMenuItem(
                value: value,
                child: Text(context.l10n.animalNameOrderLabel(value)),
              ),
          ],
          onChanged: (value) {
            if (value != null) settings.setAnimalNameOrder(value);
          },
        ),
        SwitchListTile(
          title: Text(
            sharedText(
              context,
              'Group Animals by category',
              'Tiere nach Kategorie gruppieren',
            ),
          ),
          value: settings.animalCategoryViewEnabled,
          onChanged: settings.setAnimalCategoryViewEnabled,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(sharedText(context, 'Sign out', 'Abmelden')),
          onTap: onLogout,
        ),
      ],
    );
  }
}

class SharedAccountsSection extends StatefulWidget {
  const SharedAccountsSection({super.key, required this.api});
  final SharedApiClient api;

  @override
  State<SharedAccountsSection> createState() => _SharedAccountsSectionState();
}

class _SharedAccountsSectionState extends State<SharedAccountsSection> {
  late Future<List<Map<String, dynamic>>> _accounts;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _accounts = widget.api.accounts());

  Future<void> _add() async {
    final input = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => const _NewAccountDialog(),
    );
    if (input == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.createAccount(input.$1, input.$2, input.$3);
      if (!mounted) return;
      _reload();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = sharedText(
          context,
          'Account could not be created. Check the name, password and connection.',
          'Konto konnte nicht erstellt werden. Name, Passwort und Verbindung prüfen.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        sharedText(context, 'Caregiver accounts', 'Betreuungskonten'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _accounts,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? TextButton(
                    onPressed: _reload,
                    child: Text(
                      sharedText(context, 'Retry', 'Erneut versuchen'),
                    ),
                  )
                : const LinearProgressIndicator();
          }
          return Column(
            children: [
              for (final account in snapshot.data!)
                ListTile(
                  title: Text(account['username'] as String? ?? ''),
                  subtitle: Text(account['role'] as String? ?? ''),
                  trailing: account['active'] == false
                      ? const Icon(Icons.block_outlined)
                      : null,
                ),
            ],
          );
        },
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ListenableBuilder(
        listenable: widget.api,
        builder: (context, _) => TextButton.icon(
          onPressed: widget.api.connected && !_busy ? _add : null,
          icon: const Icon(Icons.person_add_outlined),
          label: Text(sharedText(context, 'Add account', 'Konto hinzufügen')),
        ),
      ),
    ],
  );
}

class _NewAccountDialog extends StatefulWidget {
  const _NewAccountDialog();

  @override
  State<_NewAccountDialog> createState() => _NewAccountDialogState();
}

class _NewAccountDialogState extends State<_NewAccountDialog> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String _role = 'caregiver';
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _username.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._-]{3,64}$').hasMatch(username) ||
        _password.text.length < 12) {
      setState(
        () => _error = sharedText(
          context,
          'Use a 3–64 character username and a password of at least 12 characters.',
          'Benutzername mit 3–64 Zeichen und Passwort mit mindestens 12 Zeichen eingeben.',
        ),
      );
      return;
    }
    Navigator.of(context).pop((username, _password.text, _role));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(sharedText(context, 'Add account', 'Konto hinzufügen')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _username,
          decoration: InputDecoration(
            labelText: sharedText(context, 'Username', 'Benutzername'),
          ),
        ),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(
            labelText: sharedText(context, 'Password', 'Passwort'),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: _role,
          items: [
            DropdownMenuItem(
              value: 'caregiver',
              child: Text(sharedText(context, 'Caregiver', 'Betreuung')),
            ),
            DropdownMenuItem(
              value: 'administrator',
              child: Text(
                sharedText(context, 'Administrator', 'Administrator'),
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _role = value);
          },
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(sharedText(context, 'Create', 'Erstellen')),
      ),
    ],
  );
}
