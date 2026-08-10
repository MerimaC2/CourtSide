class City {
  final int id;
  final String name;
  final String? postalCode;
  final int countryId;
  final String? countryName;

  City({
    required this.id,
    required this.name,
    this.postalCode,
    required this.countryId,
    this.countryName,
  });

  factory City.fromJson(Map<String, dynamic> json) => City(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        postalCode: json['postalCode'] as String?,
        countryId: json['countryId'] as int? ?? 0,
        countryName: json['countryName'] as String?,
      );
}
