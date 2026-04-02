class QrPayloadService {
  QrPayloadService._();

  static String? extractBatchId(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final batchMatch = RegExp(r'(?:^|\|)BATCH:([^|]+)', caseSensitive: false)
        .firstMatch(value);
    if (batchMatch != null) {
      final batchId = batchMatch.group(1)?.trim();
      if (batchId != null && batchId.isNotEmpty) {
        return batchId;
      }
    }

    if (!value.contains('|') && !value.contains(':')) {
      return value;
    }

    return null;
  }
}
