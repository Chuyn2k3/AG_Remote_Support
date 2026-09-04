import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_support/core/utils/url_parser.dart';

void main() {
  group('UrlParser Tests', () {
    const validGoogleUrl =
        'https://accounts.google.com/AccountChooser?Email=phamdoan060801%40gmail.com&continue=https%3A%2F%2Fantigravity.google.com%2Fr%2F328cc6cd-005f-4647-b021-17c7681f6407-v2';
    const validDirectUrl =
        'https://antigravity.google.com/r/328cc6cd-005f-4647-b021-17c7681f6407-v2';
    const invalidUrl = 'https://google.com/search?q=test';

    test('isAntigravityUrl returns true for valid URLs', () {
      expect(UrlParser.isAntigravityUrl(validGoogleUrl), isTrue);
      expect(UrlParser.isAntigravityUrl(validDirectUrl), isTrue);
      expect(UrlParser.isAntigravityUrl(invalidUrl), isFalse);
    });

    test('extractSessionId extracts correct ID', () {
      expect(UrlParser.extractSessionId(validGoogleUrl),
          '328cc6cd-005f-4647-b021-17c7681f6407-v2');
      expect(UrlParser.extractSessionId(validDirectUrl),
          '328cc6cd-005f-4647-b021-17c7681f6407-v2');
      expect(UrlParser.extractSessionId(invalidUrl), isNull);
    });

    test('getShortSessionId truncates properly', () {
      expect(UrlParser.getShortSessionId('328cc6cd-005f-4647-b021-17c7681f6407-v2'),
          '328cc6cd...v2');
    });
  });
}
