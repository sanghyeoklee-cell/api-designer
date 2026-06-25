import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../services/app_state.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Header
              Row(
                children: [
                  const Icon(Icons.api, color: Color(0xFF818CF8), size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'API Studio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  if (state.backendConnected)
                    _IconBtn(
                      icon: Icons.settings_outlined,
                      onTap: () => _openSettings(context),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select a project or create a new one to start.',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Backend status / Content
              Expanded(
                child: !state.backendConnected
                    ? _buildWaiting(state)
                    : state.projects.isEmpty
                        ? _buildEmpty()
                        : _buildProjectGrid(state),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: state.backendConnected
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New Project'),
              backgroundColor: const Color(0xFF818CF8),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildWaiting(AppState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF818CF8),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Starting backend server...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFFA1A1AA),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.python.errorMessage.isNotEmpty
                ? state.python.errorMessage
                : 'This may take a moment',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          if (state.python.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => state.startBackend(),
              child: const Text('Retry',
                  style: TextStyle(color: Color(0xFF818CF8))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D3F),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.folder_open,
                size: 32, color: Color(0xFF818CF8)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No projects yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a project to start capturing and analyzing APIs.',
            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectGrid(AppState state) {
    return ListView.builder(
      itemCount: state.projects.length,
      itemBuilder: (context, index) {
        final project = state.projects[index];
        return _ProjectCard(
          project: project,
          onTap: () async {
            await state.activateProject(project.id);
          },
          onDelete: () => _confirmDelete(context, state, project),
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF818CF8),
            brightness: Brightness.dark,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1E1E2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3D3D50)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3D3D50)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF818CF8)),
            ),
            labelStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
            hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        child: AlertDialog(
          backgroundColor: const Color(0xFF2D2D3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('New Project',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a project to organize your API analysis work.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Project Name',
                    hintText: 'e.g. Naver API, Shopping Mall Backend',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Target URL (optional)',
                    hintText: 'https://example.com',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'What are you trying to reverse-engineer?',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF8E8E93))),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);

                final state = context.read<AppState>();
                final projectId = await state.createProject(
                  name,
                  urlController.text.trim(),
                  descController.text.trim(),
                );
                if (projectId != null && context.mounted) {
                  await state.activateProject(projectId);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF818CF8),
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppState state, ProjectInfo project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D3F),
        title: const Text('Delete Project',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${project.name}"? This will remove all sessions and generated code.',
          style: const TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              state.deleteProject(project.id);
            },
            child:
                const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    // Navigate to settings within project list context
    showDialog(
      context: context,
      builder: (ctx) {
        final state = context.watch<AppState>();
        return Dialog(
          backgroundColor: const Color(0xFF2D2D3F),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: SizedBox(
            width: 480,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  _SettingsApiKeyField(state: state),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close',
                          style: TextStyle(color: Color(0xFF818CF8))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProjectCard extends StatefulWidget {
  final ProjectInfo project;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _hovered ? const Color(0xFF353548) : const Color(0xFF2D2D3F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered
                    ? const Color(0xFF818CF8).withValues(alpha: 0.5)
                    : const Color(0xFF3D3D50),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder,
                      color: Color(0xFF818CF8), size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.project.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.project.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.project.description,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF8E8E93)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (widget.project.targetUrl.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.project.targetUrl,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.project.sessionCount} sessions',
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: Color(0xFF6B7280)),
                  color: const Color(0xFF2D2D3F),
                  onSelected: (v) {
                    if (v == 'delete') widget.onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
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

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: const Color(0xFF8E8E93)),
      splashRadius: 18,
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool autofocus;
  final int maxLines;

  const _DarkTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.autofocus = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3D3D50)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3D3D50)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF818CF8)),
        ),
      ),
    );
  }
}

class _SettingsApiKeyField extends StatefulWidget {
  final AppState state;
  const _SettingsApiKeyField({required this.state});

  @override
  State<_SettingsApiKeyField> createState() => _SettingsApiKeyFieldState();
}

class _SettingsApiKeyFieldState extends State<_SettingsApiKeyField> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('API Key',
                style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13)),
            const Spacer(),
            if (widget.state.apiKeySet)
              const Text('Connected',
                  style: TextStyle(color: Color(0xFF34D399), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.state.apiKeySet)
          Text(
            widget.state.apiKeyMasked,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          )
        else ...[
          _DarkTextField(
            controller: _controller,
            label: '',
            hint: 'sk-ant-api03-...',
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              final key = _controller.text.trim();
              if (key.isEmpty) return;
              await widget.state.updateSettings(apiKey: key);
              _controller.clear();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF818CF8),
            ),
            child: const Text('Save API Key'),
          ),
        ],
      ],
    );
  }
}
