import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/screens/shared/library_search_bar.dart';

void main() {
  group('filterByTitle', () {
    test('returns all items when the query is empty', () {
      final items = ['Alpha', 'Beta', 'Gamma'];
      expect(filterByTitle(items, '', (s) => s), items);
    });

    test('returns all items when the query is only whitespace', () {
      final items = ['Alpha', 'Beta'];
      expect(filterByTitle(items, '   ', (s) => s), items);
    });

    test('filters by case-insensitive substring match', () {
      final items = ['The Matrix', 'Matrix Reloaded', 'Inception'];
      expect(filterByTitle(items, 'matrix', (s) => s),
          ['The Matrix', 'Matrix Reloaded']);
    });

    test('matches a substring in the middle of the title', () {
      final items = ['Breaking Bad', 'Better Call Saul'];
      expect(filterByTitle(items, 'bad', (s) => s), ['Breaking Bad']);
    });

    test('returns an empty list when nothing matches', () {
      final items = ['Alpha', 'Beta'];
      expect(filterByTitle(items, 'zzz', (s) => s), isEmpty);
    });

    test('works with non-String item types via titleOf', () {
      final items = [
        {'name': 'Radarr'},
        {'name': 'Sonarr'},
      ];
      final result = filterByTitle(items, 'rad', (m) => m['name'] as String);
      expect(result, [
        {'name': 'Radarr'}
      ]);
    });

    test('trims leading/trailing whitespace from the query', () {
      final items = ['Alpha', 'Beta'];
      expect(filterByTitle(items, '  alpha  ', (s) => s), ['Alpha']);
    });
  });
}
