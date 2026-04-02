import 'package:flutter_test/flutter_test.dart';
import 'package:halal_traceability_app/services/profile_image_service.dart';

void main() {
  group('ProfileImageService.buildUrl', () {
    test('builds a storage URL from a relative avatar path', () {
      final url =
          ProfileImageService.buildUrl('avatars/test.jpg', version: 123);

      expect(url, 'http://10.0.2.2:8000/storage/avatars/test.jpg?v=123');
    });

    test('normalizes storage-prefixed avatar paths', () {
      final url =
          ProfileImageService.buildUrl('/storage/avatars/test.jpg', version: 7);

      expect(url, 'http://10.0.2.2:8000/storage/avatars/test.jpg?v=7');
    });

    test('accepts an absolute avatar URL and refreshes the version query', () {
      final url = ProfileImageService.buildUrl(
        'http://127.0.0.1:8000/storage/avatars/test.jpg?v=1',
        version: 99,
      );

      expect(url, 'http://127.0.0.1:8000/storage/avatars/test.jpg?v=99');
    });
  });
}
