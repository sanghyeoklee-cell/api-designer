import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/dynamic_form.dart';
import 'codegen_screen.dart';

class AnalysisScreen extends StatefulWidget {
  final String sessionId;
  const AnalysisScreen({super.key, required this.sessionId});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _projectNameController = TextEditingController(text: 'generated_api');

  @override
  void dispose() {
    _projectNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final analysis = state.analysisResult;

    if (analysis == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: Column(
          children: [
            _header(context, 'Analysis'),
            const Expanded(
                child: Center(child: Text('No analysis result'))),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          _header(context, 'Analysis Result'),
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column: analysis info
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary
                        _Card(
                          title: 'Summary',
                          icon: Icons.description_outlined,
                          iconColor: const Color(0xFF4F46E5),
                          child: Text(analysis.summary,
                              style: const TextStyle(
                                  fontSize: 13.5, height: 1.5)),
                        ),
                        const SizedBox(height: 14),

                        // Endpoints
                        _Card(
                          title: 'Endpoints (${analysis.endpoints.length})',
                          icon: Icons.route_outlined,
                          iconColor: const Color(0xFF059669),
                          child: Column(
                            children: analysis.endpoints
                                .map((ep) => _EndpointRow(ep: ep))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Auth
                        _Card(
                          title: 'Authentication',
                          icon: Icons.lock_outline,
                          iconColor: const Color(0xFFF59E0B),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Pill(text: analysis.authMethod),
                              if (analysis.authDetails.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ...analysis.authDetails.entries.map(
                                  (e) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      '${e.key}: ${e.value}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF6B7280)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right column: form + generate
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Card(
                          title: 'Generate API Server',
                          icon: Icons.code,
                          iconColor: const Color(0xFF7C3AED),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _projectNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Project name',
                                  hintText: 'generated_api',
                                ),
                              ),
                              if (analysis
                                  .formSchema.fields.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                DynamicForm(
                                  formSchema: analysis.formSchema,
                                  onSubmit: (v) =>
                                      _generateCode(context, v),
                                ),
                              ] else ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: state.loading
                                        ? null
                                        : () =>
                                            _generateCode(context, {}),
                                    child: const Text('Generate'),
                                  ),
                                ),
                              ],
                            ],
                          ),
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
    );
  }

  Widget _header(BuildContext context, String title) {
    return Container(
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
            style:
                IconButton.styleFrom(foregroundColor: const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 4),
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _generateCode(
      BuildContext context, Map<String, String> values) async {
    final state = context.read<AppState>();
    final projectName = _projectNameController.text.trim().isEmpty
        ? 'generated_api'
        : _projectNameController.text.trim();

    // Navigate to codegen screen immediately to show streaming
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CodegenScreen(sessionId: widget.sessionId),
        ),
      );
    }

    // Start generation (runs in background, streams via WebSocket)
    await state.generateCode(widget.sessionId, values, projectName);
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _Card({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E2E))),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  final dynamic ep;
  const _EndpointRow({required this.ep});

  Color _methodColor(String m) {
    switch (m.toUpperCase()) {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: _methodColor(ep.method).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              ep.method,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _methodColor(ep.method),
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(ep.url,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF3C3C43))),
          ),
          if (ep.authRequired)
            const Icon(Icons.lock, size: 13, color: Color(0xFFF59E0B)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF92400E))),
    );
  }
}
