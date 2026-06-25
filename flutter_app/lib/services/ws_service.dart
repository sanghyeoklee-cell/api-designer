import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsService {
  static const String _baseUrl = 'ws://127.0.0.1:8000';

  WebSocketChannel? _trafficChannel;
  WebSocketChannel? _analysisChannel;
  WebSocketChannel? _codegenChannel;
  WebSocketChannel? _manualChannel;

  final _trafficController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _analysisController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _codegenController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _manualController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get trafficStream => _trafficController.stream;
  Stream<Map<String, dynamic>> get analysisStream =>
      _analysisController.stream;
  Stream<Map<String, dynamic>> get codegenStream => _codegenController.stream;
  Stream<Map<String, dynamic>> get manualStream => _manualController.stream;

  void connectTraffic() {
    _trafficChannel?.sink.close();
    _trafficChannel =
        WebSocketChannel.connect(Uri.parse('$_baseUrl/ws/traffic'));
    _trafficChannel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _trafficController.add(json);
        } catch (_) {}
      },
      onError: (error) {
        // Will reconnect on next call
      },
      onDone: () {},
    );
  }

  void connectAnalysis() {
    _analysisChannel?.sink.close();
    _analysisChannel =
        WebSocketChannel.connect(Uri.parse('$_baseUrl/ws/analysis'));
    _analysisChannel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _analysisController.add(json);
        } catch (_) {}
      },
      onError: (error) {},
      onDone: () {},
    );
  }

  void connectCodegen() {
    _codegenChannel?.sink.close();
    _codegenChannel =
        WebSocketChannel.connect(Uri.parse('$_baseUrl/ws/codegen'));
    _codegenChannel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _codegenController.add(json);
        } catch (_) {}
      },
      onError: (error) {},
      onDone: () {},
    );
  }

  void connectManual() {
    _manualChannel?.sink.close();
    _manualChannel =
        WebSocketChannel.connect(Uri.parse('$_baseUrl/ws/manual'));
    _manualChannel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _manualController.add(json);
        } catch (_) {}
      },
      onError: (error) {},
      onDone: () {},
    );
  }

  void disconnectManual() {
    _manualChannel?.sink.close();
    _manualChannel = null;
  }

  void dispose() {
    _trafficChannel?.sink.close();
    _analysisChannel?.sink.close();
    _codegenChannel?.sink.close();
    _manualChannel?.sink.close();
    _trafficController.close();
    _analysisController.close();
    _codegenController.close();
    _manualController.close();
  }
}
