class Channel {
  final String id;
  final String name;
  final int serviceId;
  final String categoryId;
  final int channelNumber;
  final String logoUrl;
  final String language;
  final String quality;

  Channel({
    required this.id,
    required this.name,
    required this.serviceId,
    required this.categoryId,
    required this.channelNumber,
    required this.logoUrl,
    required this.language,
    required this.quality,
  });

  factory Channel.fromMap(Map<String, dynamic> m) {
    return Channel(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      serviceId: int.tryParse(m['serviceId']?.toString() ?? '0') ?? 0,
      categoryId: m['categoryId']?.toString() ?? '',
      channelNumber: int.tryParse(m['channelNumber']?.toString() ?? '0') ?? 0,
      logoUrl: m['logoUrl']?.toString() ?? '',
      language: m['language']?.toString() ?? 'EN',
      quality: m['quality']?.toString() ?? 'HD',
    );
  }
}
