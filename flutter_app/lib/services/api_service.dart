import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import '../models/project.dart';

class ApiService {
  static const String _baseUrl = 'http://127.0.0.1:8000';

  // Health
  Future<Map<String, dynamic>> healthCheck() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/health'));
    return jsonDecode(response.body);
  }

  // Projects
  Future<Map<String, dynamic>> createProject(
      String name, String targetUrl, String description) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/project/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'target_url': targetUrl,
        'description': description,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create project');
    }
    return jsonDecode(response.body);
  }

  Future<List<ProjectInfo>> listProjects() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/projects/'));
    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => ProjectInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getProject(String projectId) async {
    final response =
        await http.get(Uri.parse('$_baseUrl/api/project/$projectId'));
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updateProject(
      String projectId, {String? name, String? targetUrl, String? description}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (targetUrl != null) body['target_url'] = targetUrl;
    if (description != null) body['description'] = description;

    final response = await http.put(
      Uri.parse('$_baseUrl/api/project/$projectId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update project');
    }
    return jsonDecode(response.body);
  }

  Future<void> deleteProject(String projectId) async {
    await http.delete(Uri.parse('$_baseUrl/api/project/$projectId'));
  }

  Future<Map<String, dynamic>> activateProject(String projectId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/project/$projectId/activate'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to activate project');
    }
    return jsonDecode(response.body);
  }

  // Settings
  Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/settings/'));
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updateSettings({
    String? apiKey,
    String? model,
  }) async {
    final body = <String, dynamic>{};
    if (apiKey != null) body['anthropic_api_key'] = apiKey;
    if (model != null) body['claude_model'] = model;

    final response = await http.put(
      Uri.parse('$_baseUrl/api/settings/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(
          jsonDecode(response.body)['detail'] ?? 'Settings update failed');
    }
    return jsonDecode(response.body);
  }

  // Browser
  Future<Map<String, dynamic>> launchBrowser(String url) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/browser/launch'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Launch failed');
    }
    return jsonDecode(response.body);
  }

  Future<void> closeBrowser() async {
    final response =
        await http.post(Uri.parse('$_baseUrl/api/browser/close'));
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Close failed');
    }
  }

  Future<Map<String, dynamic>> getBrowserStatus() async {
    final response =
        await http.get(Uri.parse('$_baseUrl/api/browser/status'));
    return jsonDecode(response.body);
  }

  // Session
  Future<Map<String, dynamic>> createSession(
      String name, String targetUrl) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/session/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'target_url': targetUrl}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create session');
    }
    return jsonDecode(response.body);
  }

  Future<void> startRecording(String sessionId) async {
    final response = await http
        .post(Uri.parse('$_baseUrl/api/session/start/$sessionId'));
    if (response.statusCode != 200) {
      throw Exception(
          jsonDecode(response.body)['detail'] ?? 'Start recording failed');
    }
  }

  Future<Map<String, dynamic>> stopRecording() async {
    final response =
        await http.post(Uri.parse('$_baseUrl/api/session/stop'));
    if (response.statusCode != 200) {
      throw Exception(
          jsonDecode(response.body)['detail'] ?? 'Stop recording failed');
    }
    return jsonDecode(response.body);
  }

  Future<List<SessionInfo>> listSessions() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/sessions/'));
    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => SessionInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final response =
        await http.get(Uri.parse('$_baseUrl/api/session/$sessionId'));
    return jsonDecode(response.body);
  }

  Future<void> deleteSession(String sessionId) async {
    await http.delete(Uri.parse('$_baseUrl/api/session/$sessionId'));
  }

  // Analysis
  Future<AnalysisResult> runAnalysis(String sessionId) async {
    final response = await http
        .post(Uri.parse('$_baseUrl/api/analysis/run/$sessionId'));
    if (response.statusCode != 200) {
      throw Exception(
          jsonDecode(response.body)['detail'] ?? 'Analysis failed');
    }
    return AnalysisResult.fromJson(jsonDecode(response.body));
  }

  Future<AnalysisResult?> getAnalysis(String sessionId) async {
    final response =
        await http.get(Uri.parse('$_baseUrl/api/analysis/$sessionId'));
    if (response.statusCode != 200) return null;
    return AnalysisResult.fromJson(jsonDecode(response.body));
  }

  // Code Generation
  Future<Map<String, dynamic>> generateCode({
    required String sessionId,
    required Map<String, String> userInputs,
    String projectName = 'generated_api',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/codegen/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'user_inputs': userInputs,
        'project_name': projectName,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
          jsonDecode(response.body)['detail'] ?? 'Code generation failed');
    }
    return jsonDecode(response.body);
  }

  Future<Map<String, String>> getGeneratedFiles(String sessionId) async {
    final response =
        await http.get(Uri.parse('$_baseUrl/api/codegen/$sessionId/files'));
    if (response.statusCode != 200) return {};
    final data = jsonDecode(response.body);
    return Map<String, String>.from(data['files'] ?? {});
  }

  // Manual mode
  Future<Map<String, dynamic>> startManual(String targetUrl,
      {String name = ''}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/manual/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'target_url': targetUrl, 'name': name}),
    );
    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body);
        throw Exception(body['detail'] ?? 'Failed to start manual recording');
      } catch (e) {
        if (e is Exception && e.toString().contains('Exception:')) rethrow;
        throw Exception(
            'Failed to start manual recording (${response.statusCode})');
      }
    }
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> stopManual() async {
    final response =
        await http.post(Uri.parse('$_baseUrl/api/manual/stop'));
    if (response.statusCode != 200) {
      throw Exception(
          jsonDecode(response.body)['detail'] ?? 'Stop manual failed');
    }
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> triggerManualSnapshot() async {
    final response =
        await http.post(Uri.parse('$_baseUrl/api/manual/snapshot'));
    if (response.statusCode != 200) {
      throw Exception('Failed to capture snapshot');
    }
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getManualState() async {
    final response =
        await http.get(Uri.parse('$_baseUrl/api/manual/state'));
    return jsonDecode(response.body);
  }
}
