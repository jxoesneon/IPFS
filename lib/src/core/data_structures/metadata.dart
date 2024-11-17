// src/core/data_structures/metadata.dart
class IPLDMetadata {
  final int size;
  final Map<String, String> properties;
  final DateTime? lastModified;
  final String? contentType;

  IPLDMetadata({
    required this.size,
    this.properties = const {},
    this.lastModified,
    this.contentType,
  });

  Map<String, dynamic> toJson() => {
        'size': size,
        'lastModified': lastModified?.toIso8601String(),
        'contentType': contentType,
        'properties': properties,
      };
}
