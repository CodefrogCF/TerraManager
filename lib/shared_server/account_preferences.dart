import 'api_input.dart';

/// Personal settings live in accounts.sqlite, never in a collection backup.
const defaultAccountPreferences = <String, Object>{
  'theme_mode': 'system',
  'accent': 'green',
  'language': 'system',
  'animal_name_order': 'commonNameFirst',
  'animal_sort_order': 'createdOldestFirst',
  'animal_category_view_enabled': false,
  'next_feeding_summary_enabled': false,
  'big_picture_mode_enabled': false,
  'box_sort_order': 'labelAscending',
  'animal_archive_sort_order': 'archivedNewestFirst',
  'box_archive_sort_order': 'archivedNewestFirst',
};

const _choices = <String, Set<String>>{
  'theme_mode': {'system', 'light', 'dark'},
  'accent': {'green', 'blue', 'teal', 'orange', 'purple', 'red'},
  'language': {'system', 'english', 'german'},
  'animal_name_order': {'commonNameFirst', 'latinNameFirst'},
  'animal_sort_order': {
    'createdOldestFirst',
    'createdNewestFirst',
    'displayNameAscending',
    'displayNameDescending',
    'ageOldestFirst',
    'ageYoungestFirst',
    'latestFeedingNewestFirst',
    'latestFeedingOldestFirst',
  },
  'box_sort_order': {
    'labelAscending',
    'labelDescending',
    'nameAscending',
    'nameDescending',
    'volumeAscending',
    'volumeDescending',
  },
  'animal_archive_sort_order': {
    'archivedNewestFirst',
    'archivedOldestFirst',
    'nameAscending',
    'nameDescending',
  },
  'box_archive_sort_order': {
    'archivedNewestFirst',
    'archivedOldestFirst',
    'nameAscending',
    'nameDescending',
  },
};

Map<String, Object> validateAccountPreferences(Map<String, dynamic> patch) {
  if (patch.isEmpty) {
    throw const ApiProblem(400, 'invalid_data', 'No preferences supplied.');
  }
  final result = <String, Object>{};
  for (final entry in patch.entries) {
    final choices = _choices[entry.key];
    final valid = choices != null
        ? entry.value is String && choices.contains(entry.value)
        : defaultAccountPreferences[entry.key] is bool && entry.value is bool;
    if (!valid) {
      throw ApiProblem(
        400,
        'invalid_data',
        'Invalid preference: ${entry.key}.',
      );
    }
    result[entry.key] = entry.value as Object;
  }
  return result;
}
