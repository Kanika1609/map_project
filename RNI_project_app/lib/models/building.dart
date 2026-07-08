class Building {
  final String id;
  final String name;
  final String venueName;

  Building({
    required this.id,
    required this.name,
    required this.venueName,
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    print('RAW BUILDING JSON: $json');

    return Building(
      id: (json['id'] ?? json['buildingId'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? json['buildingName'] ?? json['venueName'] ?? 'Unknown')
          .toString(),
      venueName: (json['venueName'] ?? json['venue'] ?? json['name'] ?? '')
          .toString(),
    );
  }
}