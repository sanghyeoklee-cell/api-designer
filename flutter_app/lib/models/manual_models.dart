class HtmlSnapshot {
  final String id;
  final String timestamp;
  final String url;
  final String title;
  final String html;

  HtmlSnapshot({
    required this.id,
    required this.timestamp,
    required this.url,
    required this.title,
    required this.html,
  });

  factory HtmlSnapshot.fromJson(Map<String, dynamic> json) {
    return HtmlSnapshot(
      id: json['id'] ?? '',
      timestamp: json['timestamp'] ?? '',
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      html: json['html'] ?? '',
    );
  }

  String get shortUrl {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final path = uri.path;
    if (path.isEmpty || path == '/') return uri.host;
    return path.length > 40 ? '...${path.substring(path.length - 37)}' : path;
  }

  String get timeOnly {
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }
}
