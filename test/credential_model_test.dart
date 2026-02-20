import 'package:flutter_test/flutter_test.dart';
import 'package:keyring/models/credential.dart';

void main() {
  group('Credential.copyWith nullable reset', () {
    test('allows explicit null for folderId/url/notes', () {
      final source = Credential(
        id: 1,
        title: 'Service',
        username: 'user',
        password: 'pass',
        url: 'https://example.com',
        notes: 'some notes',
        folderId: 10,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
      );

      final updated = source.copyWith(
        folderId: null,
        url: null,
        notes: null,
      );

      expect(updated.folderId, isNull);
      expect(updated.url, isNull);
      expect(updated.notes, isNull);
      expect(updated.title, equals(source.title));
      expect(updated.username, equals(source.username));
    });
  });
}
