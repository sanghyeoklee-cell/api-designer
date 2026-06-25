import 'form_schema.dart';

class Endpoint {
  final String url;
  final String method;
  final String description;
  final bool authRequired;

  Endpoint({
    required this.url,
    required this.method,
    this.description = '',
    this.authRequired = false,
  });

  factory Endpoint.fromJson(Map<String, dynamic> json) {
    return Endpoint(
      url: json['url'] ?? '',
      method: json['method'] ?? 'GET',
      description: json['description'] ?? '',
      authRequired: json['auth_required'] ?? false,
    );
  }
}

class AnalysisResult {
  final String sessionId;
  final List<Endpoint> endpoints;
  final String authMethod;
  final Map<String, dynamic> authDetails;
  final FormSchema formSchema;
  final String summary;

  AnalysisResult({
    required this.sessionId,
    this.endpoints = const [],
    this.authMethod = 'none',
    this.authDetails = const {},
    required this.formSchema,
    this.summary = '',
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      sessionId: json['session_id'] ?? '',
      endpoints: (json['endpoints'] as List<dynamic>?)
              ?.map((e) => Endpoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      authMethod: json['auth_method'] ?? 'none',
      authDetails: Map<String, dynamic>.from(json['auth_details'] ?? {}),
      formSchema: FormSchema.fromJson(
          json['form_schema'] as Map<String, dynamic>? ?? {}),
      summary: json['summary'] ?? '',
    );
  }
}
