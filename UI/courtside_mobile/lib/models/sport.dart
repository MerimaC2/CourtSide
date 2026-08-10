class Sport {
  final int id;
  final String name;
  final String? description;

  Sport({required this.id, required this.name, this.description});

  factory Sport.fromJson(Map<String, dynamic> json) => Sport(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
      );
}
