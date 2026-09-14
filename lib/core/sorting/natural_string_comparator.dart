final RegExp _chunkPattern = RegExp(r'[0-9]+|[^0-9]+');
final RegExp _digitPattern = RegExp(r'^[0-9]+$');

int compareNaturalStrings(String first, String second) {
  final firstChunks = _chunks(first);
  final secondChunks = _chunks(second);
  var numericWidthComparison = 0;
  final sharedLength = firstChunks.length < secondChunks.length
      ? firstChunks.length
      : secondChunks.length;

  for (var index = 0; index < sharedLength; index++) {
    final firstChunk = firstChunks[index];
    final secondChunk = secondChunks[index];
    final bothNumeric =
        _digitPattern.hasMatch(firstChunk) &&
        _digitPattern.hasMatch(secondChunk);

    if (bothNumeric) {
      final valueComparison = _compareNumericChunks(firstChunk, secondChunk);

      if (valueComparison != 0) {
        return valueComparison;
      }

      if (numericWidthComparison == 0) {
        numericWidthComparison = firstChunk.length.compareTo(
          secondChunk.length,
        );
      }

      continue;
    }

    final textComparison = firstChunk.toLowerCase().compareTo(
      secondChunk.toLowerCase(),
    );

    if (textComparison != 0) {
      return textComparison;
    }
  }

  final chunkCountComparison = firstChunks.length.compareTo(
    secondChunks.length,
  );

  if (chunkCountComparison != 0) {
    return chunkCountComparison;
  }

  if (numericWidthComparison != 0) {
    return numericWidthComparison;
  }

  final caseInsensitiveComparison = first.toLowerCase().compareTo(
    second.toLowerCase(),
  );

  if (caseInsensitiveComparison != 0) {
    return caseInsensitiveComparison;
  }

  return first.compareTo(second);
}

List<String> _chunks(String value) {
  return _chunkPattern
      .allMatches(value)
      .map((match) => match.group(0)!)
      .toList(growable: false);
}

int _compareNumericChunks(String first, String second) {
  final normalizedFirst = _withoutLeadingZeros(first);
  final normalizedSecond = _withoutLeadingZeros(second);
  final lengthComparison = normalizedFirst.length.compareTo(
    normalizedSecond.length,
  );

  if (lengthComparison != 0) {
    return lengthComparison;
  }

  return normalizedFirst.compareTo(normalizedSecond);
}

String _withoutLeadingZeros(String value) {
  var firstSignificantIndex = 0;

  while (firstSignificantIndex < value.length - 1 &&
      value.codeUnitAt(firstSignificantIndex) == 48) {
    firstSignificantIndex++;
  }

  return value.substring(firstSignificantIndex);
}
