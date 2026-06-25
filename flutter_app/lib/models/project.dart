class ProjectInfo {
  final String id;
  final String name;
  final String description;
  final String targetUrl;
  final String createdAt;
  final String updatedAt;
  final int sessionCount;

  ProjectInfo({
    required this.id,
    required this.name,
    this.description = '',
    this.targetUrl = '',
    required this.createdAt,
    required this.updatedAt,
    this.sessionCount = 0,
  });

  factory ProjectInfo.fromJson(Map<String, dynamic> json) {
    return ProjectInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      targetUrl: json['target_url'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      sessionCount: json['session_count'] ?? 0,
    );
  }
}

class SessionInfo {
  final String id;
  final String name;
  final String targetUrl;
  final String status;
  final String createdAt;
  final int trafficCount;
  final int apiCallCount;

  SessionInfo({
    required this.id,
    required this.name,
    required this.targetUrl,
    required this.status,
    required this.createdAt,
    this.trafficCount = 0,
    this.apiCallCount = 0,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      targetUrl: json['target_url'] ?? '',
      status: json['status'] ?? 'idle',
      createdAt: json['created_at'] ?? '',
      trafficCount: json['traffic_count'] ?? 0,
      apiCallCount: json['api_call_count'] ?? 0,
    );
  }
}
