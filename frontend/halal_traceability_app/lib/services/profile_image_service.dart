import 'package:flutter/painting.dart';

import '../config.dart';

/// Normalizes avatar URLs and clears image cache after profile updates.
class ProfileImageService {
  ProfileImageService._();

  static const String _storageSegment = '/storage/';

  static String? buildUrl(dynamic path, {required int version}) {
    final rawPath = path?.toString().trim();
    if (rawPath == null || rawPath.isEmpty) {
      return null;
    }

    final normalizedPath = _normalizeStoredPath(rawPath);
    if (normalizedPath == null) {
      return null;
    }

    final directUri = Uri.tryParse(normalizedPath);
    if (directUri != null && directUri.hasScheme && directUri.hasAuthority) {
      return _withVersion(directUri, version);
    }

    final baseUri = Uri.parse(storageUrl);
    final resolvedUri = baseUri.resolve(normalizedPath);
    return _withVersion(resolvedUri, version);
  }

  static Future<void> evict({
    dynamic previousPath,
    dynamic nextPath,
    required int currentVersion,
    required int nextVersion,
  }) async {
    final previousUrl = buildUrl(previousPath, version: currentVersion);
    final nextUrl = buildUrl(nextPath, version: nextVersion);

    if (previousUrl != null) {
      await NetworkImage(previousUrl).evict();
    }

    if (nextUrl != null) {
      await NetworkImage(nextUrl).evict();
    }
  }

  static String? _normalizeStoredPath(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      final storageIndex = uri.path.indexOf(_storageSegment);
      if (storageIndex >= 0) {
        return uri.path.substring(storageIndex + _storageSegment.length);
      }

      return uri.toString();
    }

    var normalizedPath = path.replaceAll('\\', '/').trim();
    while (normalizedPath.startsWith('/')) {
      normalizedPath = normalizedPath.substring(1);
    }

    if (normalizedPath.startsWith('public/')) {
      normalizedPath = normalizedPath.substring('public/'.length);
    }

    if (normalizedPath.startsWith('storage/')) {
      normalizedPath = normalizedPath.substring('storage/'.length);
    }

    return normalizedPath.isEmpty ? null : normalizedPath;
  }

  static String _withVersion(Uri uri, int version) {
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    queryParameters['v'] = version.toString();

    return uri.replace(queryParameters: queryParameters).toString();
  }
}
