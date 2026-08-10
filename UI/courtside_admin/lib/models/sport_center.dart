class SportCenter {
  final int id;
  final String name;
  final String address;
  final String? description;
  final int cityId;
  final String? cityName;

  SportCenter({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    required this.cityId,
    this.cityName,
  });

  factory SportCenter.fromJson(Map<String, dynamic> json) => SportCenter(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        description: json['description'] as String?,
        cityId: json['cityId'] as int? ?? 0,
        cityName: json['cityName'] as String?,
      );
}
