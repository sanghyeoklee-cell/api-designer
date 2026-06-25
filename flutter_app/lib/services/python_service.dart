import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum PythonStatus { stopped, starting, running, error }

class PythonService extends ChangeNotifier {
  Process? _process;
  PythonStatus _status = PythonStatus.stopped;
  String _log = '';
  String _errorMessage = '';
  String? _backendDir;
  String? _pythonPath;

  PythonStatus get status => _status;
  String get log => _log;
  String get errorMessage => _errorMessage;
  bool get isRunning => _status == PythonStatus.running;

  Future<void> start() async {
    if (_status == PythonStatus.running || _status == PythonStatus.starting) {
      return;
    }

    _status = PythonStatus.starting;
    _errorMessage = '';
    _log = '';
    notifyListeners();

    // Check if backend is already running (started externally)
    _appendLog('Checking for existing backend...');
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:8000/api/health'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        _status = PythonStatus.running;
        _appendLog('Backend already running (external).');
        notifyListeners();
        return;
      }
    } catch (_) {
      // Not running, we'll start it
    }

    // Find backend directory first (needed for venv python lookup)
    _backendDir = await _findBackendDir();
    if (_backendDir == null) {
      _status = PythonStatus.error;
      _errorMessage = 'Backend directory not found.';
      notifyListeners();
      return;
    }

    // Find Python (prefers venv in backend dir)
    _pythonPath = await _findPython();
    if (_pythonPath == null) {
      _status = PythonStatus.error;
      _errorMessage = 'Python3 not found. Please install Python 3.11+.';
      notifyListeners();
      return;
    }

    _appendLog('Python: $_pythonPath');
    _appendLog('Backend: $_backendDir');
    _appendLog('Starting server...');

    try {
      _process = await Process.start(
        _pythonPath!,
        ['main.py'],
        workingDirectory: _backendDir!,
        environment: Platform.environment,
      );

      // Capture stdout
      _process!.stdout.transform(utf8.decoder).listen((data) {
        _appendLog(data.trim());
      });

      // Capture stderr
      _process!.stderr.transform(utf8.decoder).listen((data) {
        _appendLog(data.trim());
      });

      // Handle process exit
      _process!.exitCode.then((code) {
        if (_status == PythonStatus.running || _status == PythonStatus.starting) {
          _status = PythonStatus.stopped;
          _appendLog('Backend process exited with code $code');
          notifyListeners();
        }
      });

      // Wait for health check
      final healthy = await _waitForHealth();
      if (healthy) {
        _status = PythonStatus.running;
        _appendLog('Backend is ready.');
      } else {
        _status = PythonStatus.error;
        _errorMessage = 'Backend started but health check failed.';
      }
    } catch (e) {
      _status = PythonStatus.error;
      _errorMessage = 'Failed to start backend: $e';
    }
    notifyListeners();
  }

  Future<void> stop() async {
    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
      // Give it a moment to shut down gracefully
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        _process!.kill(ProcessSignal.sigkill);
      } catch (_) {}
      _process = null;
    }
    _status = PythonStatus.stopped;
    _appendLog('Backend stopped.');
    notifyListeners();
  }

  Future<String?> _findPython() async {
    // Strategy 1: Use venv python inside backend dir (ensures matching arch).
    // Accept both `.venv` (convention) and `venv`.
    if (_backendDir != null) {
      for (final name in ['.venv', 'venv']) {
        final venvPython = '$_backendDir/$name/bin/python3';
        if (await File(venvPython).exists()) {
          return venvPython;
        }
      }
    }

    // Strategy 2: Prefer ARM Homebrew python on Apple Silicon
    for (final path in [
      '/opt/homebrew/bin/python3.12',
      '/opt/homebrew/bin/python3',
      '/usr/local/bin/python3',
      '/usr/bin/python3',
    ]) {
      if (await File(path).exists()) return path;
    }

    // Strategy 3: Fallback to PATH
    for (final cmd in ['python3', 'python']) {
      try {
        final result = await Process.run('which', [cmd]);
        if (result.exitCode == 0) {
          final path = (result.stdout as String).trim();
          final ver = await Process.run(path, ['--version']);
          if (ver.exitCode == 0) {
            return path;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<String?> _findBackendDir() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final cwd = Directory.current.path;

    // Strategy 1: Walk up from executable to find backend/main.py
    // Executable is at: .../flutter_app/build/macos/Build/Products/Debug/flutter_app.app/Contents/MacOS/
    // We need: .../api_studio/backend/
    var dir = Directory(exeDir);
    for (var i = 0; i < 15; i++) {
      final backendDir = Directory('${dir.path}/backend');
      final mainPy = File('${backendDir.path}/main.py');
      if (await mainPy.exists()) {
        return backendDir.absolute.path;
      }
      dir = dir.parent;
    }

    // Strategy 2: Common relative paths from current working directory
    final candidates = [
      '$cwd/../backend',
      '$cwd/backend',
      '$cwd/../../backend',
    ];

    for (final candidate in candidates) {
      final candidateDir = Directory(candidate);
      if (await candidateDir.exists()) {
        final mainPy = File('${candidateDir.path}/main.py');
        if (await mainPy.exists()) {
          return candidateDir.absolute.path;
        }
      }
    }
    return null;
  }

  Future<bool> _waitForHealth({int maxRetries = 20}) async {
    for (var i = 0; i < maxRetries; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final response = await http
            .get(Uri.parse('http://127.0.0.1:8000/api/health'))
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  void _appendLog(String line) {
    if (line.isEmpty) return;
    _log += '$line\n';
    // Keep last 200 lines
    final lines = _log.split('\n');
    if (lines.length > 200) {
      _log = lines.skip(lines.length - 200).join('\n');
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
