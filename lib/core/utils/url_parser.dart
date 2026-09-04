class UrlParser {
  /// Kiểm tra xem URL có phải là đường link Antigravity hợp lệ hay không
  static bool isAntigravityUrl(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    if (uri.host == 'antigravity.google.com' && uri.path.contains('/r/')) {
      return true;
    }

    if (uri.host == 'accounts.google.com' &&
        (url.contains('antigravity.google.com') || url.contains('%2Fantigravity.google.com'))) {
      return true;
    }

    return false;
  }

  /// Bóc tách session id (ví dụ: 328cc6cd-005f-4647-b021-17c7681f6407-v2) từ URL
  static String? extractSessionId(String url) {
    if (!isAntigravityUrl(url)) return null;

    final decoded = Uri.decodeFull(url);
    final regExp = RegExp(r'\/r\/([a-zA-Z0-9\-_]+)');
    final match = regExp.firstMatch(decoded);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  /// Bóc tách email tài khoản Google từ tham số Email=... hoặc authuser=... nếu có
  static String? extractEmail(String url) {
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      if (uri.queryParameters.containsKey('Email')) {
        return uri.queryParameters['Email'];
      }
      if (uri.queryParameters.containsKey('authuser') &&
          uri.queryParameters['authuser']!.contains('@')) {
        return uri.queryParameters['authuser'];
      }
    }

    // Dự phòng tìm kiếm bằng Regex nếu URI chứa nhiều tầng encoding
    final regExp = RegExp(r'(?:Email|authuser)=([^&]+)');
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      final val = Uri.decodeComponent(match.group(1)!);
      if (val.contains('@')) return val;
    }
    return null;
  }

  /// Rút gọn session ID để hiển thị gọn gàng trên UI (ví dụ: 328cc6cd...v2)
  static String getShortSessionId(String sessionId) {
    if (sessionId.length <= 12) return sessionId;
    final prefix = sessionId.substring(0, 8);
    final suffix = sessionId.contains('-v') ? sessionId.split('-').last : sessionId.substring(sessionId.length - 4);
    return '$prefix...$suffix';
  }
}
