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
        type: _typeFrom(json['type']),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  /// The server's `NotificationType` names by enum value. The type normally arrives as the
  /// name; a numeric value is mapped to the same name so either form parses.
  static const _typeNames = {
    1: 'ReservationCreated',
    2: 'ReservationConfirmed',
    3: 'ReservationCancelled',
    4: 'ReservationCompleted',
    5: 'PaymentCompleted',
    6: 'PaymentRefunded',
    7: 'General',
    8: 'PaymentRefundPending',
    9: 'PaymentRefundFailed',
  };

  static String _typeFrom(Object? value) => switch (value) {
        String name when name.isNotEmpty => name,
        int number => _typeNames[number] ?? 'General',
        _ => 'General',
      };

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        text: text,
        isRead: isRead ?? this.isRead,
        type: type,
        createdAt: createdAt,
      );
}
