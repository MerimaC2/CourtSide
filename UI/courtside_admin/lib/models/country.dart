class Country {
  final int id;
  final String name;
  final String? isoCode;

  Country({required this.id, required this.name, this.isoCode});

  factory Country.fromJson(Map<String, dynamic> json) => Country(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        isoCode: json['isoCode'] as String?,
      );
}
