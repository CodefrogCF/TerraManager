import 'dart:convert';

class ApiProblem implements Exception {
  final int status;
  final String code;
  final String message;

  const ApiProblem(this.status, this.code, this.message);
}

/// Parses an allow-listed JSON command. Database IDs and lifecycle fields are
/// never mass-assigned from a browser-provided record.
class ApiInput {
  final Map<String, dynamic> values;

  ApiInput(this.values);

  factory ApiInput.decode(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const ApiProblem(400, 'invalid_json', 'Expected a JSON object.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiProblem(400, 'invalid_json', 'Expected a JSON object.');
    }
    return ApiInput(decoded);
  }

  void allow(Set<String> keys) {
    for (final key in values.keys) {
      if (!keys.contains(key)) {
        throw ApiProblem(400, 'invalid_data', 'Unknown field: $key.');
      }
    }
  }

  String string(String key, {int maxLength = 200}) {
    final value = values[key];
    if (value is! String) {
      throw ApiProblem(400, 'invalid_data', '$key must be a string.');
    }
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > maxLength) {
      throw ApiProblem(
        400,
        'invalid_data',
        '$key must contain 1 to $maxLength characters.',
      );
    }
    return normalized;
  }

  String? nullableString(String key, {int maxLength = 10000}) {
    final value = values[key];
    if (value == null) return null;
    if (value is! String) {
      throw ApiProblem(400, 'invalid_data', '$key must be a string or null.');
    }
    final normalized = value.trim();
    if (normalized.length > maxLength) {
      throw ApiProblem(
        400,
        'invalid_data',
        '$key must contain at most $maxLength characters.',
      );
    }
    return normalized.isEmpty ? null : normalized;
  }

  int integer(String key, {int minimum = 1}) {
    final value = values[key];
    if (value is! int || value < minimum) {
      throw ApiProblem(
        400,
        'invalid_data',
        '$key must be an integer >= $minimum.',
      );
    }
    return value;
  }

  int? nullableInteger(String key, {int minimum = 1}) {
    if (values[key] == null) return null;
    return integer(key, minimum: minimum);
  }

  double number(String key) {
    final value = values[key];
    if (value is! num || !value.isFinite) {
      throw ApiProblem(400, 'invalid_data', '$key must be a finite number.');
    }
    return value.toDouble();
  }

  double? nullableNumber(String key) =>
      values[key] == null ? null : number(key);

  bool boolean(String key, {bool? fallback}) {
    final value = values[key];
    if (value == null && fallback != null) return fallback;
    if (value is! bool) {
      throw ApiProblem(400, 'invalid_data', '$key must be a Boolean.');
    }
    return value;
  }

  DateTime dateTime(String key, {DateTime? fallback}) {
    final value = values[key];
    if (value == null && fallback != null) return fallback;
    if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      throw ApiProblem(400, 'invalid_data', '$key must be an ISO-8601 string.');
    }
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException {
      throw ApiProblem(400, 'invalid_data', '$key must be an ISO-8601 string.');
    }
  }

  DateTime? nullableDateTime(String key) =>
      values[key] == null ? null : dateTime(key);

  T enumerated<T extends Enum>(String key, List<T> options) {
    final value = values[key];
    if (value is! String) {
      throw ApiProblem(400, 'invalid_data', '$key has an invalid value.');
    }
    for (final option in options) {
      if (option.name == value) return option;
    }
    throw ApiProblem(400, 'invalid_data', '$key has an invalid value.');
  }

  T? nullableEnum<T extends Enum>(String key, List<T> options) =>
      values[key] == null ? null : enumerated(key, options);

  List<int> integerList(String key) {
    final value = values[key];
    if (value is! List || value.isEmpty || value.length > 100) {
      throw ApiProblem(400, 'invalid_data', '$key must be a nonempty list.');
    }
    final ids = <int>[];
    for (final item in value) {
      if (item is! int || item < 1) {
        throw ApiProblem(
          400,
          'invalid_data',
          '$key must contain positive IDs.',
        );
      }
      ids.add(item);
    }
    if (ids.toSet().length != ids.length) {
      throw ApiProblem(
        400,
        'invalid_data',
        '$key must not contain duplicates.',
      );
    }
    return ids;
  }
}
