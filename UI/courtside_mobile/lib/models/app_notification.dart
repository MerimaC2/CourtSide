class AppNotification {
  final int id;
  final String title;
  final String text;
  final bool isRead;
  final String type;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.text,
    required this.isRead,
    required this.type,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
        isRead: json['isRead'] as bool? ?? false,
        type: json['type'] as String? ?? 'General',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        text: text,
        isRead: isRead ?? this.isRead,
        type: type,
        createdAt: createdAt,
      );
}
