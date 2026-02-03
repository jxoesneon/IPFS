// src/core/data_structures/metadata.dart

/// Metadata associated with IPLD nodes.
///
/// Contains size, content type, modification time, and custom properties.
class IPLDMetadata {
  /// Creates metadata with the given parameters.
  IPLDMetadata({
    required this.size,
    this.properties = const {},
    this.lastModified,
    this.contentType,
  });

  /// Size of the content in bytes.
  final int size;

  /// Custom key-value properties.
  final Map<String, String> properties;

  /// When the content was last modified.
  final DateTime? lastModified;

  /// MIME type of the content.
  final String? contentType;

  /// Converts this metadata to a JSON map.
  Map<String, dynamic> toJson() => {
    'size': size,
    'lastModified': lastModified?.toIso8601String(),
    'contentType': contentType,
    'properties': properties,
  };
}
