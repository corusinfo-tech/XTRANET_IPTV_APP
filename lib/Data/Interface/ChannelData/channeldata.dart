class Channel {
  final String id;
  final String name;
  final int serviceId;
  final String categoryId;
  final int channelNumber;
  final String logoUrl;
  final String language;
  final String quality;
  final String streamingUrl;

  Channel({
    required this.id,
    required this.name,
    required this.serviceId,
    required this.categoryId,
    required this.channelNumber,
    required this.logoUrl,
    required this.language,
    required this.quality,
    required this.streamingUrl,
  });

  factory Channel.fromMap(Map<String, dynamic> m) {
    return Channel(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      serviceId: int.tryParse(m['serviceId']?.toString() ?? '0') ?? 0,
      categoryId: (m['bouquetIds'] != null && m['bouquetIds'].isNotEmpty) 
          ? m['bouquetIds'][0].toString() 
          : 'all',
      channelNumber: int.tryParse(m['lcn']?.toString() ?? '0') ?? 0,
      logoUrl: m['img']?.toString() ?? m['logo']?.toString() ?? '',
      language: (m['epgLanguages'] != null && m['epgLanguages'].isNotEmpty) ? m['epgLanguages'][0].toString() : 'EN',
      quality: 'HD',
      streamingUrl: m['url']?.toString() ?? '',
    );
  }
}
