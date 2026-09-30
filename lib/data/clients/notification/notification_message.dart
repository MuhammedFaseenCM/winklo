class NotificationMessage {
  const NotificationMessage({
    required this.data,
    required this.type,
    this.id,
    this.title,
    this.body,
    this.receivedAt,
  });

  final String? id;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final String type;
  final DateTime? receivedAt;

  String get route {
    final value = data['route'];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return '/';
  }

  factory NotificationMessage.fromPayloadMap(Map<String, dynamic> map) {
    final rawData = map['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    return NotificationMessage(
      id: map['id'] as String?,
      title: map['title'] as String?,
      body: map['body'] as String?,
      data: data,
      type: (map['type'] as String?) ?? data['type'] as String? ?? 'general',
      receivedAt: DateTime.now(),
    );
  }
}
