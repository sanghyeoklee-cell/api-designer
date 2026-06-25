import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/manual_models.dart';
import '../services/app_state.dart';
import '../widgets/traffic_list.dart';
import 'analysis_screen.dart';

class ManualScreen extends StatefulWidget {
  const ManualScreen({super.key});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  int? _selectedSnapshotIndex;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.manualActive ||
        (state.manualSessionId != null && state.manualTraffic.isNotEmpty)) {
      return _buildRecordingView(context, state);
    }
    return _buildStartView(context, state);
  }

  Widget _buildStartView(BuildContext context, AppState state) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Center(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.touch_app,
                        color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manual Mode',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('Browse freely, capture everything',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF8E8E93))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Target URL',
                  hintText: 'https://example.com',
                  prefixIcon: Icon(Icons.language, size: 18),
                ),
                onSubmitted: (_) => _startRecording(state),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Session name (optional)',
                  hintText: 'My session',
                  prefixIcon: Icon(Icons.label_outline, size: 18),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Color(0xFF6B7280)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Browser will open and you can browse freely.\n'
                        'All HTTP traffic and HTML elements will be captured automatically.',
                        style: TextStyle(
                            fontSize: 12.5, color: Color(0xFF6B7280), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (state.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 15, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(state.error!,
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFFDC2626))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: state.loading ? null : () => _startRecording(state),
                  icon: state.loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow, size: 18),
                  label: Text(state.loading ? 'Starting...' : 'Start Recording'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startRecording(AppState state) {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final normalizedUrl =
        url.startsWith('http') ? url : 'https://$url';
    state.startManualRecording(normalizedUrl, name: _nameController.text.trim());
  }

  Widget _buildRecordingView(BuildContext context, AppState state) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          // Header bar
          _buildHeader(context, state),

          // Loading bar
          if (state.loading)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFFF0F4FF),
              child: Row(
                children: [
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text(state.loadingMessage,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF4F46E5))),
                ],
              ),
            ),

          // Dialog notification banner
          if (state.manualDialog != null)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFFFFF7ED),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 15, color: Color(0xFFEA580C)),
                  const SizedBox(width: 8),
                  Text(
                    '[${state.manualDialog!['type'] ?? 'dialog'}] ',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEA580C)),
                  ),
                  Expanded(
                    child: Text(
                      state.manualDialog!['message'] ?? '',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF9A3412)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Error bar
          if (state.error != null)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

          // Main content: Traffic + Snapshots
          Expanded(
            child: Row(
              children: [
                // Left: Traffic list
                Expanded(
                  flex: 3,
                  child: TrafficList(
                    entries: state.manualTraffic,
                    onTap: (entry) => _showTrafficDetail(context, entry),
                  ),
                ),
                // Right: DOM snapshots panel
                Expanded(
                  flex: 2,
                  child: _SnapshotPanel(
                    snapshots: state.manualSnapshots,
                    selectedIndex: _selectedSnapshotIndex,
                    onSelect: (i) =>
                        setState(() => _selectedSnapshotIndex = i),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState state) {
    final apiCount = state.manualTraffic
        .where((e) => !_isStaticResource(e.requestUrl))
        .length;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app, size: 18, color: Color(0xFF059669)),
          const SizedBox(width: 8),
          Text(
            state.manualSessionName ?? 'Manual Recording',
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (state.manualActive) ...[
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
              label: '${state.manualTraffic.length}', sublabel: 'requests'),
          const SizedBox(width: 12),
          _Stat(label: '$apiCount', sublabel: 'API calls'),
          const SizedBox(width: 12),
          _Stat(
              label: '${state.manualSnapshots.length}',
              sublabel: 'snapshots'),
          const SizedBox(width: 16),
          // Actions
          if (state.manualActive) ...[
            _ActionButton(
              label: 'Snapshot',
              icon: Icons.camera_alt_outlined,
              color: const Color(0xFF2563EB),
              onTap: state.loading
                  ? null
                  : () => state.triggerManualSnapshot(),
            ),
            const SizedBox(width: 8),
            _ActionButton(
              label: 'Stop',
              icon: Icons.stop_rounded,
              color: const Color(0xFFDC2626),
              onTap: state.loading
                  ? null
                  : () async {
                      await state.stopManualRecording();
                    },
            ),
          ],
          if (!state.manualActive &&
              state.manualSessionId != null) ...[
            _ActionButton(
              label: 'New',
              icon: Icons.refresh,
              color: const Color(0xFF6B7280),
              onTap: () {
                setState(() {
                  _selectedSnapshotIndex = null;
                });
                state.resetManualState();
              },
            ),
            const SizedBox(width: 8),
            _ActionButton(
              label: 'Analyze',
              icon: Icons.auto_awesome,
              color: const Color(0xFF4F46E5),
              onTap: state.loading
                  ? null
                  : () async {
                      await state.runAnalysis(state.manualSessionId!);
                      if (state.analysisResult != null &&
                          context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnalysisScreen(
                                sessionId: state.manualSessionId!),
                          ),
                        );
                      }
                    },
            ),
          ],
        ],
      ),
    );
  }

  bool _isStaticResource(String url) {
    final lower = url.toLowerCase();
    const exts = [
      '.js', '.css', '.png', '.jpg', '.jpeg', '.gif', '.svg',
      '.ico', '.woff', '.woff2', '.ttf', '.eot', '.mp4', '.webp',
    ];
    return exts.any((ext) => lower.contains(ext));
  }

  void _showTrafficDetail(BuildContext context, dynamic entry) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 640,
          height: 520,
          child: Column(
            children: [
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

// ─── Snapshot Panel ───────────────────────────────────

class _SnapshotPanel extends StatelessWidget {
  final List<HtmlSnapshot> snapshots;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  const _SnapshotPanel({
    required this.snapshots,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE5E5EA))),
      ),
      child: Column(
        children: [
          // Panel header
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Text(
                  'DOM Snapshots (${snapshots.length})',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E2E)),
                ),
              ],
            ),
          ),
          if (snapshots.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        size: 32, color: Color(0xFFD1D5DB)),
                    SizedBox(height: 8),
                    Text('No snapshots yet',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF9CA3AF))),
                    SizedBox(height: 4),
                    Text('DOM will be captured automatically',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFFD1D5DB))),
                  ],
                ),
              ),
            )
          else ...[
            // Snapshot list
            SizedBox(
              height: 160,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: snapshots.length,
                itemBuilder: (ctx, i) {
                  final snap = snapshots[i];
                  final isSelected = selectedIndex == i;
                  return InkWell(
                    onTap: () => onSelect(i),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF0F4FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: isSelected
                            ? Border.all(color: const Color(0xFF818CF8))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 14,
                            color: isSelected
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  snap.title.isNotEmpty
                                      ? snap.title
                                      : snap.shortUrl,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: const Color(0xFF1E1E2E),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  snap.url,
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF9CA3AF)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            snap.timeOnly,
                            style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF9CA3AF),
                                fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E5EA)),
            // Snapshot HTML viewer
            Expanded(
              child: _SnapshotViewer(
                snapshot: selectedIndex != null &&
                        selectedIndex! < snapshots.length
                    ? snapshots[selectedIndex!]
                    : (snapshots.isNotEmpty ? snapshots.last : null),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SnapshotViewer extends StatelessWidget {
  final HtmlSnapshot? snapshot;

  const _SnapshotViewer({this.snapshot});

  @override
  Widget build(BuildContext context) {
    if (snapshot == null) {
      return const Center(
        child: Text('Select a snapshot to view',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Viewer header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  snapshot!.url,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF6B7280)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: snapshot!.html));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('HTML copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: const Icon(Icons.copy, size: 14, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
        // HTML content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              snapshot!.html,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.5,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Shared sub-widgets ──────────────────────────────

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
