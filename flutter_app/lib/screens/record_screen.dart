import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/traffic_list.dart';
import 'analysis_screen.dart';

class RecordScreen extends StatefulWidget {
  final String sessionId;
  const RecordScreen({super.key, required this.sessionId});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  bool _resuming = false;

  String get sessionId => widget.sessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoResume();
    });
  }

  Future<void> _autoResume() async {
    final state = context.read<AppState>();
    // If browser isn't running but we have a session, relaunch
    if (!state.browserRunning && !state.recording) {
      setState(() => _resuming = true);
      try {
        final sessionData = await state.api.getSession(sessionId);
        final url = sessionData['target_url'] ?? '';
        if (url.isNotEmpty) {
          await state.launchBrowser(url);
          await state.api.startRecording(sessionId);
          state.recording = true;
          state.activeSessionId = sessionId;
          state.liveTraffic.clear();
          state.ensureTrafficSubscription();
        }
      } catch (_) {
        // Will show error via state.error
      }
      if (mounted) setState(() => _resuming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          // Header bar
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  state.activeSessionName ?? 'Recording',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (state.recording) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text('REC',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                // Stats
                _Stat(
                    label: '${state.liveTraffic.length}',
                    sublabel: 'requests'),
                const SizedBox(width: 16),
                _Stat(
                  label:
                      '${state.liveTraffic.where((e) => e.responseStatus > 0).length}',
                  sublabel: 'responses',
                ),
                const SizedBox(width: 20),
                // Actions
                if (state.recording)
                  _ActionButton(
                    label: 'Stop',
                    icon: Icons.stop_rounded,
                    color: const Color(0xFFDC2626),
                    onTap: state.loading
                        ? null
                        : () async {
                            await state.stopRecording();
                          },
                  ),
                if (!state.recording && state.liveTraffic.isNotEmpty)
                  _ActionButton(
                    label: 'Analyze',
                    icon: Icons.auto_awesome,
                    color: const Color(0xFF4F46E5),
                    onTap: state.loading
                        ? null
                        : () async {
                            await state.runAnalysis(sessionId);
                            if (state.analysisResult != null &&
                                context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AnalysisScreen(sessionId: sessionId),
                                ),
                              );
                            }
                          },
                  ),
              ],
            ),
          ),

          // Loading bar
          if (state.loading || _resuming)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFFF0F4FF),
              child: Row(
                children: [
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text(_resuming ? 'Resuming session...' : state.loadingMessage,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF4F46E5))),
                ],
              ),
            ),

          // Error bar
          if (state.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFFFEF2F2),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 15, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(state.error!,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFFDC2626))),
                  ),
                  GestureDetector(
                    onTap: state.clearError,
                    child: const Icon(Icons.close,
                        size: 14, color: Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),

          // Traffic list
          Expanded(
            child: TrafficList(
              entries: state.liveTraffic,
              onTap: (entry) => _showDetail(context, entry),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, dynamic entry) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 640,
          height: 520,
          child: Column(
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
                ),
                child: Row(
                  children: [
                    _MethodBadge(method: entry.requestMethod),
                    const SizedBox(width: 10),
                    _StatusBadge(status: entry.responseStatus),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.requestUrl,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Color(0xFF6B7280)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Tabs
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        labelStyle: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        tabs: [
                          Tab(text: 'Request'),
                          Tab(text: 'Response'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _DetailPane(
                              headers: entry.requestHeaders,
                              body: entry.requestBody,
                            ),
                            _DetailPane(
                              headers: entry.responseHeaders,
                              body: entry.responseBody,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String sublabel;
  const _Stat({required this.label, required this.sublabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E2E))),
        Text(sublabel,
            style:
                const TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 13),
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  final String method;
  const _MethodBadge({required this.method});

  Color get _color {
    switch (method.toUpperCase()) {
      case 'GET':
        return const Color(0xFF2563EB);
      case 'POST':
        return const Color(0xFF059669);
      case 'PUT':
        return const Color(0xFFF59E0B);
      case 'DELETE':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(method,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _color,
              letterSpacing: 0.3)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final int status;
  const _StatusBadge({required this.status});

  Color get _color {
    if (status >= 200 && status < 300) return const Color(0xFF059669);
    if (status >= 300 && status < 400) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return Text('$status',
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: _color));
  }
}

class _DetailPane extends StatelessWidget {
  final Map<String, String> headers;
  final String? body;
  const _DetailPane({required this.headers, this.body});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Headers',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E8E93))),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              headers.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Body',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E8E93))),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              body ?? '(empty)',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
