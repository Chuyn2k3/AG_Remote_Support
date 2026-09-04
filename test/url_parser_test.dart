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

    test('extractEmail extracts correct email', () {
      expect(UrlParser.extractEmail(validGoogleUrl), 'phamdoan060801@gmail.com');
      expect(UrlParser.extractEmail(validDirectUrl), isNull);
      expect(
        UrlParser.extractEmail('https://antigravity.google.com/r/abc-v2?authuser=work%40company.com'),
        'work@company.com',
      );
    });

    test('getShortSessionId truncates properly', () {
      expect(UrlParser.getShortSessionId('328cc6cd-005f-4647-b021-17c7681f6407-v2'),
          '328cc6cd...v2');
    });

    // --- SECURITY ATTACK VECTOR TESTS ---
    test('isAntigravityUrl rejects http protocol downgrade', () {
      expect(UrlParser.isAntigravityUrl('http://antigravity.google.com/r/abc-123'), isFalse);
    });

    test('isAntigravityUrl rejects open redirect attacks on google domain', () {
      expect(UrlParser.isAntigravityUrl('https://evil.com?redirect=antigravity.google.com'), isFalse);
      expect(UrlParser.isAntigravityUrl('https://evil.com/r/antigravity.google.com'), isFalse);
    });

    test('isAntigravityUrl rejects spoofed subdomains', () {
      expect(UrlParser.isAntigravityUrl('https://antigravity.google.com.evil.com/r/abc-123'), isFalse);
    });

    test('isAntigravityUrl validates legitimate accounts.google.com only with valid antigravity continue', () {
      expect(
        UrlParser.isAntigravityUrl('https://accounts.google.com/AccountChooser?continue=https%3A%2F%2Fantigravity.google.com%2Fr%2F123'),
        isTrue,
      );
      expect(
        UrlParser.isAntigravityUrl('https://accounts.google.com/AccountChooser?continue=https%3A%2F%2Fevil.com'),
        isFalse,
      );
    });
  });
}
