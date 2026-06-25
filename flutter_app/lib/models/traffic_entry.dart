class TrafficEntry {
  final String id;
  final String timestamp;
  final String requestUrl;
  final String requestMethod;
  final Map<String, String> requestHeaders;
  final String? requestBody;
  final int responseStatus;
  final Map<String, String> responseHeaders;
  final String? responseBody;
  final String contentType;
  final double durationMs;

  TrafficEntry({
    required this.id,
    required this.timestamp,
    required this.requestUrl,
    required this.requestMethod,
    this.requestHeaders = const {},
    this.requestBody,
    this.responseStatus = 0,
    this.responseHeaders = const {},
    this.responseBody,
    this.contentType = '',
    this.durationMs = 0.0,
  });

  factory TrafficEntry.fromJson(Map<String, dynamic> json) {
    return TrafficEntry(
      id: json['id'] ?? '',
      timestamp: json['timestamp'] ?? '',
      requestUrl: json['request_url'] ?? '',
      requestMethod: json['request_method'] ?? 'GET',
      requestHeaders: Map<String, String>.from(json['request_headers'] ?? {}),
      requestBody: json['request_body'],
      responseStatus: json['response_status'] ?? 0,
      responseHeaders: Map<String, String>.from(json['response_headers'] ?? {}),
      responseBody: json['response_body'],
      contentType: json['content_type'] ?? '',
      durationMs: (json['duration_ms'] ?? 0.0).toDouble(),
    );
  }

  String get statusColor {
    if (responseStatus >= 200 && responseStatus < 300) return 'green';
    if (responseStatus >= 300 && responseStatus < 400) return 'orange';
    if (responseStatus >= 400) return 'red';
    return 'grey';
  }

  String get shortUrl {
    final uri = Uri.tryParse(requestUrl);
    if (uri == null) return requestUrl;
    final path = uri.path;
    return path.length > 60 ? '...${path.substring(path.length - 57)}' : path;
  }
}
