import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'record_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border:
                  Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
            ),
            child: Row(
              children: [
                const Text(
                  'Sessions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E1E2E),
                  ),
                ),
                const Spacer(),
                if (!state.backendConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Waiting for backend...',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  )
                else
                  _AddButton(onTap: () => _showNewSessionDialog(context)),
              ],
            ),
          ),

          // Content
          Expanded(
            child: !state.backendConnected
                ? _buildWaiting(context, state)
                : state.sessions.isEmpty
                    ? _buildEmpty(context)
                    : _buildList(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting(BuildContext context, AppState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'Starting backend server...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3C3C43),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.python.errorMessage.isNotEmpty
                ? state.python.errorMessage
                : 'This may take a moment',
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF8E8E93)),
          ),
          if (state.python.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => state.startBackend(),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                const Icon(Icons.web, size: 28, color: Color(0xFF818CF8)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No sessions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E2E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a session to start capturing API traffic.',
            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showNewSessionDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, AppState state) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: state.sessions.length,
      itemBuilder: (context, index) {
        final session = state.sessions[index];
        return _SessionCard(
          session: session,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordScreen(sessionId: session.id),
              ),
            );
          },
          onDelete: () {
            state.api.deleteSession(session.id).then((_) {
              state.refreshSessions();
            });
          },
        );
      },
    );
  }

  void _showNewSessionDialog(BuildContext context) {
    final urlController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 440,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Session',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter the target website URL to begin capturing traffic.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: urlController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Target URL',
                    hintText: 'https://example.com',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Session name (optional)',
                    hintText: 'e.g. Naver Login Flow',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        var url = urlController.text.trim();
                        var name = nameController.text.trim();
                        if (url.isEmpty) return;

                        // Auto-detect: if name looks like URL and url doesn't, swap them
                        final urlPattern = RegExp(r'^https?://');
                        if (!urlPattern.hasMatch(url) && urlPattern.hasMatch(name)) {
                          final tmp = url;
                          url = name;
                          name = tmp;
                        }
                        // Auto-add https:// if missing
                        if (!url.startsWith('http://') && !url.startsWith('https://')) {
                          url = 'https://$url';
                        }

                        Navigator.pop(ctx);

                        final state = context.read<AppState>();
                        if (!state.browserRunning) {
                          await state.launchBrowser(url);
                        }
                        await state.createAndStartRecording(
                          name.isEmpty ? url : name,
                          url,
                        );
                        if (state.activeSessionId != null &&
                            context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecordScreen(
                                  sessionId: state.activeSessionId!),
                            ),
                          );
                        }
                      },
                      child: const Text('Start Recording'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 16),
      label: const Text('New Session'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 13),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final dynamic session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E5EA)),
            ),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _statusBgColor(session.status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _statusIcon(session.status),
                    size: 18,
                    color: _statusFgColor(session.status),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E1E2E),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        session.targetUrl,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF8E8E93)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Stats
                _StatChip(
                    label: '${session.apiCallCount} calls',
                    icon: Icons.swap_vert),
                const SizedBox(width: 8),
                _StatusBadge(status: session.status),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz,
                      size: 18, color: Color(0xFF8E8E93)),
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'recording':
        return Icons.fiber_manual_record;
      case 'stopped':
        return Icons.stop_circle_outlined;
      case 'analyzing':
        return Icons.hourglass_top;
      case 'analyzed':
        return Icons.analytics_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _statusBgColor(String s) {
    switch (s) {
      case 'recording':
        return const Color(0xFFFEE2E2);
      case 'analyzed':
        return const Color(0xFFDBEAFE);
      case 'completed':
        return const Color(0xFFD1FAE5);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _statusFgColor(String s) {
    switch (s) {
      case 'recording':
        return const Color(0xFFDC2626);
      case 'analyzed':
        return const Color(0xFF2563EB);
      case 'completed':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _fgColor),
      ),
    );
  }

  Color get _bgColor {
    switch (status) {
      case 'recording':
        return const Color(0xFFFEE2E2);
      case 'analyzed':
        return const Color(0xFFDBEAFE);
      case 'completed':
        return const Color(0xFFD1FAE5);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color get _fgColor {
    switch (status) {
      case 'recording':
        return const Color(0xFFDC2626);
      case 'analyzed':
        return const Color(0xFF2563EB);
      case 'completed':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
