class WeatherInfo {
  final double temperatureC;
  final String description;
  final String headline;
  final String? city;
  final bool needsOuterwear;

  WeatherInfo({
    required this.temperatureC,
    required this.description,
    required this.headline,
    this.city,
    required this.needsOuterwear,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 0,
      description: json['description']?.toString() ?? '',
      headline: json['headline']?.toString() ?? '',
      city: json['city']?.toString(),
      needsOuterwear: json['needs_outerwear'] as bool? ?? false,
    );
  }
}

class CitySuggestion {
  final String name;
  final String admin1;
  final String label;
  final double latitude;
  final double longitude;

  const CitySuggestion({
    required this.name,
    required this.admin1,
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  factory CitySuggestion.fromJson(Map<String, dynamic> json) {
    return CitySuggestion(
      name: json['name']?.toString() ?? '',
      admin1: json['admin1']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}
