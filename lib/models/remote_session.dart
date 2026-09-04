class RemoteSession {
  final String id;
  final String rawUrl;
  String title;
  final DateTime createdAt;
  DateTime lastAccessedAt;
  bool isPinned;

  RemoteSession({
    required this.id,
    required this.rawUrl,
    required this.title,
    required this.createdAt,
    required this.lastAccessedAt,
    this.isPinned = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawUrl': rawUrl,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
        'isPinned': isPinned,
      };

  factory RemoteSession.fromJson(Map<String, dynamic> json) => RemoteSession(
        id: json['id'] as String,
        rawUrl: json['rawUrl'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
        isPinned: json['isPinned'] as bool? ?? false,
      );
}
