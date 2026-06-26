import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/analysis_result.dart';
import '../models/manual_models.dart';
import '../models/project.dart';
import '../models/traffic_entry.dart';
import 'api_service.dart';
import 'python_service.dart';
import 'ws_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api = ApiService();
  final WsService ws = WsService();
  final PythonService python = PythonService();

  // Settings
  bool apiKeySet = false;
  String apiKeyMasked = '';
  String claudeModel = '';
  List<String> availableModels = [];

  // Project state
  List<ProjectInfo> projects = [];
  String? activeProjectId;
  String? activeProjectName;

  // State
  bool backendConnected = false;
  bool browserRunning = false;
  bool recording = false;
  String? activeSessionId;
  String? activeSessionName;
  List<SessionInfo> sessions = [];
  List<TrafficEntry> liveTraffic = [];
  AnalysisResult? analysisResult;
  Map<String, String> generatedFiles = {};
  String? error;
  bool loading = false;
  String loadingMessage = '';

  // Codegen streaming state
  bool codegenStreaming = false;
  Map<String, String> streamingFiles = {};  // filename -> accumulated content
  List<String> streamingFileOrder = [];     // order files were created
  String? codegenCurrentFile;

  // Manual mode state
  bool manualActive = false;
  String? manualSessionId;
  String? manualSessionName;
  List<TrafficEntry> manualTraffic = [];
  List<HtmlSnapshot> manualSnapshots = [];
  Map<String, dynamic>? manualDialog; // current dialog info

  StreamSubscription? _trafficSub;
  StreamSubscription? _codegenSub;
  StreamSubscription? _manualSub;

  AppState() {
    python.addListener(_onPythonChange);
  }

  void _onPythonChange() {
    if (python.isRunning && !backendConnected) {
      init();
    }
    notifyListeners();
  }

  Future<void> startBackend() async {
    await python.start();
    if (python.isRunning) {
      await init();
    }
  }

  Future<void> init() async {
    try {
      final health = await api.healthCheck();
      backendConnected = true;
      browserRunning = health['browser_running'] ?? false;
      apiKeySet = health['api_key_set'] ?? false;
      claudeModel = health['claude_model'] ?? '';
      await refreshSettings();
      await refreshProjects();
    } catch (_) {
      backendConnected = false;
    }
    notifyListeners();
  }

  // ─── Project methods ─────────────────────────────────────

  Future<void> refreshProjects() async {
    try {
      projects = await api.listProjects();
    } catch (_) {
      projects = [];
    }
    notifyListeners();
  }

  Future<String?> createProject(String name, String targetUrl, String description) async {
    try {
      final result = await api.createProject(name, targetUrl, description);
      await refreshProjects();
      return result['id'] as String?;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> activateProject(String projectId) async {
    try {
      await api.activateProject(projectId);
      activeProjectId = projectId;
      // Find the project name
      final project = projects.firstWhere(
        (p) => p.id == projectId,
        orElse: () => ProjectInfo(id: projectId, name: '', createdAt: '', updatedAt: ''),
      );
      activeProjectName = project.name;
      // Refresh sessions for this project
      await refreshSessions();
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteProject(String projectId) async {
    try {
      await api.deleteProject(projectId);
      if (activeProjectId == projectId) {
        activeProjectId = null;
        activeProjectName = null;
        sessions = [];
      }
      await refreshProjects();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void leaveProject() {
    activeProjectId = null;
    activeProjectName = null;
    sessions = [];
    activeSessionId = null;
    activeSessionName = null;
    liveTraffic = [];
    analysisResult = null;
    generatedFiles = {};
    notifyListeners();
  }

  Future<void> refreshSettings() async {
    try {
      final data = await api.getSettings();
      apiKeySet = data['anthropic_api_key_set'] ?? false;
      apiKeyMasked = data['anthropic_api_key_masked'] ?? '';
      claudeModel = data['claude_model'] ?? '';
      availableModels = List<String>.from(data['available_models'] ?? []);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateSettings({String? apiKey, String? model}) async {
    try {
      final data = await api.updateSettings(apiKey: apiKey, model: model);
      apiKeySet = data['anthropic_api_key_set'] ?? false;
      apiKeyMasked = data['anthropic_api_key_masked'] ?? '';
      claudeModel = data['claude_model'] ?? '';
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> refreshSessions() async {
    try {
      sessions = await api.listSessions();
    } catch (_) {
      sessions = [];
    }
    notifyListeners();
  }

  Future<void> launchBrowser(String url) async {
    _setLoading(true, 'Launching browser...');
    try {
      await api.launchBrowser(url);
      browserRunning = true;
      error = null;
    } catch (e) {
      error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> closeBrowser() async {
    try {
      await api.closeBrowser();
      browserRunning = false;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> createAndStartRecording(String name, String url) async {
    _setLoading(true, 'Starting recording...');
    try {
      final result = await api.createSession(name, url);
      activeSessionId = result['session_id'];
      activeSessionName = result['name'];
      await api.startRecording(activeSessionId!);
      recording = true;
      liveTraffic.clear();
      error = null;

      ensureTrafficSubscription();
    } catch (e) {
      error = e.toString();
    }
    _setLoading(false);
  }

  Future<Map<String, dynamic>?> stopRecording() async {
    _setLoading(true, 'Stopping recording...');
    Map<String, dynamic>? result;
    try {
      result = await api.stopRecording();
      recording = false;
      _trafficSub?.cancel();
      _trafficSub = null;
      await refreshSessions();
      error = null;
    } catch (e) {
      error = e.toString();
    }
    _setLoading(false);
    return result;
  }

  Future<void> runAnalysis(String sessionId) async {
    _setLoading(true, 'Analyzing traffic with Claude...');
    ws.connectAnalysis();
    try {
      analysisResult = await api.runAnalysis(sessionId);
      error = null;
    } catch (e) {
      error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> generateCode(
      String sessionId, Map<String, String> userInputs, String projectName,
      [String target = 'fastapi']) async {
    // Setup streaming state
    codegenStreaming = true;
    streamingFiles = {};
    streamingFileOrder = [];
    codegenCurrentFile = null;
    notifyListeners();

    // Connect codegen WebSocket before starting generation
    ws.connectCodegen();
    _codegenSub?.cancel();
    _codegenSub = ws.codegenStream.listen(_handleCodegenMessage);

    _setLoading(true, 'Generating API server code...');
    try {
      await api.generateCode(
        sessionId: sessionId,
        userInputs: userInputs,
        projectName: projectName,
        target: target,
      );
      generatedFiles = Map<String, String>.from(streamingFiles);
      error = null;
    } catch (e) {
      error = e.toString();
    }
    codegenStreaming = false;
    _codegenSub?.cancel();
    _codegenSub = null;
    _setLoading(false);
  }

  void _handleCodegenMessage(Map<String, dynamic> data) {
    final type = data['type'];
    final msgData = data['data'] as Map<String, dynamic>?;
    if (msgData == null) return;

    if (type == 'file_start') {
      final filename = msgData['filename'] as String;
      codegenCurrentFile = filename;
      if (!streamingFiles.containsKey(filename)) {
        streamingFiles[filename] = '';
        streamingFileOrder.add(filename);
      }
    } else if (type == 'chunk') {
      final filename = msgData['filename'] as String;
      final text = msgData['text'] as String;
      streamingFiles[filename] = (streamingFiles[filename] ?? '') + text;
    } else if (type == 'complete') {
      codegenStreaming = false;
    }
    notifyListeners();
  }

  void ensureTrafficSubscription() {
    if (_trafficSub != null) return;
    ws.connectTraffic();
    _trafficSub = ws.trafficStream.listen((data) {
      if (data['type'] == 'traffic' && data['data'] != null) {
        liveTraffic
            .add(TrafficEntry.fromJson(data['data'] as Map<String, dynamic>));
        notifyListeners();
      }
    });
  }

  // ─── Manual mode methods ─────────────────────────────

  Future<void> startManualRecording(String url, {String name = ''}) async {
    manualActive = false;
    manualTraffic = [];
    manualSnapshots = [];
    manualSessionId = null;
    manualSessionName = null;
    error = null;
    notifyListeners();

    _setLoading(true, 'Launching browser...');

    // Connect manual WebSocket before starting
    ws.connectManual();
    _manualSub?.cancel();
    _manualSub = ws.manualStream.listen(_handleManualMessage);

    try {
      final result = await api.startManual(url, name: name);
      manualSessionId = result['session_id'];
      manualSessionName = result['name'];
      manualActive = true;
      browserRunning = true;
    } catch (e) {
      error = e.toString();
      _manualSub?.cancel();
      _manualSub = null;
      ws.disconnectManual();
    }
    _setLoading(false);
  }

  void _handleManualMessage(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'traffic' && data['data'] != null) {
      manualTraffic
          .add(TrafficEntry.fromJson(data['data'] as Map<String, dynamic>));
    } else if (type == 'snapshot' && data['data'] != null) {
      manualSnapshots
          .add(HtmlSnapshot.fromJson(data['data'] as Map<String, dynamic>));
    } else if (type == 'dialog' && data['data'] != null) {
      manualDialog = data['data'] as Map<String, dynamic>;
      // Auto-clear dialog notification after 6 seconds
      Future.delayed(const Duration(seconds: 6), () {
        if (manualDialog == data['data']) {
          manualDialog = null;
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> stopManualRecording() async {
    _setLoading(true, 'Stopping recording...');
    Map<String, dynamic>? result;
    try {
      result = await api.stopManual();
      manualActive = false;
      _manualSub?.cancel();
      _manualSub = null;
      ws.disconnectManual();
      await refreshSessions();
      error = null;
    } catch (e) {
      error = e.toString();
    }
    _setLoading(false);
    return result;
  }

  void resetManualState() {
    manualTraffic.clear();
    manualSnapshots.clear();
    manualSessionId = null;
    manualSessionName = null;
    manualDialog = null;
    notifyListeners();
  }

  Future<void> triggerManualSnapshot() async {
    try {
      await api.triggerManualSnapshot();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void _setLoading(bool value, [String message = '']) {
    loading = value;
    loadingMessage = message;
    notifyListeners();
  }

  /// Graceful shutdown: close browser, stop backend, report progress via callback.
  Future<void> shutdown({void Function(String status)? onProgress}) async {
    // 1. Close browser if running
    if (browserRunning) {
      onProgress?.call('Closing browser...');
      try {
        await api.closeBrowser();
        browserRunning = false;
      } catch (_) {}
    }

    // 2. Stop backend Python process
    onProgress?.call('Stopping backend server...');
    await python.stop();

    onProgress?.call('Done');
  }

  @override
  void dispose() {
    python.removeListener(_onPythonChange);
    _trafficSub?.cancel();
    _codegenSub?.cancel();
    _manualSub?.cancel();
    ws.dispose();
    python.dispose();
    super.dispose();
  }
}
