class News {
  final int id;
  final String title;
  final String text;
  final DateTime publishedAt;
  final bool hasImage;

  News({
    required this.id,
    required this.title,
    required this.text,
    required this.publishedAt,
    required this.hasImage,
  });

  factory News.fromJson(Map<String, dynamic> json) => News(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '') ?? DateTime.now(),
        hasImage: json['hasImage'] as bool? ?? false,
      );
}
